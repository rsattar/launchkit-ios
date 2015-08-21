//
//  LKUIManager.m
//  Pods
//
//  Created by Rizwan Sattar on 1/19/15.
//
//

#import "LKUIManager.h"

#import "LaunchKitShared.h"
#import "LKCardPresentationController.h"
#import "LKLog.h"

@interface LKUIManager () <LKViewControllerFlowDelegate, UIViewControllerTransitioningDelegate>

@property (strong, nonatomic) LKBundlesManager *bundlesManager;

@property (strong, nonatomic) LKViewController *remoteUIPresentedController;
@property (weak, nonatomic) UIViewController *remoteUIPresentingController;
@property (copy, nonatomic) LKRemoteUIDismissalHandler remoteUIControllerDismissalHandler;

@end

@implementation LKUIManager

- (instancetype)initWithBundlesManager:(LKBundlesManager *)bundlesManager
{
    self = [super init];
    if (self) {
        self.bundlesManager = bundlesManager;
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

        LKViewController *viewController = [storyboard instantiateInitialViewController];

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
}


- (void)dismissRemoteUIViewController:(LKViewController *)controller animated:(BOOL)animated withFlowResult:(LKViewControllerFlowResult)flowResult userInfo:(NSDictionary *)userInfo
{
    if (self.remoteUIPresentedController == controller) {
        controller.flowDelegate = nil;

        [self.remoteUIPresentingController dismissViewControllerAnimated:animated completion:^{
            self.remoteUIPresentingController = nil;
            self.remoteUIPresentedController = nil;
            if (self.remoteUIControllerDismissalHandler != nil) {
                self.remoteUIControllerDismissalHandler(flowResult);
                self.remoteUIControllerDismissalHandler = nil;
            }
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

@end
