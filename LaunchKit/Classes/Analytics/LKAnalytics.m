//
//  LKAnalytics.m
//  LaunchKit
//
//  Created by Rizwan Sattar on 8/13/15.
//
//

#import "LKAnalytics.h"

#import "LKLog.h"
#import "LKUtils.h"

NSString *const LKAppUserUpdatedNotificationName = @"LKAppUserUpdatedNotificationName";
NSString *const LKPreviousAppUserKey = @"LKPreviousAppUserKey";
NSString *const LKCurrentAppUserKey = @"LKCurrentAppUserKey";

static NSUInteger const VISITED_VIEW_CONTROLLERS_BUFFER_SIZE = 50;
static NSUInteger const TAP_BATCHES_BUFFER_SIZE = 5;
static NSUInteger const RECORDED_TAPS_BUFFER_SIZE = 200;

@interface LKAnalytics () <UIGestureRecognizerDelegate>

// TODO(Riz): We don't really need this, just need it for getting serverTimeOffset
@property (strong, nonatomic) LKAPIClient *apiClient;

// Turn on/off the entire module
@property (assign, nonatomic) BOOL analyticsEnabled;

// Tracking the app's UI
@property (assign, nonatomic) BOOL shouldReportScreens;
@property (strong, nonatomic) NSTimer *currentViewControllerInspectionTimer;
@property (strong, nonatomic) NSString *currentViewControllerClassName;
@property (strong, nonatomic) NSDate *currentViewControllerStartTimestamp;
@property (strong, nonatomic) NSMutableArray *viewControllersVisited;

// Detecting taps
@property (assign, nonatomic) BOOL shouldReportTaps;
@property (strong, nonatomic) UITapGestureRecognizer *tapRecognizer;
@property (strong, nonatomic) NSMutableArray *tapBatches;
@property (assign, nonatomic) CGSize currentWindowSize;
@property (strong, nonatomic) NSMutableArray *currentBatchTaps;

// Current User Info
@property (strong, nonatomic) LKAppUser *user;
@property (strong, nonatomic) NSDictionary *lastUserDictionary;

@end

@implementation LKAnalytics

- (instancetype)initWithAPIClient:(LKAPIClient *)apiClient
{
    self = [super init];
    if (self) {
        self.apiClient = apiClient;
        self.analyticsEnabled = YES;
        self.shouldReportScreens = YES;
        self.shouldReportTaps = YES;
        self.viewControllersVisited = [NSMutableArray arrayWithCapacity:VISITED_VIEW_CONTROLLERS_BUFFER_SIZE];
        self.tapBatches = [NSMutableArray arrayWithCapacity:TAP_BATCHES_BUFFER_SIZE];
    }
    return self;
}

- (void)dealloc
{
    [self destroyListeners];
    [self stopDetectingTapsOnWindow];
}

- (NSDictionary *)commitTrackableProperties;
{
    NSMutableDictionary *propertiesToInclude = [NSMutableDictionary dictionaryWithCapacity:2];
    if (self.viewControllersVisited.count && self.analyticsEnabled) {
        propertiesToInclude[@"screens"] = [self.viewControllersVisited copy];
    }

    [self commitCurrentTapsAtWindowSize:self.currentWindowSize];
    if (self.tapBatches.count && self.analyticsEnabled) {
        propertiesToInclude[@"tapBatches"] = [self.tapBatches copy];
    }

    [self.viewControllersVisited removeAllObjects];
    [self.tapBatches removeAllObjects];
    [self.currentBatchTaps removeAllObjects];

    return propertiesToInclude;
}

- (void) updateAnalyticsEnabled:(BOOL)analyticsEnabled
{
    if (self.analyticsEnabled == analyticsEnabled) {
        return;
    }

    self.analyticsEnabled = analyticsEnabled;

    // regardless of whether they were already being measured
    // start/stop timers and recognizers
    [self handleScreenReportingStateChange];
    [self handleTapReportingStateChange];
}

