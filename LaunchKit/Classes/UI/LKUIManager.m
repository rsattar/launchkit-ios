//
//  LKUIManager.m
//  LaunchKit
//
//  Created by Rizwan Sattar on 1/19/15.
//
//

#import "LKUIManager.h"

#import "LaunchKitShared.h"
#import "LKCardPresentationController.h"
#import "LKLog.h"
#import "LKOnboardingViewController.h"

@interface LKUIManager () <LKViewControllerFlowDelegate, UIViewControllerTransitioningDelegate>

@property (strong, nonatomic) LKBundlesManager *bundlesManager;

@property (strong, nonatomic) LKViewController *remoteUIPresentedController;
@property (weak, nonatomic) UIViewController *remoteUIPresentingController;
@property (copy, nonatomic) LKRemoteUIDismissalHandler remoteUIControllerDismissalHandler;

@property (strong, nonatomic) NSMutableDictionary *appVersionsForPresentedBundleId;

// Onboarding UI
@property (strong, nonatomic, nullable) UIViewController *postOnboardingRootViewController;
@property (strong, nonatomic, nullable) UIWindow *onboardingWindow;

@end

@implementation LKUIManager

- (instancetype)initWithBundlesManager:(LKBundlesManager *)bundlesManager
{
    self = [super init];
    if (self) {
        self.bundlesManager = bundlesManager;
        self.appVersionsForPresentedBundleId = [@{} mutableCopy];
        [self restoreAppVersionsForPresentedBundleIdFromArchive];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Remote Native UI Loading

- (void)loadRemoteUIWithId:(NSString *)remoteUIId completion:(LKRemoteUILoadHandler)completion
{
    [self.bundlesManager loadBundleWithId:remoteUIId completion:^(NSBundle *bundle, NSError *error) {

        UIStoryboard *storyboard = nil;
        if ([bundle URLForResource:remoteUIId withExtension:@"storyboardc"] != nil) {
            storyboard = [UIStoryboard storyboardWithName:remoteUIId bundle:bundle];
        }
        if (storyboard == nil) {
            // Hmm there isn't a storyboard that matches the name of the bundle/remote-id, so try finding any storyboard for now :okay:
            NSArray *storyboardUrls = [bundle URLsForResourcesWithExtension:@"storyboardc" subdirectory:nil];
            if (storyboardUrls.count > 0) {
                NSString *storyboardName = ((NSURL *)storyboardUrls[0]).lastPathComponent.stringByDeletingPathExtension;
                storyboard = [UIStoryboard storyboardWithName:storyboardName bundle:bundle];
            }
        }
        if (storyboard == nil && (error == nil || error.code == 404)) {
            error = [self uiNotFoundError];
        }

        LKViewController *viewController = nil;
        @try {
            viewController = [storyboard instantiateInitialViewController];
        }
        @catch (NSException *exception) {
            // In production, there seems to be an intermittent NSInternalConsistencyException
            // which causes a crash. A way to reproduce this is to take the .nib file *inside*
            // a .storyboardc file and either delete or rename it. (i.e. "WhatsNew.nib.fake")
            // It is unclear why this would be happening. Perhaps an unzipping error, or disk
            // corruption?
            LKLogError(@"Encountered error loading LK storyboard:\n%@", exception);
            NSError *nibLoadError = [NSError errorWithDomain:@"LKUIManagerError"
                                                        code:500
                                                    userInfo:@{@"underlyingException" : exception}];
            if (completion) {
                completion(nil, nibLoadError);
            }
            return;
        }
        @finally {
            // Code that gets executed whether or not an exception is thrown
        }
        // Set the related bundleinfo into the initialviewcontroller, useful later (for tracking)
        viewController.bundleInfo = [self.bundlesManager localBundleInfoWithName:remoteUIId];

        if ([UIPresentationController class]) {
            if ([viewController.presentationStyleName isEqualToString:@"card"]) {
                viewController.modalPresentationStyle = UIModalPresentationCustom;
                viewController.transitioningDelegate = self;
            }
        }
        if (viewController.transitioningDelegate != self) {
            // On iOS 7, we don't have a presentation controller to control our corner radius, so just
            // ensure that our corner radius is 0 (which is the default).
            // Since our .view hasn't loaded yet, we can't set the cornerRadius directly. Instead,
            // we'll use a custom property in our LKViewController to set a corner radius which *IT*
            // will set upon its -viewDidLoad:
            viewController.viewCornerRadius = 0.0;
        }
        if (completion) {
            completion(viewController, error);
        }
    }];
}


- (NSError *)uiNotFoundError
{
    return [[NSError alloc] initWithDomain:@"LKUIError"
                                      code:404
                                  userInfo:@{@"message" : @"UI with that name does not exist in your LaunchKit account"}];
}


#pragma mark - UIViewControllerTransitioningDelegate


- (UIPresentationController *)presentationControllerForPresentedViewController:(UIViewController *)presented presentingViewController:(UIViewController *)presenting sourceViewController:(UIViewController *)source
{
    if ([presented isKindOfClass:[LKViewController class]]) {
        if ([((LKViewController *)presented).presentationStyleName isEqualToString:@"card"]) {
            return [[LKCardPresentationController alloc] initWithPresentedViewController:presented presentingViewController:presenting];
        }
    }
    return nil;
}


#pragma mark - Presenting Remote UI

- (void)presentRemoteUIViewController:(LKViewController *)viewController fromViewController:(UIViewController *)presentingViewController animated:(BOOL)animated dismissalHandler:(LKRemoteUIDismissalHandler)dismissalHandler
{
    if (self.remoteUIPresentedController != nil) {
        // TODO(Riz): Auto-dismiss this view controller?
        [self dismissRemoteUIViewController:self.remoteUIPresentedController animated:NO withFlowResult:LKViewControllerFlowResultCancelled userInfo:nil];
    }
    if ([viewController isKindOfClass:[LKViewController class]]) {
        ((LKViewController *)viewController).flowDelegate = self;
    }
    self.remoteUIPresentedController = viewController;
    self.remoteUIPresentingController = presentingViewController;
    self.remoteUIControllerDismissalHandler = dismissalHandler;
    [self.remoteUIPresentingController presentViewController:self.remoteUIPresentedController animated:animated completion:nil];
    if (viewController.bundleInfo.name != nil) {
        [self markPresentationOfRemoteUI:viewController.bundleInfo.name];
    }
}


- (void)dismissRemoteUIViewController:(LKViewController *)controller animated:(BOOL)animated withFlowResult:(LKViewControllerFlowResult)flowResult userInfo:(NSDictionary *)userInfo
{
    if (self.remoteUIPresentedController == controller) {
        controller.flowDelegate = nil;

        UIViewController *presentingController = self.remoteUIPresentingController;

        self.remoteUIPresentingController = nil;
        self.remoteUIPresentedController = nil;
        LKRemoteUIDismissalHandler handler = self.remoteUIControllerDismissalHandler;
        self.remoteUIControllerDismissalHandler = nil;
        [presentingController dismissViewControllerAnimated:animated completion:^{

            if (handler != nil) {
                handler(flowResult);
            }
        }];
    }
}


#pragma mark - Onboarding UI


- (void)presentOnboardingUIOnWindow:(UIWindow *)window
                  completionHandler:(LKOnboardingUIDismissHandler)completionHandler;
{
    if (window == nil) {
        window = [UIApplication sharedApplication].keyWindow;
    }
    if (window == nil) {
        LKLogError(@"Cannot display onboarding UI. Window is not available");
        return;
    }
    self.onboardingWindow = window;
    LKOnboardingViewController *onboarding = [[LKOnboardingViewController alloc] init];
    self.postOnboardingRootViewController = window.rootViewController;

    // Present it without animation, just swap out root view controller
    self.onboardingWindow.rootViewController = onboarding;

    __weak LKUIManager *weakSelf = self;
    onboarding.dismissalHandler = ^(LKViewControllerFlowResult flowResult, LKBundleInfo *bundleInfo, NSDate *onboardingStartTime, NSDate *onboardingEndTime, NSTimeInterval preOnboardingDuration) {

        [weakSelf transitionToRootViewController:weakSelf.postOnboardingRootViewController inWindow:weakSelf.onboardingWindow animation:LKRootViewControllerAnimationModalPresentation completion:^{

            // Onboarding is done! First call
            if (completionHandler) {
                completionHandler(flowResult, bundleInfo, onboardingStartTime, onboardingEndTime, preOnboardingDuration);
            }

            // Cleanup
            weakSelf.onboardingWindow = nil;
            weakSelf.postOnboardingRootViewController = nil;

        }];

    };
    [self loadRemoteUIWithId:@"Onboarding" completion:^(LKViewController *viewController, NSError *error) {
        if (viewController == nil) {
            LKLogWarning(@"Unable to load remote onboarding UI, cancelling");
            [onboarding finishOnboardingWithResult:LKViewControllerFlowResultFailed];
            return;
        }
        [onboarding setActualOnboardingUI:viewController];
    }];
}

typedef NS_ENUM(NSInteger, LKRootViewControllerAnimation) {
    LKRootViewControllerAnimationNone,
    LKRootViewControllerAnimationModalDismiss,
    LKRootViewControllerAnimationModalPresentation,
};

- (void)transitionToRootViewController:(UIViewController *)toViewController
                              inWindow:(UIWindow *)window
                             animation:(LKRootViewControllerAnimation)animation
                            completion:(void (^)())completion
{
    void (^doneTransitioning)() = ^{
        if (completion) {
            completion();
        }
    };

    if (animation == LKRootViewControllerAnimationNone) {
        window.rootViewController = toViewController;
        doneTransitioning();
    } else if (animation == LKRootViewControllerAnimationModalDismiss) {
        NSTimeInterval duration = 0.35;
        [UIView transitionWithView:window duration:duration options:UIViewAnimationOptionAllowAnimatedContent animations:^{
            [window insertSubview:toViewController.view belowSubview:window.rootViewController.view];
            CGRect endFrame = window.rootViewController.view.frame;
            endFrame.origin.y += CGRectGetHeight(endFrame);
            window.rootViewController.view.frame = endFrame;
        } completion:^(BOOL finished) {
            window.rootViewController = toViewController;
            doneTransitioning();
        }];
    } else if (animation== LKRootViewControllerAnimationModalPresentation) {

        NSTimeInterval duration = 0.35;
        CGRect startFrame = window.bounds;
        startFrame.origin.y += CGRectGetHeight(startFrame);
        toViewController.view.frame = startFrame;
        [UIView transitionWithView:window duration:duration options:UIViewAnimationOptionAllowAnimatedContent animations:^{
            [window insertSubview:toViewController.view aboveSubview:window.rootViewController.view];
            toViewController.view.frame = window.bounds;
        } completion:^(BOOL finished) {
            window.rootViewController = toViewController;
            doneTransitioning();
        }];
    }
}


#pragma mark - LKViewControllerFlowDelegate


- (void)launchKitController:(nonnull LKViewController *)controller didFinishWithResult:(LKViewControllerFlowResult)result userInfo:(nullable NSDictionary *)userInfo
{
    [self dismissRemoteUIViewController:controller animated:YES withFlowResult:result userInfo:userInfo];
}


#pragma mark - Presentation Helpers

- (UIViewController *)currentPresentedViewController
{
    UIViewController *controller = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (controller.presentedViewController) {
        controller = controller.presentedViewController;
    }
    return controller;
}

- (UIView *)currentTopWindowView
{
    UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
    if (keyWindow) {
        // Thanks to Mixpanel here.
        for (UIView *subview in keyWindow.subviews) {
            if (!subview.hidden && subview.alpha > 0 && CGRectGetWidth(subview.frame) > 0 && CGRectGetHeight(subview.frame) > 0) {
                // First visible view that has some dimensions
                return subview;
            }
        }
    }
    return nil;
}

+ (BOOL)isPad
{
    static BOOL _isPad = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _isPad = [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad;
    });
    return _isPad;
}

#pragma mark - Locally recording which UI's have been shown (by bundle version)

- (void) restoreAppVersionsForPresentedBundleIdFromArchive
{
    NSDictionary *restored = [NSKeyedUnarchiver unarchiveObjectWithFile:[self appVersionsForPresentedBundleIdArchiveFilePath]];
    if (restored != nil) {
        [self.appVersionsForPresentedBundleId removeAllObjects];
        [self.appVersionsForPresentedBundleId addEntriesFromDictionary:restored];
    }
}


- (void) archiveAppVersionsForPresentedBundleId
{
    NSString *archiveFilePath = [self appVersionsForPresentedBundleIdArchiveFilePath];
    NSString *archiveParentDirectory = [archiveFilePath stringByDeletingLastPathComponent];
    NSError *archiveParentDirError = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:archiveParentDirectory withIntermediateDirectories:YES attributes:nil error:&archiveParentDirError];
    if (archiveParentDirError != nil) {
        LKLogWarning(@"Error trying to create UI prefs archive folder: %@", archiveParentDirError);
    }
    BOOL saved = [NSKeyedArchiver archiveRootObject:self.appVersionsForPresentedBundleId
                                             toFile:archiveFilePath];
    if (!saved) {
        LKLogWarning(@"Could not save app versions for presented UI's");
    }
}


