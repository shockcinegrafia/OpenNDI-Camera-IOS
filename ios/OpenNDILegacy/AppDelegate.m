#import "AppDelegate.h"
#import "CameraViewController.h"
@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[CameraViewController alloc] init];
    [self.window makeKeyAndVisible];
    application.idleTimerDisabled = YES;
    return YES;
}
@end
