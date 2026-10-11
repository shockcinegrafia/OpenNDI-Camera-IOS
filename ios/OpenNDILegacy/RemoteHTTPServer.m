#import "RemoteHTTPServer.h"
#import "CameraFrameStore.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <unistd.h>
#import <fcntl.h>
#import <errno.h>
#import <string.h>
@interface RemoteHTTPServer ()
@property (nonatomic, strong) CameraFrameStore *store;
@property (nonatomic, assign) int serverFD;
@property (nonatomic, assign) BOOL running;
@property (nonatomic, copy, readwrite) NSString *statusMessage;
@property (nonatomic, assign, readwrite, getter=isListening) BOOL listening;
@property (nonatomic, strong) dispatch_queue_t serverQueue;
@end
@implementation RemoteHTTPServer
- (instancetype)initWithFrameStore:(CameraFrameStore *)store {
    if ((self = [super init])) { _store = store; _serverFD = -1; _port = 8088; _statusMessage = @"Stopped"; _serverQueue = dispatch_queue_create("com.shockcinegrafia.legacy.http", DISPATCH_QUEUE_SERIAL); }
    return self;
}
- (void)start {
    @synchronized(self) {
        if (self.running) return;
        self.running = YES;
        self.listening = NO;
        self.statusMessage = @"Starting HTTP server...";
    }
    dispatch_async(self.serverQueue, ^{ [self serve]; });
}
- (void)stop {
    @synchronized(self) {
        self.running = NO;
        self.listening = NO;
        self.statusMessage = @"Stopped";
        if (self.serverFD >= 0) shutdown(self.serverFD, SHUT_RDWR);
    }
}
- (void)sendBytes:(NSData *)data fd:(int)fd {
    const uint8_t *ptr = data.bytes;
    NSUInteger left = data.length;
    while (left > 0) {
        ssize_t n = send(fd, ptr, left, 0);
        if (n <= 0) break;
        ptr += n; left -= (NSUInteger)n;
    }
}
- (void)respond:(int)fd code:(NSString *)code type:(NSString *)type data:(NSData *)body {
    NSString *header = [NSString stringWithFormat:@"HTTP/1.1 %@\r\nContent-Type: %@\r\nContent-Length: %lu\r\nCache-Control: no-store\r\nConnection: close\r\nX-Content-Type-Options: nosniff\r\n\r\n",code,type,(unsigned long)body.length];
    [self sendBytes:[header dataUsingEncoding:NSUTF8StringEncoding] fd:fd];
    [self sendBytes:body fd:fd];
}
- (void)serve {
    int s = socket(AF_INET, SOCK_STREAM, 0);
    if (s < 0) {
        @synchronized(self) { self.running = NO; self.statusMessage = [NSString stringWithFormat:@"socket: %s (%d)", strerror(errno), errno]; }
        return;
    }
    @synchronized(self) { self.serverFD = s; }
    int yes = 1;
    setsockopt(s, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));
    struct sockaddr_in addr = {0};
    addr.sin_len = sizeof(addr);
    addr.sin_family = AF_INET;
    addr.sin_port = htons((uint16_t)self.port);
    addr.sin_addr.s_addr = htonl(INADDR_ANY);
    if (bind(s, (struct sockaddr *)&addr, sizeof(addr)) != 0) {
        int err = errno;
        @synchronized(self) { self.running = NO; self.statusMessage = [NSString stringWithFormat:@"bind: %s (%d)", strerror(err), err]; self.serverFD = -1; }
        close(s); return;
    }
    if (listen(s, 8) != 0) {
        int err = errno;
        @synchronized(self) { self.running = NO; self.statusMessage = [NSString stringWithFormat:@"listen: %s (%d)", strerror(err), err]; self.serverFD = -1; }
        close(s); return;
    }
    @synchronized(self) { self.listening = YES; self.statusMessage = @"Listening on port 8088"; }
    while (self.running) {
        int client = accept(s, NULL, NULL);
        if (client < 0) { if (!self.running) break; continue; }
        struct timeval timeout = {2, 0};
        setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
        setsockopt(client, SOL_SOCKET, SO_SNDTIMEO, &timeout, sizeof(timeout));
        char buffer[2048] = {0};
        ssize_t n = recv(client, buffer, sizeof(buffer)-1, 0);
        if (n > 0) {
            NSString *req = [[NSString alloc] initWithBytes:buffer length:(NSUInteger)n encoding:NSUTF8StringEncoding];
            NSArray *parts = [req componentsSeparatedByString:@" "];
            NSString *method = [parts count] > 0 ? parts[0] : @"";
            NSString *path = [parts count] > 1 ? parts[1] : @"";
            if (![method isEqualToString:@"GET"]) {
                [self respond:client code:@"405 Method Not Allowed" type:@"text/plain" data:[@"GET only" dataUsingEncoding:NSUTF8StringEncoding]];
                close(client);
                continue;
            }
            if ([path isEqualToString:@"/snapshot.jpg"]) {
                NSData *jpeg = [self.store latestJPEG];
                if (jpeg) [self respond:client code:@"200 OK" type:@"image/jpeg" data:jpeg];
                else [self respond:client code:@"503 Service Unavailable" type:@"text/plain" data:[@"Camera warming up" dataUsingEncoding:NSUTF8StringEncoding]];
            } else if ([path isEqualToString:@"/api/status"]) {
                NSString *json = @"{\"app\":\"OpenNDI Camera Legacy\",\"version\":\"0.1.0\",\"webPreviewTargetFPS\":10,\"localPreviewDefault\":false,\"ndiImplemented\":false,\"remoteControlsImplemented\":false}";
                [self respond:client code:@"200 OK" type:@"application/json; charset=utf-8" data:[json dataUsingEncoding:NSUTF8StringEncoding]];
            } else if ([path isEqualToString:@"/"] || [path isEqualToString:@"/index.html"]) {
                NSString *html = @"<!doctype html><html><head><meta name='viewport' content='width=device-width,initial-scale=1'><title>OpenNDI Legacy</title><style>body{background:#10151d;color:white;font:16px -apple-system,Arial;text-align:center;margin:20px}img{max-width:100%;background:black;border-radius:12px}</style></head><body><h2>OpenNDI Camera Legacy</h2><p>Web preview (target 10 FPS)</p><img id='v' alt='Camera preview'><p>Local-only development preview. NDI not yet available.</p><script>var v=document.getElementById('v');setInterval(function(){v.src='/snapshot.jpg?t='+Date.now()},100);</script></body></html>";
                [self respond:client code:@"200 OK" type:@"text/html; charset=utf-8" data:[html dataUsingEncoding:NSUTF8StringEncoding]];
            } else {
                [self respond:client code:@"404 Not Found" type:@"text/plain" data:[@"Not found" dataUsingEncoding:NSUTF8StringEncoding]];
            }
        }
        close(client);
    }
    @synchronized(self) {
        if (self.serverFD == s) self.serverFD = -1;
        self.listening = NO;
        self.running = NO;
        if ([self.statusMessage isEqualToString:@"Listening on port 8088"]) self.statusMessage = @"Stopped";
    }
    close(s);
}
@end