- (NSString *)appVersionsForPresentedBundleIdArchiveFilePath
{
    // Library/Application Support/launchkit/ui/appVersionsForPresentedBundleId.plist
    NSString *appSupportDir = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).lastObject;
    NSString *launchKitDir = [appSupportDir stringByAppendingPathComponent:@"launchkit"];
    NSString *ui = [launchKitDir stringByAppendingPathComponent:@"ui"];
    NSString *filename = [NSString stringWithFormat:@"appVersionsForPresentedBundleId.plist"];
    return [ui stringByAppendingPathComponent:filename];
}


- (NSString *)currentAppVersionAndBuild
{
    NSDictionary *bundleDict = [[NSBundle mainBundle] infoDictionary];
    // Example: 1.5.2
    NSString *version = bundleDict[@"CFBundleShortVersionString"];
    if (!version || ![version isKindOfClass:[NSString class]]) {
        version = @"(unknown)";
    }
    // Example: 10
    NSString *build = bundleDict[@"CFBundleVersion"];
    if (!build || ![build isKindOfClass:[NSString class]]) {
        build = @"(unknown)";
    }
    // Example: 1.5.2-10
    return [NSString stringWithFormat:@"%@-%@", version, build];
}


- (void)markPresentationOfRemoteUI:(NSString *)remoteUIId
{
    NSSet *presentedInVersions = self.appVersionsForPresentedBundleId[remoteUIId];
    NSString *currentVersionAndBuild = [self currentAppVersionAndBuild];
    if (![presentedInVersions member:currentVersionAndBuild]) {
        if (presentedInVersions == nil) {
            presentedInVersions = [NSSet setWithObject:currentVersionAndBuild];
        } else {
            presentedInVersions = [presentedInVersions setByAddingObject:currentVersionAndBuild];
        }
        self.appVersionsForPresentedBundleId[remoteUIId] = presentedInVersions;
        [self archiveAppVersionsForPresentedBundleId];
    }
}


- (BOOL)remoteUIPresentedForThisAppVersion:(NSString *)remoteUIId
{
    NSSet *presentedInVersions = self.appVersionsForPresentedBundleId[remoteUIId];
    NSString *currentVersionAndBuild = [self currentAppVersionAndBuild];
    BOOL hasPresentedInThisVersion = [presentedInVersions member:currentVersionAndBuild] != nil;
    return hasPresentedInThisVersion;
}

@end