- (void) updateReportingScreens:(BOOL)shouldReport
{
    if (self.shouldReportScreens == shouldReport) {
        return;
    }
    self.shouldReportScreens = shouldReport;
    [self handleScreenReportingStateChange];

    if (self.verboseLogging) {
        LKLog(@"Report Screens turned %@ via remote command", (self.shouldReportScreens ? @"on" : @"off"));
    }
}

// Actually start/stop screen reporting systems, based on 'shouldReportScreens'
- (void) handleScreenReportingStateChange
{
    UIApplicationState state = [UIApplication sharedApplication].applicationState;
    if (self.shouldReportScreens) {
        if (state == UIApplicationStateActive) {
            [self restartInspectingCurrentViewController];
        }
    } else {
        [self stopInspectingCurrentViewController];
        // Clear out our current visitation
        [self markEndOfVisitationForCurrentViewController];
    }
}

- (void) updateReportingTaps:(BOOL)shouldReport
{
    if (self.shouldReportTaps == shouldReport) {
        return;
    }
    self.shouldReportTaps = shouldReport;
    [self handleTapReportingStateChange];

    if (self.verboseLogging) {
        LKLog(@"Report Taps turned %@ via remote command", (self.shouldReportTaps ? @"on" : @"off"));
    }
}

// Actually start/stop tap reporting systems, based on'shouldReportTaps'
- (void) handleTapReportingStateChange
{
    UIApplicationState state = [UIApplication sharedApplication].applicationState;
    if (self.shouldReportTaps) {
        if (state == UIApplicationStateActive) {
            [self startDetectingTapsOnWindow];
        }
    } else {
        [self stopDetectingTapsOnWindow];
    }
}

#pragma mark - Screen Detection

- (void)restartInspectingCurrentViewController
{
    if (!self.analyticsEnabled) {
        return;
    }
    [self stopInspectingCurrentViewController];
    [self inspectCurrentViewController];
    self.currentViewControllerInspectionTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
                                                                                 target:self
                                                                               selector:@selector(inspectCurrentViewController)
                                                                               userInfo:nil
                                                                                repeats:YES];
}

- (void)stopInspectingCurrentViewController
{
    if (self.currentViewControllerInspectionTimer.isValid) {
        [self.currentViewControllerInspectionTimer invalidate];
    }
    self.currentViewControllerInspectionTimer = nil;
}

- (void)inspectCurrentViewController
{
    if (!self.analyticsEnabled) {
        return;
    }
    UIViewController *rootViewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    UIViewController *currentViewController = [self presentedViewControllerInViewController:rootViewController];
    NSString *className = NSStringFromClass([currentViewController class]);
    if (![className isEqualToString:self.currentViewControllerClassName]) {
        [self markEndOfVisitationForCurrentViewController];
        self.currentViewControllerClassName = className;
        self.currentViewControllerStartTimestamp = [NSDate date]; // We'll apply the serverTimeOffset only when recording
        LKLog(@"Current View Controller: %@", self.currentViewControllerClassName);
    }
}

- (void)markEndOfVisitationForCurrentViewController
{
    if (!self.analyticsEnabled) {
        return;
    }
    if (self.currentViewControllerClassName.length && self.currentViewControllerStartTimestamp) {
        NSInteger numToBeOverMax = (self.viewControllersVisited.count+1)-VISITED_VIEW_CONTROLLERS_BUFFER_SIZE;
        if (numToBeOverMax > 0) {
            [self.viewControllersVisited removeObjectsInRange:NSMakeRange(0, numToBeOverMax)];
        }
        // Save in a format that we can easily send up to server
        NSDate *now = [NSDate date];
        [self.viewControllersVisited addObject:@{@"name" : self.currentViewControllerClassName,
                                                 @"start" : @(self.currentViewControllerStartTimestamp.timeIntervalSince1970+self.apiClient.serverTimeOffset),
                                                 @"end" : @(now.timeIntervalSince1970+self.apiClient.serverTimeOffset)}];
        NSTimeInterval duration = [now timeIntervalSinceDate:self.currentViewControllerStartTimestamp];
        LKLog(@"%@ seen for about %.0fs", self.currentViewControllerClassName, duration);
        self.currentViewControllerClassName = nil;
        self.currentViewControllerStartTimestamp = nil;
    }
}


