// Transport test only. These stubs do not simulate/verify AVFoundation controls.
#import <Foundation/Foundation.h>
#import "RemoteHTTPServer.h"
#import "CameraFrameStore.h"
#import "CameraControl.h"
#import <unistd.h>
#import <stdio.h>
@implementation CameraFrameStore
- (NSData *)latestJPEG { return [NSMutableData dataWithLength:262144]; }
- (NSData *)latestSDJPEG { return [NSMutableData dataWithLength:1024]; }
- (void)clear {}
@end
@implementation CameraControl
- (NSDictionary *)state { return @{@"version":@"transport-test"}; }
- (NSDictionary *)capabilities { return @{@"audio":@NO}; }
- (NSDictionary *)action:(NSString *)type value:(NSString *)value { return [type isEqualToString:@"unsupported"] ? @{@"ok":@NO,@"httpStatus":@501} : @{@"ok":@YES,@"type":type,@"value":value ?: @""}; }
@end
static BOOL waitForServer(RemoteHTTPServer *server) {
    for (int i=0;i<300;i++) { if (server.isListening) { puts("READY"); fflush(stdout); return YES; } usleep(10000); }
    fprintf(stderr, "HTTP startup/restart failed: %s\n", server.statusMessage.UTF8String);
    return NO;
}
int main(void) { @autoreleasepool {
    RemoteHTTPServer *server=[[RemoteHTTPServer alloc] initWithFrameStore:[CameraFrameStore new]];
    server.control=[CameraControl new]; [server start]; if (!waitForServer(server)) return 1;
    int command;
    while ((command=getchar()) != EOF) { if (command=='q') break; if(command=='r') { [server stop]; [server start]; if(!waitForServer(server))return 2; } }
    [server stop]; usleep(100000); return 0;
} }
