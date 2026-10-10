#import "CameraViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "CameraFrameStore.h"
#import "RemoteHTTPServer.h"
@interface CameraViewController ()
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, strong) UIButton *toggleButton;
@property (nonatomic, assign) BOOL previewEnabled;
@property (nonatomic, strong) CameraFrameStore *frameStore;
@property (nonatomic, strong) RemoteHTTPServer *webServer;
@property (nonatomic, strong) dispatch_queue_t captureQueue;
@end
@implementation CameraViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    self.previewEnabled = NO;
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 55, self.view.bounds.size.width - 40, 45)];
    titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    titleLabel.text = @"OpenNDI Camera Legacy";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:titleLabel];
    self.toggleButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.toggleButton.frame = CGRectMake(30, 115, self.view.bounds.size.width - 60, 50);
    self.toggleButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.toggleButton setTitle:@"Show local preview" forState:UIControlStateNormal];
    [self.toggleButton addTarget:self action:@selector(togglePreview) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.toggleButton];
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (status == AVAuthorizationStatusAuthorized) {
        [self configureCamera];
    } else if (status == AVAuthorizationStatusNotDetermined) {
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (granted) [self configureCamera];
                else [self showCameraError:@"Camera permission denied. Enable camera access in Settings."];
            });
        }];
    } else {
        [self showCameraError:@"Camera access unavailable. Check iOS privacy settings."];
    }
}
- (void)showCameraError:(NSString *)message {
    UILabel *errorLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 185, self.view.bounds.size.width - 40, 100)];
    errorLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    errorLabel.textColor = [UIColor orangeColor];
    errorLabel.numberOfLines = 0;
    errorLabel.textAlignment = NSTextAlignmentCenter;
    errorLabel.text = message;
    [self.view addSubview:errorLabel];
}
- (void)configureCamera {
    self.session = [[AVCaptureSession alloc] init];
    if ([self.session canSetSessionPreset:AVCaptureSessionPreset640x480]) self.session.sessionPreset = AVCaptureSessionPreset640x480;
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (!device) { [self showCameraError:@"No video camera available."]; return; }
    NSError *error = nil;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    if (!input || ![self.session canAddInput:input]) {
        [self showCameraError:error.localizedDescription ?: @"Cannot open camera."];
        return;
    }
    [self.session addInput:input];
    self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.previewLayer.frame = self.view.bounds;
    self.frameStore = [[CameraFrameStore alloc] init];
    self.captureQueue = dispatch_queue_create("com.shockcinegrafia.legacy.frames", DISPATCH_QUEUE_SERIAL);
    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
    output.alwaysDiscardsLateVideoFrames = YES;
    output.videoSettings = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)};
    if ([self.session canAddOutput:output]) {
        [self.session addOutput:output];
        [output setSampleBufferDelegate:self.frameStore queue:self.captureQueue];
    }
    self.webServer = [[RemoteHTTPServer alloc] initWithFrameStore:self.frameStore];
    [self.webServer start];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.session startRunning];
    });
}
- (void)togglePreview {
    self.previewEnabled = !self.previewEnabled;
    if (self.previewEnabled) {
        self.previewLayer.frame = self.view.bounds;
        [self.view.layer insertSublayer:self.previewLayer atIndex:0];
    } else {
        [self.previewLayer removeFromSuperlayer];
    }
    [self.toggleButton setTitle:self.previewEnabled ? @"Hide local preview" : @"Show local preview" forState:UIControlStateNormal];
}
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.webServer stop];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ [self.session stopRunning]; });
}
@end