- (UIViewController *)presentedViewControllerInViewController:(UIViewController *)viewController
{
    if (viewController.presentedViewController) {

        return [self presentedViewControllerInViewController:viewController.presentedViewController];

    } else if ([viewController isKindOfClass:[UITabBarController class]]) {

        UITabBarController *tabBarController = (UITabBarController *)viewController;
        if (tabBarController.selectedViewController) {
            return [self presentedViewControllerInViewController:tabBarController.selectedViewController];
        } else {
            return tabBarController;
        }
        return [self presentedViewControllerInViewController:tabBarController.selectedViewController];

    } else if ([viewController isKindOfClass:[UINavigationController class]]) {

        UINavigationController *navController = (UINavigationController *)viewController;
        if (navController.topViewController) {
            return [self presentedViewControllerInViewController:navController.topViewController];
        }
    } else if ([viewController isKindOfClass:[UISplitViewController class]]) {

        UISplitViewController *splitViewController = (UISplitViewController *)viewController;

        BOOL returnSingleViewController = (splitViewController.viewControllers.count == 1);
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
        if ([splitViewController respondsToSelector:@selector(displayMode)]) {
            if (splitViewController.displayMode == UISplitViewControllerDisplayModePrimaryHidden) {
                returnSingleViewController = YES;
            }
        }
#endif
        if (returnSingleViewController) {
            // One VC is collapsed
            return [self presentedViewControllerInViewController:splitViewController.viewControllers.lastObject];
        } else {
            // iOS 7
            // TODO(Riz): Perhaps on iPad portrait, ask split view's delegate whether the primary vc
            // should be hidden
            return splitViewController;
        }
    }
    // Nothing to dive into, just return the view controller passed in
    return viewController;
}


#pragma mark - Detecting Taps

- (void)startDetectingTapsOnWindow
{
    if (!self.analyticsEnabled) {
        return;
    }
    if (!self.tapRecognizer) {
        self.tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleWindowTap:)];
        self.tapRecognizer.cancelsTouchesInView = NO;
        self.tapRecognizer.delegate = self;
    }
    self.currentWindowSize = [LKUtils currentWindowSize];
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    [window addGestureRecognizer:self.tapRecognizer];
}

- (void)stopDetectingTapsOnWindow
{
    // First, commit any batches of taps we may have
    [self commitCurrentTapsAtWindowSize:self.currentWindowSize];

    if (self.tapRecognizer.view) {
        [self.tapRecognizer.view removeGestureRecognizer:self.tapRecognizer];
    }
    self.tapRecognizer.delegate = nil;
    self.tapRecognizer = nil;
}

/// Will not commit if there are no taps. If commited, will reset the taps collecting array
- (void)commitCurrentTapsAtWindowSize:(CGSize)windowSize
{
    if (!self.analyticsEnabled) {
        return;
    }
    if (self.currentBatchTaps.count > 0) {
        // Commit our current batch of taps at this window size
        NSDictionary *batch = @{@"screen" : @{@"w" : @(self.currentWindowSize.width),
                                              @"h" : @(self.currentWindowSize.height)},
                                @"taps" : [self.currentBatchTaps copy]};
        [self.tapBatches addObject:batch];
        [self.currentBatchTaps removeAllObjects];
    }
}

