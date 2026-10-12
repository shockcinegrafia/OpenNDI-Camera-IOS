#import "CameraFrameStore.h"
#import <UIKit/UIKit.h>
#import <CoreImage/CoreImage.h>
@interface CameraFrameStore ()
@property (nonatomic, strong) NSData *frame;
@property (nonatomic, strong) NSData *sdFrame;
@property (nonatomic, strong) CIContext *context;
@property (nonatomic, assign) NSTimeInterval lastFrameTime;
@end
@implementation CameraFrameStore
- (instancetype)init {
    if ((self = [super init])) self.context = [CIContext contextWithOptions:nil];
    return self;
}
- (NSData *)latestJPEG { @synchronized(self) { return self.frame; } }
- (NSData *)latestSDJPEG { @synchronized(self) { return self.sdFrame; } }
- (void)clear { @synchronized(self) { self.frame = nil; self.sdFrame = nil; } }
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    @autoreleasepool {
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
    CGFloat scale = MIN(1.0, 320.0 / rect.size.width);
    CIImage *sd = [ci imageByApplyingTransform:CGAffineTransformMakeScale(scale, scale)];
    CGImageRef small = [self.context createCGImage:sd fromRect:sd.extent];
    NSData *sdJPEG = small ? UIImageJPEGRepresentation([UIImage imageWithCGImage:small], 0.4) : nil;
    if (small) CGImageRelease(small);
    if (jpeg && sdJPEG) { @synchronized(self) { self.frame = jpeg; self.sdFrame = sdJPEG; } }
    }
}
@end
