#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
@interface CameraFrameStore : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>
- (NSData *)latestJPEG;
- (NSData *)latestSDJPEG;
- (void)clear;
@end