- (void)handleWindowTap:(UITapGestureRecognizer *)recognizer
{
    if (!self.analyticsEnabled) {
        return;
    }
    if (recognizer.state != UIGestureRecognizerStateEnded) {
        return;
    }

    CGSize windowSize = [LKUtils currentWindowSize];

    if (!CGSizeEqualToSize(self.currentWindowSize, windowSize)) {
        // This new tap is in a new window size, so record our old taps into a
        // batch, based on the old window size
        [self commitCurrentTapsAtWindowSize:self.currentWindowSize];
        // Update to new window size
        self.currentWindowSize = windowSize;
    }

    if (!self.currentBatchTaps) {
        // We've not recorded any taps until now, so start collecting them
        self.currentBatchTaps = [NSMutableArray arrayWithCapacity:RECORDED_TAPS_BUFFER_SIZE];
    }

    CGPoint touchPoint = [recognizer locationInView:nil];
    CGRect frame = recognizer.view.bounds;

    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    if (![UIViewController instancesRespondToSelector:@selector(traitCollection)]) {
        // iOS 7 and below...
        BOOL isLandscape = NO;
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
        UIInterfaceOrientation orientation = window.rootViewController.interfaceOrientation;
#pragma GCC diagnostic pop
        isLandscape = UIInterfaceOrientationIsLandscape(orientation);

        // We have to transform the rect ourselves for landscape
        if (orientation != UIInterfaceOrientationPortrait) {
            double angle = [LKAnalytics angleForInterfaceOrientation:orientation];
            CGAffineTransform rotationTransform = CGAffineTransformMakeRotation((float)angle);
            frame = CGRectApplyAffineTransform(frame, rotationTransform);
            frame.origin = CGPointZero;

            if (isLandscape) {
                CGFloat tmp = touchPoint.x;
                touchPoint.x = touchPoint.y;
                touchPoint.y = tmp;
                if (orientation == UIInterfaceOrientationLandscapeLeft) {
                    touchPoint.x = CGRectGetWidth(frame)-touchPoint.x;
                } else if (orientation == UIInterfaceOrientationLandscapeRight) {
                    touchPoint.y = CGRectGetHeight(frame)-touchPoint.y;
                }
            } else if (orientation == UIInterfaceOrientationPortraitUpsideDown) {
                touchPoint.x = CGRectGetWidth(frame)-touchPoint.x;
                touchPoint.y = CGRectGetHeight(frame)-touchPoint.y;
            }
        }
    } else {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
        CGPoint zeroPoint = CGPointMake(0, 0);
        CGFloat offsetX = ABS([window convertPoint:zeroPoint fromCoordinateSpace:window.screen.coordinateSpace].x);
        if ([window.screen respondsToSelector:@selector(fixedCoordinateSpace)]) {
            touchPoint = [window convertPoint:touchPoint fromCoordinateSpace:window.screen.fixedCoordinateSpace];
        }
        touchPoint.x += offsetX;
#endif
    }
    if (self.verboseLogging) {
        LKLog(@"Tapped %@ within %@", NSStringFromCGPoint(touchPoint), NSStringFromCGRect(frame));
    }
    NSInteger numToBeOverMax = (self.currentBatchTaps.count+1)-RECORDED_TAPS_BUFFER_SIZE;
    if (numToBeOverMax > 0) {
        // TODO(Riz): Instead of dropping taps, maybe store another batch, or persist some to disk?
        [self.currentBatchTaps removeObjectsInRange:NSMakeRange(0, numToBeOverMax)];
    }
    [self.currentBatchTaps addObject:@{@"x" : @(touchPoint.x),
                                       @"y" : @(touchPoint.y),
                                       @"time" : @([NSDate date].timeIntervalSince1970 + self.apiClient.serverTimeOffset)}];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

#pragma mark - Listening to system/application events


- (void)createListeners
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];

    // App Lifecycle events
    [center addObserver:self
               selector:@selector(applicationWillTerminate:)
                   name:UIApplicationWillTerminateNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(applicationWillResignActive:)
                   name:UIApplicationWillResignActiveNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(applicationDidBecomeActive:)
                   name:UIApplicationDidBecomeActiveNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(applicationDidEnterBackground:)
                   name:UIApplicationDidEnterBackgroundNotification
                 object:nil];
    /*
     [center addObserver:self
     selector:@selector(applicationWillEnterForeground:)
     name:UIApplicationWillEnterForegroundNotification
     object:nil];
     */

    [center addObserver:self
               selector:@selector(applicationDidEndIgnoringInteractionEvents:)
                   name:@"_UIApplicationDidEndIgnoringInteractionEventsNotification"
                 object:nil];
    [center addObserver:self
               selector:@selector(navigationControllerDidShowViewControllerNotification:)
                   name:@"UINavigationControllerDidShowViewControllerNotification"
                 object:nil];
}


