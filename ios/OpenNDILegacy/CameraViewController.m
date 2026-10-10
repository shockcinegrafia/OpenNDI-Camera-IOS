#import "CameraViewController.h"
#import <AVFoundation/AVFoundation.h>
@interface CameraViewController ()
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, strong) UIButton *toggleButton;
@property (nonatomic, assign) BOOL previewEnabled;
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
    [self configureCamera];
}
- (void)configureCamera {
    self.session = [[AVCaptureSession alloc] init];
    if ([self.session canSetSessionPreset:AVCaptureSessionPreset640x480]) self.session.sessionPreset = AVCaptureSessionPreset640x480;
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (!device) return;
    NSError *error = nil;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    if (!input || ![self.session canAddInput:input]) return;
    [self.session addInput:input];
    self.previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.session];
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.previewLayer.frame = self.view.bounds;
    [self.session startRunning];
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
    [self.session stopRunning];
}
@end
