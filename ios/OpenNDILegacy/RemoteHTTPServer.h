#import <Foundation/Foundation.h>
@class CameraFrameStore;
@interface RemoteHTTPServer : NSObject
- (instancetype)initWithFrameStore:(CameraFrameStore *)store;
- (void)start;
- (void)stop;
@property (nonatomic, copy, readonly) NSString *statusMessage;
@property (nonatomic, assign, readonly, getter=isListening) BOOL listening;
@property (nonatomic, readonly) NSUInteger port;
@end
