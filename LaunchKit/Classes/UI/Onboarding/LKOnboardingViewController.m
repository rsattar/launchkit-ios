//
//  LKOnboardingViewController.m
//  Pods
//
//  Created by Rizwan Sattar on 1/25/16.
//
//

#import "LKOnboardingViewController.h"

#import "LKLog.h"

@interface LKViewController (LKHelperAdditions)

- (void) markFinishedFlowResult:(LKViewControllerFlowResult)result;

@end

@interface LKOnboardingViewController () <LKViewControllerFlowDelegate>

#if !TARGET_OS_TV
@property (assign, nonatomic) BOOL shouldLockOrientation;
@property (assign, nonatomic) UIInterfaceOrientation lockedOrientation;
#endif
@property (strong, nonatomic, nullable) UIImageView *launchImageView;
@property (strong, nonatomic, nullable) UIView *launchScreenView;
@property (strong, nonatomic, nullable) UIViewController *launchViewController;

@property (strong, nonatomic, nullable) LKViewController *remoteOnboardingViewController;

@property (strong, nonatomic, nullable) NSTimer *maxLoadingTimeoutTimer;

// Measuring Time
@property (strong, nonatomic, nullable) NSDate *viewAppearanceTime;
@property (assign, nonatomic) NSTimeInterval preOnboardingDuration;
@property (strong, nonatomic, nullable) NSDate *actualOnboardingStartTime;

@end

@implementation LKOnboardingViewController

- (void) dealloc
{
    [self destroyMaxLoadingTimeoutTimerIfNeeded];
}

- (void) loadView
{
    self.view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 600, 600)];

    BOOL loadedLaunchImage = [self loadLaunchImageIfPossible];
    BOOL loadedLaunchStoryboard = NO;
    if (!loadedLaunchImage) {
        loadedLaunchStoryboard = [self loadLaunchStoryboardIfPossible];
    } else {
#if !TARGET_OS_TV
        self.shouldLockOrientation = YES;
#endif
    }
    if (!loadedLaunchImage && !loadedLaunchStoryboard) {
        LKLogError(@"Neither LaunchImage or Launch screen was loaded");
    }
}

- (BOOL) loadLaunchImageIfPossible
{
    UIImage *launchImage = [UIImage imageNamed:@"LaunchImage"];
    if (launchImage != nil) {
        self.launchImageView = [[UIImageView alloc] initWithFrame:self.view.bounds];
        self.launchImageView.image = launchImage;
        [self.view addSubview:self.launchImageView];
        return YES;
    }

    return NO;
}

- (BOOL) loadLaunchStoryboardIfPossible
{
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *launchScreenName = [NSBundle mainBundle].infoDictionary[@"UILaunchStoryboardName"];
    if (launchScreenName.length > 0) {
        // Try storyboard first
        NSString *storyboardPath = [bundle pathForResource:launchScreenName ofType:@"storyboardc"];
        if (storyboardPath.length > 0) {
            @try {
                UIStoryboard *storyboard = [UIStoryboard storyboardWithName:launchScreenName bundle:bundle];
                self.launchViewController = [storyboard instantiateInitialViewController];
            }
            @catch (NSException *exception) {
                // Storyboard could not load, so move on
                LKLogWarning(@"%@.storyboard not found", launchScreenName);
            }
            @finally {
                //
            }
        }

        // Try xib next
        NSString *nibPath = [bundle pathForResource:launchScreenName ofType:@"nib"];
        if (!self.launchViewController && nibPath.length > 0) {
            @try {
                UINib *nib = [UINib nibWithNibName:launchScreenName bundle:bundle];
                UIViewController *nibVC = [[UIViewController alloc] init];
                NSArray *topLevelObjects = [nib instantiateWithOwner:nibVC options:nil];

                if ([topLevelObjects.firstObject isKindOfClass:[UIView class]]) {
                    self.launchScreenView = (UIView *)topLevelObjects.firstObject;
                } else if ([topLevelObjects.firstObject isKindOfClass:[UIViewController class]]) {
                    self.launchViewController = (UIViewController *)topLevelObjects.firstObject;
                }
            }
            @catch (NSException *exception) {
                // Nib could not be loaded
                LKLogWarning(@"%@.nib not found", launchScreenName);
            }
            @finally {
                //
            }
        }

        if (self.launchViewController != nil && self.launchScreenView == nil) {
            self.launchScreenView = self.launchViewController.view;
        }

        if (self.launchScreenView != nil) {
            if (self.launchViewController != nil) {
                [self addChildViewController:self.launchViewController];
            }
            [self.view addSubview:self.launchScreenView];
            self.launchScreenView.frame = self.view.bounds;
            self.launchScreenView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            return YES;
        }
    }
    return NO;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    // Fire this, in case we supplied the onboarding view controller already
    [self setActualOnboardingUI:self.remoteOnboardingViewController];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    // NOTE: We may get called again accidentally, when we are
    // transitioning from being the rootViewController of the
    // window during the hand-off back the app's UI (see LKUIManager).
    // So check if we already have finished and do nothing, if so.
    if (self.finishedFlowResult != LKViewControllerFlowResultNotSet) {
        return;
    }

    self.viewAppearanceTime = [NSDate date];

    if (!self.remoteOnboardingViewController) {
        [self startLoadingTimeoutTimerIfNeeded];
    }
}

