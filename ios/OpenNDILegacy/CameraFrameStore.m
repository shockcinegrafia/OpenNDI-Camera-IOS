#import "CameraFrameStore.h"
#import <UIKit/UIKit.h>
#import <CoreImage/CoreImage.h>
@interface CameraFrameStore ()
@property (nonatomic, strong) NSData *frame;
@property (nonatomic, strong) CIContext *context;
@property (nonatomic, assign) NSTimeInterval lastFrameTime;
@end
@implementation CameraFrameStore
- (instancetype)init {
    if ((self = [super init])) self.context = [CIContext contextWithOptions:nil];
    return self;
}
- (NSData *)latestJPEG { @synchronized(self) { return self.frame; } }
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (now - self.lastFrameTime < 0.1) return; // Web preview budget: <=10 FPS
    self.lastFrameTime = now;
    CVImageBufferRef pixel = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (!pixel) return;
    CIImage *ci = [CIImage imageWithCVPixelBuffer:pixel];
    CGRect rect = CGRectMake(0, 0, CVPixelBufferGetWidth(pixel), CVPixelBufferGetHeight(pixel));
    CGImageRef cg = [self.context createCGImage:ci fromRect:rect];
    if (!cg) return;
    UIImage *image = [UIImage imageWithCGImage:cg];
    CGImageRelease(cg);
    NSData *jpeg = UIImageJPEGRepresentation(image, 0.55);
    if (jpeg) { @synchronized(self) { self.frame = jpeg; } }
}
@end
