#import <Foundation/Foundation.h>
@class CameraFrameStore;
@interface RemoteHTTPServer : NSObject
- (instancetype)initWithFrameStore:(CameraFrameStore *)store;
- (void)start;
- (void)stop;
@property (nonatomic, readonly) NSUInteger port;
@end