#pragma mark - Timeout

- (void) startLoadingTimeoutTimerIfNeeded
{
    if (self.maxWaitTimeInterval <= 0) {
        // No time set, so no timer to start
        return;
    }
    self.maxLoadingTimeoutTimer = [NSTimer scheduledTimerWithTimeInterval:self.maxWaitTimeInterval
                                                                   target:self
                                                                 selector:@selector(onMaxLoadingTimeoutTimerFired:)
                                                                 userInfo:nil
                                                                  repeats:NO];
}

- (void) onMaxLoadingTimeoutTimerFired:(NSTimer *)timer
{
    [self destroyMaxLoadingTimeoutTimerIfNeeded];

    if (!self.remoteOnboardingViewController) {
        LKLogError(@"Actual onboarding UI failed to load from remote after %.1f seconds, failing...", self.maxWaitTimeInterval);
        [self finishOnboardingWithResult:LKViewControllerFlowResultFailed];
    }
}

- (void) destroyMaxLoadingTimeoutTimerIfNeeded
{
    if (self.maxLoadingTimeoutTimer.valid) {
        [self.maxLoadingTimeoutTimer invalidate];
    }
    self.maxLoadingTimeoutTimer = nil;
}

#pragma mark - Actual onboarding UI

- (void) setActualOnboardingUI:(LKViewController *)actualOnboardingUI
{
    if (self.finishedFlowResult != LKViewControllerFlowResultNotSet || actualOnboardingUI == nil) {
        return;
    }
    if (self.remoteOnboardingViewController == actualOnboardingUI) {
        return;
    }
    self.remoteOnboardingViewController = actualOnboardingUI;
    self.actualOnboardingStartTime = [NSDate date];
    if (self.viewAppearanceTime != nil) {
        self.preOnboardingDuration = [[NSDate date] timeIntervalSinceDate:self.viewAppearanceTime];
    }
    if (![self isViewLoaded]) {
        return;
    }
    [self destroyMaxLoadingTimeoutTimerIfNeeded];
    // TODO: (Optional) On iPads, show onboarding UI in a form sheet size
    [self addChildViewController:self.remoteOnboardingViewController];
    self.remoteOnboardingViewController.flowDelegate = self;
    UIView *remoteView = self.remoteOnboardingViewController.view;
    [self.view addSubview:remoteView];
    [self setNeedsStatusBarAppearanceUpdate];
}


- (void)launchKitController:(nonnull LKViewController *)controller
        didFinishWithResult:(LKViewControllerFlowResult)result
                   userInfo:(nullable NSDictionary *)userInfo
{
    [self finishFlowWithResult:result userInfo:userInfo];
}


- (void) finishFlowWithResult:(LKViewControllerFlowResult)result userInfo:(NSDictionary *)userInfo
{
    // In case we were called before the timeout fired
    [self destroyMaxLoadingTimeoutTimerIfNeeded];

    NSDate *endTime = [NSDate date];
    if (self.dismissalHandler) {
        LKBundleInfo *actualOnboardingBundleInfo = self.remoteOnboardingViewController.bundleInfo;
        self.dismissalHandler(result, userInfo, actualOnboardingBundleInfo, self.actualOnboardingStartTime, endTime, self.preOnboardingDuration);
    }
    self.dismissalHandler = nil;
    [self markFinishedFlowResult:result];
}


- (void) finishOnboardingWithResult:(LKViewControllerFlowResult)result
{
    [self finishFlowWithResult:result userInfo:nil];
}

#pragma mark - Status Bar Management

- (UIViewController *)childViewControllerForStatusBarHidden
{
    return self.remoteOnboardingViewController;
}

- (UIViewController *)childViewControllerForStatusBarStyle
{
    return self.remoteOnboardingViewController;
}

@end
