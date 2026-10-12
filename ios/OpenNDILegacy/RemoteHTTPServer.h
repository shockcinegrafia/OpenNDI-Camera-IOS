#import <Foundation/Foundation.h>
@class CameraFrameStore;
@class CameraControl;
@interface RemoteHTTPServer : NSObject
- (instancetype)initWithFrameStore:(CameraFrameStore *)store;
- (void)start;
- (void)stop;
@property (atomic, copy, readonly) NSString *statusMessage;
@property (atomic, assign, readonly, getter=isListening) BOOL listening;
@property (nonatomic, readonly) NSUInteger port;
@property (nonatomic, strong) CameraControl *control;
@end
