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
        if (bundle != nil) {
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
        }
        if ((bundle == nil || storyboard == nil) && (error == nil || error.code == 404)) {
            error = [self uiNotFoundError];
            if (completion) {
                completion(nil, error);
            }
            return;
        }

        // At this point we have a valid storyboard, so try to load a vc inside
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
    } else {
        LKLogWarning(@"Main remote UI view controller is not of type LKViewController. It is a %@",
                     NSStringFromClass([viewController class]));
    }
    self.remoteUIPresentedController = viewController;
    self.remoteUIPresentingController = presentingViewController;
    self.remoteUIControllerDismissalHandler = ^(LKViewControllerFlowResult flowResult) {
        if (dismissalHandler) {
            dismissalHandler(flowResult);
        }
    };
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
    } else {
        LKLogWarning(@"Could not dismiss %@ as it doesn't match the current presented controller (%@).",
                     controller.bundleInfo.name,
                     self.remoteUIPresentedController.bundleInfo.name);
    }
}


#pragma mark - Onboarding UI


- (void)presentOnboardingUIOnWindow:(UIWindow *)window
                maxWaitTimeInterval:(NSTimeInterval)maxWaitTimeInterval
                  completionHandler:(LKOnboardingUICompletionHandler)completionHandler;
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
    if (maxWaitTimeInterval > 0.0) {
        onboarding.maxWaitTimeInterval = maxWaitTimeInterval;
    }
    self.postOnboardingRootViewController = window.rootViewController;

    // Present it without animation, just swap out root view controller
    self.onboardingWindow.rootViewController = onboarding;

    __weak LKUIManager *weakSelf = self;
    onboarding.dismissalHandler = ^(LKViewControllerFlowResult flowResult, NSDictionary *additionalFlowParameters, LKBundleInfo *bundleInfo, NSDate *onboardingStartTime, NSDate *onboardingEndTime, NSTimeInterval preOnboardingDuration) {

        [weakSelf transitionToRootViewController:weakSelf.postOnboardingRootViewController inWindow:weakSelf.onboardingWindow animation:LKRootViewControllerAnimationModalDismiss completion:^{

            // Onboarding is done! First record the UI event
            if (bundleInfo != nil) {
                NSMutableDictionary *resultInfo = [NSMutableDictionary dictionary];
                if (additionalFlowParameters) {
                    [resultInfo addEntriesFromDictionary:additionalFlowParameters];
                }
                [resultInfo addEntriesFromDictionary:@{@"flow_result" : NSStringFromViewControllerFlowResult(flowResult),
                                                       @"start_time": @(onboardingStartTime.timeIntervalSince1970),
                                                       @"end_time": @(onboardingEndTime.timeIntervalSince1970),
                                                       @"load_duration": @(preOnboardingDuration)
                                                       }];
                [weakSelf.delegate uiManagerRequestedToReportUIEvent:@"ui-shown"
                                                        uiBundleInfo:bundleInfo
                                                additionalParameters:resultInfo];
            }


            // Then call the completion
            if (completionHandler) {
                completionHandler(flowResult);
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

        [weakSelf.delegate uiManagerRequestedToReportUIEvent:@"ui-showing"
                                                uiBundleInfo:viewController.bundleInfo
                                        additionalParameters:nil];
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

    UIViewController *fromViewController = window.rootViewController;

    if (animation == LKRootViewControllerAnimationNone) {
        window.rootViewController = toViewController;
        doneTransitioning();
    } else if (animation == LKRootViewControllerAnimationModalDismiss) {

        CGRect endFrame = window.bounds;
        endFrame.origin.y += CGRectGetHeight(endFrame);

        window.rootViewController = toViewController;
        [window insertSubview:fromViewController.view aboveSubview:window.rootViewController.view];

        NSTimeInterval duration = 0.35;
        [UIView transitionWithView:window duration:duration options:UIViewAnimationOptionAllowAnimatedContent animations:^{
            fromViewController.view.frame = endFrame;
        } completion:^(BOOL finished) {
            [fromViewController.view removeFromSuperview];
            doneTransitioning();
        }];

    } else if (animation== LKRootViewControllerAnimationModalPresentation) {

        window.rootViewController = toViewController;
        [window insertSubview:fromViewController.view belowSubview:window.rootViewController.view];

        // Move rootVC off bounds to "animate" it in
        CGRect startFrame = window.bounds;
        startFrame.origin.y += CGRectGetHeight(startFrame);
        toViewController.view.frame = startFrame;

        NSTimeInterval duration = 0.35;
        [UIView transitionWithView:window duration:duration options:UIViewAnimationOptionAllowAnimatedContent animations:^{
            toViewController.view.frame = window.bounds;
        } completion:^(BOOL finished) {
            [fromViewController.view removeFromSuperview];
            doneTransitioning();
        }];

    }
}


#pragma mark - App Review Card
- (void) presentAppReviewCardIfNeededFromViewController:(nonnull UIViewController *)presentingViewController
                                             completion:(nullable LKAppReviewCardCompletionHandler)completion
{
    [self showUIWithName:@"AppReviewCard" fromViewController:presentingViewController completion:^(LKViewControllerFlowResult flowResult, NSError *error) {
        if (error) {
            LKLogError(@"AppReviewCard presentation failed due to error: %@", error);
        }
        if (completion) {
            completion(flowResult);
        }
    }];
}


#pragma mark - App Release Notes
- (void) presentAppReleaseNotesFromViewController:(nonnull UIViewController *)viewController
                                       completion:(nullable LKReleaseNotesCompletionHandler)completion
{
    [self showUIWithName:@"WhatsNew" fromViewController:viewController completion:^(LKViewControllerFlowResult flowResult, NSError *error) {
        BOOL didPresent = flowResult == LKViewControllerFlowResultCompleted || flowResult == LKViewControllerFlowResultCancelled;
        if (completion) {
            completion(didPresent);
        }
    }];
}

#pragma mark -

- (void)showUIWithName:(NSString *)uiName fromViewController:(UIViewController *)presentingViewController completion:(void (^)(LKViewControllerFlowResult flowResult, NSError *error))completion
{
    __weak LKUIManager *weakSelf = self;
    [self loadRemoteUIWithId:uiName completion:^(LKViewController *viewController, NSError *error) {
        if (viewController) {
            // Notify LaunchKit that this view controller is being displayed
            [weakSelf.delegate uiManagerRequestedToReportUIEvent:@"ui-showing"
                                                uiBundleInfo:viewController.bundleInfo
                                        additionalParameters:nil];

            [weakSelf presentRemoteUIViewController:viewController fromViewController:presentingViewController animated:YES dismissalHandler:^(LKViewControllerFlowResult flowResult) {

                // report that the UI was shown
                if (viewController.bundleInfo != nil) {
                    // Notify LaunchKit that this view controller has been displayed
                    NSString *flowResultString = NSStringFromViewControllerFlowResult(flowResult);
                    [weakSelf.delegate uiManagerRequestedToReportUIEvent:@"ui-shown"
                                                            uiBundleInfo:viewController.bundleInfo
                                                    additionalParameters:@{@"flow_result" : flowResultString}];
                }

                if (completion) {
                    completion(flowResult, nil);
                }
            }];
        } else {
            if (completion) {
                completion(LKViewControllerFlowResultFailed, error);
            }
        }
    }];
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
