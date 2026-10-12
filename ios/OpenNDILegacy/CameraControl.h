#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
@class CameraFrameStore;
@interface CameraControl : NSObject
@property (nonatomic, strong, readonly) dispatch_queue_t queue;
@property (nonatomic, copy) void (^darkHandler)(BOOL);
@property (nonatomic, strong) dispatch_queue_t frameQueue;
- (instancetype)initWithSession:(AVCaptureSession *)session store:(CameraFrameStore *)store;
- (NSDictionary *)state;
- (NSDictionary *)capabilities;
- (NSDictionary *)action:(NSString *)type value:(NSString *)value;
@end
