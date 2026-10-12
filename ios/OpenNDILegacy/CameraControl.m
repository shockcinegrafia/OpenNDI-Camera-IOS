#import "CameraControl.h"
#import "CameraFrameStore.h"
#import <UIKit/UIKit.h>
#import <math.h>
@interface CameraControl ()
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) CameraFrameStore *store;
@property (nonatomic, strong, readwrite) dispatch_queue_t queue;
@property (nonatomic, assign) BOOL dark;
@end
@implementation CameraControl
- (instancetype)initWithSession:(AVCaptureSession *)session store:(CameraFrameStore *)store {
    if ((self = [super init])) { _session = session; _store = store; _queue = dispatch_queue_create("com.shockcinegrafia.legacy.controls", DISPATCH_QUEUE_SERIAL); }
    return self;
}
- (AVCaptureDeviceInput *)input {
    for (AVCaptureInput *input in self.session.inputs) if ([input isKindOfClass:[AVCaptureDeviceInput class]]) return (AVCaptureDeviceInput *)input;
    return nil;
}
- (NSArray *)resolutions {
    NSMutableArray *items = [NSMutableArray array];
    for (NSString *preset in @[AVCaptureSessionPreset352x288, AVCaptureSessionPreset640x480, AVCaptureSessionPreset1280x720])
        if ([self.session canSetSessionPreset:preset]) [items addObject:preset];
    return items;
}
- (NSArray *)frameRates {
    NSMutableArray *items = [NSMutableArray array];
    for (NSNumber *fps in @[@10, @15, @24, @25, @30]) {
        for (AVFrameRateRange *range in [self input].device.activeFormat.videoSupportedFrameRateRanges)
            if (fps.doubleValue >= range.minFrameRate && fps.doubleValue <= range.maxFrameRate) { [items addObject:fps]; break; }
    }
    return items;
}
- (NSDictionary *)capabilitiesOnQueue {
    AVCaptureDevice *d = [self input].device;
    return @{ @"mjpeg":@YES, @"snapshot":@YES, @"remoteControls":@YES, @"ndi":@NO, @"audio":@NO,
      @"recording":@NO, @"webrtc":@NO, @"rtmp":@NO, @"gpu":@NO, @"studio":@NO,
      @"switchCamera":@([AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo].count > 1),
      @"zoom":@(d.activeFormat.videoMaxZoomFactor > 1), @"zoomMin":@1, @"zoomMax":@(MIN(10.0, d.activeFormat.videoMaxZoomFactor)),
      @"focus":@(d.isFocusPointOfInterestSupported && [d isFocusModeSupported:AVCaptureFocusModeAutoFocus]),
      @"torch":@(d.hasTorch && d.isTorchAvailable), @"darkScreen":@YES,
      @"resolutions":[self resolutions], @"frameRates":[self frameRates], @"webPreviewTargetFPS":@10 };
}
- (NSDictionary *)capabilities { __block NSDictionary *result; dispatch_sync(self.queue, ^{ result = [self capabilitiesOnQueue]; }); return result; }
- (NSDictionary *)stateOnQueue {
    AVCaptureDevice *d = [self input].device;
    CMVideoDimensions size = CMVideoFormatDescriptionGetDimensions(d.activeFormat.formatDescription);
    double duration = CMTimeGetSeconds(d.activeVideoMinFrameDuration);
    return @{ @"platform":@"ios-legacy", @"version":@"0.3.0", @"deviceName":@"OpenNDI Camera Legacy",
      @"isCameraEnabled":@(self.session.isRunning), @"cameraOn":@(self.session.isRunning), @"streaming":@(self.session.isRunning && !self.session.isInterrupted && [self.store latestJPEG].length > 0),
      @"interrupted":@(self.session.isInterrupted),
      @"isTransmitting":@NO, @"ndiEnabled":@NO, @"audioEnabled":@NO, @"isMicEnabled":@NO, @"audioLevel":@0,
      @"currentZoom":@(d.videoZoomFactor), @"isTorchEnabled":@(d.torchMode == AVCaptureTorchModeOn),
      @"camera":d.position == AVCaptureDevicePositionFront ? @"front" : @"back", @"darkScreen":@(self.dark),
      @"resolution":self.session.sessionPreset, @"width":@(size.width), @"height":@(size.height), @"isPortrait":@NO,
      @"fps":@(duration > 0 ? 1.0/duration : 0), @"webPreviewTargetFPS":@10, @"capabilities":[self capabilitiesOnQueue] };
}
- (NSDictionary *)state { __block NSDictionary *result; dispatch_sync(self.queue, ^{ result = [self stateOnQueue]; }); return result; }
- (NSDictionary *)failure:(NSString *)message status:(NSInteger)status { return @{ @"ok":@NO, @"error":message, @"httpStatus":@(status) }; }
- (BOOL)number:(NSString *)text result:(double *)value {
    if (!text.length) return NO;
    NSScanner *scanner = [NSScanner scannerWithString:text];
    return [scanner scanDouble:value] && scanner.isAtEnd && isfinite(*value);
}
- (NSDictionary *)perform:(NSString *)type value:(NSString *)value {
    AVCaptureDevice *d = [self input].device;
    NSError *error = nil;
    if ([type isEqualToString:@"toggle_camera"]) {
        AVCaptureDevicePosition position = d.position == AVCaptureDevicePositionBack ? AVCaptureDevicePositionFront : AVCaptureDevicePositionBack;
        AVCaptureDevice *next = nil;
        for (AVCaptureDevice *candidate in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) if (candidate.position == position) { next = candidate; break; }
        if (!next) return [self failure:@"Camera unavailable" status:409];
        AVCaptureDeviceInput *newInput = [AVCaptureDeviceInput deviceInputWithDevice:next error:&error];
        if (!newInput) return [self failure:error.localizedDescription ?: @"Cannot open camera" status:409];
        AVCaptureDeviceInput *old = [self input];
        [self.session beginConfiguration];
        [self.session removeInput:old];
        if (![self.session canAddInput:newInput]) { [self.session addInput:old]; [self.session commitConfiguration]; return [self failure:@"Camera switch rejected" status:409]; }
        [self.session addInput:newInput];
        [self.session commitConfiguration];
        for (AVCaptureOutput *output in self.session.outputs) {
            AVCaptureConnection *connection = [output connectionWithMediaType:AVMediaTypeVideo];
            if (connection.isVideoOrientationSupported) connection.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
            if (connection.isVideoMirroringSupported) { connection.automaticallyAdjustsVideoMirroring = NO; connection.videoMirrored = NO; }
        }
        [self.store clear];
    } else if ([type isEqualToString:@"toggle_camera_power"]) {
        if (self.session.isRunning) { [self.session stopRunning]; [self.store clear]; } else [self.session startRunning];
    } else if ([type isEqualToString:@"toggle_dark_screen"] || [type isEqualToString:@"dark_screen"]) {
        if (value.length && ![value isEqualToString:@"0"] && ![value isEqualToString:@"1"]) return [self failure:@"Use 0 or 1" status:400];
        self.dark = value.length ? value.boolValue : !self.dark;
        if (self.darkHandler) self.darkHandler(self.dark);
    } else if ([type isEqualToString:@"set_resolution"]) {
        if (![[self resolutions] containsObject:value]) return [self failure:@"Resolution unavailable" status:409];
        [self.session beginConfiguration]; self.session.sessionPreset = value; [self.session commitConfiguration]; [self.store clear];
    } else if ([type isEqualToString:@"set_zoom"] || [type hasPrefix:@"zoom_"] || [type isEqualToString:@"tap_focus"] || [type isEqualToString:@"toggle_torch"] || [type isEqualToString:@"set_fps"]) {
        double number = 0, x = 0, y = 0;
        BOOL zoom = [type isEqualToString:@"set_zoom"] || [type hasPrefix:@"zoom_"];
        if (zoom) {
            NSString *text = [type hasPrefix:@"zoom_"] ? [type substringFromIndex:5] : value;
            if ([text isEqualToString:@"05"]) text = @"0.5";
            if (![self number:text result:&number] || number < 1 || number > MIN(10.0, d.activeFormat.videoMaxZoomFactor)) return [self failure:@"Zoom outside device range" status:400];
        } else if ([type isEqualToString:@"tap_focus"]) {
            NSArray *point = [value componentsSeparatedByString:@","];
            if (point.count != 2 || ![self number:point[0] result:&x] || ![self number:point[1] result:&y] || x < 0 || x > 1 || y < 0 || y > 1) return [self failure:@"Expected normalized x,y" status:400];
            if (!d.isFocusPointOfInterestSupported || ![d isFocusModeSupported:AVCaptureFocusModeAutoFocus]) return [self failure:@"Focus unavailable" status:409];
        } else if ([type isEqualToString:@"set_fps"]) {
            if (![self number:value result:&number] || ![[self frameRates] containsObject:@(number)]) return [self failure:@"FPS unavailable" status:409];
        } else if (!d.hasTorch || !d.isTorchAvailable) return [self failure:@"Torch unavailable" status:409];
        if (![d lockForConfiguration:&error]) return [self failure:error.localizedDescription ?: @"Device busy" status:409];
        @try {
        if (zoom) d.videoZoomFactor = number;
        else if ([type isEqualToString:@"tap_focus"]) { d.focusPointOfInterest = CGPointMake(x,y); d.focusMode = AVCaptureFocusModeAutoFocus; }
        else if ([type isEqualToString:@"set_fps"]) { CMTime time = CMTimeMake(1, (int32_t)number); if (CMTimeCompare(time, d.activeVideoMaxFrameDuration) > 0) d.activeVideoMaxFrameDuration = time; d.activeVideoMinFrameDuration = time; d.activeVideoMaxFrameDuration = time; }
        else d.torchMode = d.torchMode == AVCaptureTorchModeOn ? AVCaptureTorchModeOff : AVCaptureTorchModeOn;
        } @catch (NSException *exception) { return [self failure:exception.reason ?: @"Device rejected control" status:409]; }
        @finally { [d unlockForConfiguration]; }
    } else return [self failure:@"Action not implemented on iOS Legacy" status:501];
    return @{ @"ok":@YES, @"state":[self stateOnQueue] };
}
- (NSDictionary *)action:(NSString *)type value:(NSString *)value {
    __block NSDictionary *result; dispatch_sync(self.queue, ^{ result = [self perform:type value:value ?: @""]; }); return result;
}
@end
