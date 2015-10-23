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

@interface LKUIManager () <LKViewControllerFlowDelegate, UIViewControllerTransitioningDelegate>

@property (strong, nonatomic) LKBundlesManager *bundlesManager;

@property (strong, nonatomic) LKViewController *remoteUIPresentedController;
@property (weak, nonatomic) UIViewController *remoteUIPresentingController;
@property (copy, nonatomic) LKRemoteUIDismissalHandler remoteUIControllerDismissalHandler;

@property (strong, nonatomic) NSMutableDictionary *appVersionsForPresentedBundleId;

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


- (NSString *)currentAppVersion
{
    // Example: 1.5.2
    NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    if (!version) {
        version = @"(unknown)";
    }
    return version;
}


- (void)markPresentationOfRemoteUI:(NSString *)remoteUIId
{
    NSSet *presentedInVersions = self.appVersionsForPresentedBundleId[remoteUIId];
    NSString *currentVersion = [self currentAppVersion];
    if (![presentedInVersions member:currentVersion]) {
        if (presentedInVersions == nil) {
            presentedInVersions = [NSSet setWithObject:currentVersion];
        } else {
            presentedInVersions = [presentedInVersions setByAddingObject:currentVersion];
        }
        self.appVersionsForPresentedBundleId[remoteUIId] = presentedInVersions;
        [self archiveAppVersionsForPresentedBundleId];
    }
}


- (BOOL)remoteUIPresentedForThisAppVersion:(NSString *)remoteUIId
{
    NSSet *presentedInVersions = self.appVersionsForPresentedBundleId[remoteUIId];
    NSString *currentVersion = [self currentAppVersion];
    BOOL hasPresentedInThisVersion = [presentedInVersions member:currentVersion] != nil;
    return hasPresentedInThisVersion;
}

@end
