#import "RemoteHTTPServer.h"
#import "CameraFrameStore.h"
#import "CameraControl.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <unistd.h>
#import <errno.h>
#import <string.h>
@interface RemoteHTTPServer ()
@property (nonatomic, strong) CameraFrameStore *store;
@property (nonatomic, assign) int serverFD;
@property (atomic, assign) BOOL running;
@property (atomic, copy, readwrite) NSString *statusMessage;
@property (atomic, assign, readwrite, getter=isListening) BOOL listening;
@property (nonatomic, strong) dispatch_queue_t serverQueue;
@property (nonatomic, strong) NSMutableSet *clients;
@property (nonatomic, assign) NSUInteger streamCount;
@end
@implementation RemoteHTTPServer
- (instancetype)initWithFrameStore:(CameraFrameStore *)store {
    if ((self = [super init])) { _store = store; _serverFD = -1; _port = 8088; _statusMessage = @"Stopped"; _clients = [NSMutableSet set]; _serverQueue = dispatch_queue_create("com.shockcinegrafia.legacy.http", DISPATCH_QUEUE_SERIAL); }
    return self;
}
- (void)start { dispatch_async(self.serverQueue, ^{ if (!self.running) { self.running = YES; [self serve]; } }); }
- (void)stop {
    @synchronized(self) {
        self.running = NO; self.listening = NO; self.statusMessage = @"Stopped";
        if (self.serverFD >= 0) shutdown(self.serverFD, SHUT_RDWR);
        for (NSNumber *client in self.clients) shutdown(client.intValue, SHUT_RDWR);
    }
}
- (BOOL)sendBytes:(NSData *)data fd:(int)fd {
    const uint8_t *ptr = data.bytes; NSUInteger left = data.length;
    while (left) {
        ssize_t n = send(fd, ptr, left, 0);
        if (n < 0 && errno == EINTR) continue;
        if (n <= 0) return NO;
        ptr += n; left -= (NSUInteger)n;
    }
    return YES;
}
- (void)respond:(int)fd code:(NSString *)code type:(NSString *)type data:(NSData *)body {
    NSString *header = [NSString stringWithFormat:@"HTTP/1.1 %@\r\nContent-Type: %@\r\nContent-Length: %lu\r\nCache-Control: no-store\r\nConnection: close\r\nAccess-Control-Allow-Origin: *\r\nX-Content-Type-Options: nosniff\r\n\r\n", code,type,(unsigned long)body.length];
    if ([self sendBytes:[header dataUsingEncoding:NSUTF8StringEncoding] fd:fd]) [self sendBytes:body fd:fd];
}
- (void)json:(NSDictionary *)object fd:(int)fd code:(NSString *)code {
    [self respond:fd code:code type:@"application/json; charset=utf-8" data:[NSJSONSerialization dataWithJSONObject:object options:0 error:NULL]];
}
- (void)stream:(int)fd sd:(BOOL)sd {
    @synchronized(self) {
        if (self.streamCount >= 4) { [self json:@{@"error":@"Four streams already connected"} fd:fd code:@"503 Service Unavailable"]; return; }
        self.streamCount++;
    }
    @try {
    if (![self sendBytes:[@"HTTP/1.1 200 OK\r\nContent-Type: multipart/x-mixed-replace; boundary=frame\r\nCache-Control: no-store\r\nConnection: close\r\nAccess-Control-Allow-Origin: *\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding] fd:fd]) return;
    NSData *previous = nil;
    while (self.running) {
        @autoreleasepool {
            NSData *jpeg = sd ? [self.store latestSDJPEG] : [self.store latestJPEG];
            if (jpeg.length && jpeg != previous) {
                NSString *part = [NSString stringWithFormat:@"--frame\r\nContent-Type: image/jpeg\r\nContent-Length: %lu\r\n\r\n", (unsigned long)jpeg.length];
                if (![self sendBytes:[part dataUsingEncoding:NSUTF8StringEncoding] fd:fd] || ![self sendBytes:jpeg fd:fd] || ![self sendBytes:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding] fd:fd]) break;
                previous = jpeg;
            }
            // Detect disconnect even when capture is paused or has no frames.
            char probe; ssize_t peek = recv(fd, &probe, 1, MSG_PEEK | MSG_DONTWAIT);
            if (peek == 0 || (peek < 0 && errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR)) break;
        }
        usleep(sd ? 200000 : 100000);
    }
    } @finally { @synchronized(self) { self.streamCount--; } }
}
- (void)handle:(int)fd {
    NSMutableData *request = [NSMutableData data];
    while (request.length < 4096) {
        char buffer[512]; ssize_t count = recv(fd, buffer, MIN(sizeof(buffer), 4096-request.length), 0);
        if (count < 0 && errno == EINTR) continue;
        if (count <= 0) return;
        [request appendBytes:buffer length:(NSUInteger)count];
        NSString *partial = [[NSString alloc] initWithData:request encoding:NSUTF8StringEncoding];
        if ([partial rangeOfString:@"\r\n\r\n"].location != NSNotFound) break;
    }
    NSString *text = [[NSString alloc] initWithData:request encoding:NSUTF8StringEncoding];
    if (!text || [text rangeOfString:@"\r\n\r\n"].location == NSNotFound) { [self json:@{@"error":@"Invalid or oversized headers"} fd:fd code:@"400 Bad Request"]; return; }
    NSArray *line = [[[text componentsSeparatedByString:@"\r\n"] firstObject] componentsSeparatedByString:@" "];
    if (line.count != 3 || ![line[0] isEqualToString:@"GET"]) { [self json:@{@"error":@"GET only"} fd:fd code:@"405 Method Not Allowed"]; return; }
    NSString *target = line[1];
    if (![target hasPrefix:@"/"]) { [self json:@{@"error":@"Invalid target"} fd:fd code:@"400 Bad Request"]; return; }
    NSURLComponents *url = [NSURLComponents componentsWithString:[@"http://localhost" stringByAppendingString:target]];
    NSString *path = url.path;
    NSMutableDictionary *query = [NSMutableDictionary dictionary];
    for (NSURLQueryItem *item in url.queryItems) if (item.name && item.value) query[item.name] = item.value;
    if ([path isEqualToString:@"/stream"] || [path isEqualToString:@"/stream_sd"]) [self stream:fd sd:[path isEqualToString:@"/stream_sd"]];
    else if ([path isEqualToString:@"/snapshot.jpg"]) {
        NSData *jpeg = [self.store latestJPEG];
        if (jpeg.length) [self respond:fd code:@"200 OK" type:@"image/jpeg" data:jpeg];
        else [self json:@{@"error":@"No camera frame available"} fd:fd code:@"503 Service Unavailable"];
    } else if ([path isEqualToString:@"/state.json"] || [path isEqualToString:@"/api/status"]) [self json:[self.control state] fd:fd code:@"200 OK"];
    else if ([path isEqualToString:@"/api/capabilities"]) [self json:[self.control capabilities] fd:fd code:@"200 OK"];
    else if ([path isEqualToString:@"/legacy.js"]) {
        NSString *resource = [[NSBundle mainBundle] pathForResource:@"legacy" ofType:@"js"];
        NSData *data = resource ? [NSData dataWithContentsOfFile:resource] : nil;
        if (data) [self respond:fd code:@"200 OK" type:@"application/javascript; charset=utf-8" data:data];
        else [self json:@{@"error":@"Resource missing"} fd:fd code:@"503 Service Unavailable"];
    }
    else if ([path isEqualToString:@"/action"] || [path hasPrefix:@"/action/"]) {
        NSString *type = [path isEqualToString:@"/action"] ? query[@"type"] : [path substringFromIndex:8];
        if (!type.length) { [self json:@{@"ok":@NO,@"error":@"Missing type"} fd:fd code:@"400 Bad Request"]; return; }
        NSDictionary *result = [self.control action:type value:query[@"value"] ?: query[@"val"]];
        NSInteger status = [result[@"httpStatus"] integerValue];
        NSString *code = status == 400 ? @"400 Bad Request" : status == 409 ? @"409 Conflict" : status == 501 ? @"501 Not Implemented" : @"200 OK";
        [self json:result fd:fd code:code];
    } else if ([@[@"/", @"/index.html", @"/index_full.html", @"/lite", @"/index_lite.html"] containsObject:path]) {
        BOOL lite = [path isEqualToString:@"/lite"] || [path isEqualToString:@"/index_lite.html"];
        NSString *resource = [[NSBundle mainBundle] pathForResource:lite ? @"index_lite" : @"index_full" ofType:@"html"];
        NSData *html = resource ? [NSData dataWithContentsOfFile:resource] : nil;
        if (html) [self respond:fd code:@"200 OK" type:@"text/html; charset=utf-8" data:html];
        else [self json:@{@"error":@"Web resources missing"} fd:fd code:@"503 Service Unavailable"];
    } else [self json:@{@"ok":@NO,@"error":@"Route not implemented"} fd:fd code:[path hasPrefix:@"/api/"] ? @"501 Not Implemented" : @"404 Not Found"];
}
- (void)serve {
    int s = socket(AF_INET, SOCK_STREAM, 0);
    @synchronized(self) { self.serverFD = s; }
    int yes = 1; setsockopt(s, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));
    struct sockaddr_in addr = {0}; addr.sin_len = sizeof(addr); addr.sin_family = AF_INET; addr.sin_port = htons((uint16_t)self.port); addr.sin_addr.s_addr = htonl(INADDR_ANY);
    if (s < 0 || bind(s, (struct sockaddr *)&addr, sizeof(addr)) != 0 || listen(s, 12) != 0) {
        self.statusMessage = [NSString stringWithFormat:@"HTTP: %s (%d)", strerror(errno), errno];
    } else {
        self.listening = YES; self.statusMessage = @"Listening on port 8088";
        while (self.running) {
            int client = accept(s, NULL, NULL);
            if (client < 0) { if (errno == EINTR) continue; break; }
            setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &yes, sizeof(yes));
            struct timeval timeout = {2,0};
            setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout)); setsockopt(client, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));
            BOOL admitted;
            @synchronized(self) { admitted = self.running && self.clients.count < 12; if (admitted) [self.clients addObject:@(client)]; }
            if (!admitted) { [self json:@{@"error":@"Server busy"} fd:client code:@"503 Service Unavailable"]; close(client); continue; }
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                @autoreleasepool { [self handle:client]; }
                @synchronized(self) { [self.clients removeObject:@(client)]; close(client); }
            });
        }
    }
    @synchronized(self) { if (self.serverFD == s) self.serverFD = -1; self.running = NO; self.listening = NO; }
    if (s >= 0) close(s);
}
@end