- (void)destroyListeners
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Application Lifecycle Events

- (void)applicationWillTerminate:(NSNotification *)notification
{
}

- (void)applicationWillResignActive:(NSNotification *)notification
{
    [self stopInspectingCurrentViewController];
    // Clear out our current visitation
    [self markEndOfVisitationForCurrentViewController];
    [self stopDetectingTapsOnWindow];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    if (self.shouldReportScreens) {
        [self restartInspectingCurrentViewController];
    }
    if (!self.tapRecognizer && self.shouldReportTaps) {
        [self startDetectingTapsOnWindow];
    }
}

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
}

// Called usually after a modal presentation animation ends
- (void)applicationDidEndIgnoringInteractionEvents:(NSNotification *)notification
{
    UIApplicationState state = [UIApplication sharedApplication].applicationState;
    if (state == UIApplicationStateActive && self.shouldReportScreens) {
        [self restartInspectingCurrentViewController];
    }
}

- (void)navigationControllerDidShowViewControllerNotification:(NSNotification *)notification
{
    UIApplicationState state = [UIApplication sharedApplication].applicationState;
    if (state == UIApplicationStateActive && self.shouldReportScreens) {
        [self restartInspectingCurrentViewController];
    }
}


#pragma mark - Current User Data


- (void) updateUserFromDictionary:(NSDictionary *)dictionary reportUpdate:(BOOL)reportUpdate
{
    // Sanity check, in case we get a bad parameter (e.g. NSNull from bad JSON)
    if (![dictionary isKindOfClass:[NSDictionary class]]) {
        return;
    }
    if (self.user != nil && [self.lastUserDictionary isEqualToDictionary:dictionary]) {
        return;
    }
    if (self.verboseLogging) {
        LKLog(@"User object is different, notifying");
    }
    LKAppUser *currentUser = [[LKAppUser alloc] initWithDictionary:dictionary];
    // TODO(Riz): Figure out what is different and include in change notification
    LKAppUser *previousUser = self.user;
    self.user = currentUser;
    self.lastUserDictionary = dictionary;
    if (reportUpdate) {
        NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithCapacity:2];
        if (previousUser != nil) {
            userInfo[LKPreviousAppUserKey] = previousUser;
        }
        if (currentUser != nil) {
            userInfo[LKCurrentAppUserKey] = currentUser;
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:LKAppUserUpdatedNotificationName
                                                            object:self
                                                          userInfo:userInfo];
    }
}


#pragma mark - Convenience Methods

// Thanks, Mixpanel
+ (double)angleForInterfaceOrientation:(UIInterfaceOrientation)orientation
{
    switch (orientation) {
        case UIInterfaceOrientationLandscapeLeft:
            return -M_PI_2;
        case UIInterfaceOrientationLandscapeRight:
            return M_PI_2;
        case UIInterfaceOrientationPortraitUpsideDown:
            return M_PI;
        default:
            return 0.0;
    }
}

- (CGRect)frameFixedForOrientation:(UIInterfaceOrientation)interfaceOrientation fromFrame:(CGRect)sourceFrame
{
    // Thanks to Mixpanel here...
    CGRect transformedFrame;
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= 80000
    // Guaranteed running iOS 8 and above (which fixes window coordinates for orientation)
    transformedFrame = sourceFrame;
#elif __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
    // iOS 8 is possible, but could be running lower, so check for iOS 8
    if ([[UIViewController class] instancesRespondToSelector:@selector(viewWillTransitionToSize:withTransitionCoordinator:)]) {
        transformedFrame = sourceFrame;
    } else {
        double angle = [LKAnalytics angleForInterfaceOrientation:interfaceOrientation];
        transformedFrame = CGRectApplyAffineTransform(sourceFrame, CGAffineTransformMakeRotation((float)angle));
    }
#else
    // Guaranteed running iOS 7 and below
    double angle = [self angleForInterfaceOrientation:[self interfaceOrientation]];
    transformedFrame = CGRectApplyAffineTransform(sourceFrame, CGAffineTransformMakeRotation((float)angle));
#endif
    return transformedFrame;
}

@end
