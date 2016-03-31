//
//  LaunchKit.m
//  LaunchKit
//
//  Created by Cluster Labs, Inc. on 1/13/15.
//
//

#import "LaunchKit.h"

#import "LKAnalytics.h"
#import "LKAPIClient.h"
#import "LKBundlesManager.h"
#import "LKLog.h"
#import "LKTrackOperation.h"
#import "LKUIManager.h"

#define DEBUG_DESTROY_BUNDLE_CACHE_ON_START 0
#define DEBUG_MEASURE_USAGE 0

static NSTimeInterval const DEFAULT_TRACKING_INTERVAL = 30.0;
static NSTimeInterval const MIN_TRACKING_INTERVAL = 5.0;

static BOOL USE_LOCAL_LAUNCHKIT_SERVER = NO;
static NSString* const BASE_API_URL_REMOTE = @"https://api.launchkit.io/";
static NSString* const BASE_API_URL_LOCAL = @"http://localhost:9101/";

static NSTimeInterval const DEFAULT_MAX_ONBOARDING_WAIT_TIME_INTERVAL = 15.0;

#pragma mark - Extending LKConfig to allow LaunchKit to modify parameters

@interface LKConfig (Private)

@property (weak, nonatomic, nullable) id <LKConfigDelegate> delegate;
@property (readwrite, strong, nonatomic, nonnull) NSDictionary *parameters;
- (BOOL) updateParameters:(NSDictionary  * __nullable)parameters;
- (nullable NSDate *) dateForKey:(NSString * __nonnull)key defaultValue:(nullable NSDate *)defaultValue;

@end

#pragma mark - Extension LKAnalytics to allow LaunchKit to access some parameters
@interface LKAnalytics (Private)

@property (strong, nonatomic) NSDictionary *lastUserDictionary;

@end

#pragma mark - Extend LKAppUser to allow debugging super user status
@interface LKAppUser (Private)
+ (BOOL)debugUserIsAlwaysSuper;
+ (void)setDebugUserIsAlwaysSuper:(BOOL)alwaysSuper;
@end

#pragma mark - Extend LKBundlesManager to allow access to some methods
@interface LKBundlesManager (Private)
- (void)updateFromPreviousState:(nullable NSDictionary *)state;
- (nonnull NSDictionary *)stateDictionary;
@end

#pragma mark - LaunchKit Implementation

@interface LaunchKit () <LKBundlesManagerDelegate, LKConfigDelegate, LKUIManagerDelegate>

@property (copy, nonatomic) NSString *apiToken;

/** Long-lived, persistent dictionary that is sent up with API requests. */
@property (copy, nonatomic) NSDictionary *sessionParameters;

@property (strong, nonatomic) LKAPIClient *apiClient;
@property (strong, nonatomic) NSTimer *trackingTimer;
@property (assign, nonatomic) BOOL intervalTrackingEnabled;
@property (assign, nonatomic) NSInteger numTrackingRequestsCompleted;
@property (assign, nonatomic) NSTimeInterval trackingInterval;
@property (assign, nonatomic) BOOL trackingRequestInProgress;
// LaunchKit executes track requests sequentially, so queue them
// manually. Can't use an NSOperationQueue here because completion
// blocks are not guaranteed to fire before next operation starts.
@property (strong, nonatomic) NSMutableArray *trackingRequests;

@property (strong, nonatomic) NSDate *launchTime;

// Usage measurement
@property (assign, nonatomic) BOOL debugMeasureUsage;

// Analytics
@property (strong, nonatomic) LKAnalytics *analytics;

// Config
@property (readwrite, strong, nonatomic, nonnull) LKConfig *config;
@property (readwrite, strong, nonatomic, nonnull) NSMutableArray <void (^)()>*configReadyBlocks;

// Displaying UI
@property (strong, nonatomic) LKUIManager *uiManager;

// Bundles Manager
@property (strong, nonatomic) LKBundlesManager *bundlesManager;

@end

@implementation LaunchKit

static LaunchKit *_sharedInstance;

+ (nonnull instancetype)launchWithToken:(nonnull NSString *)apiToken
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[LaunchKit alloc] initWithToken:apiToken];
    });
    return _sharedInstance;
}


+ (nonnull instancetype)sharedInstance
{
    if (_sharedInstance == nil) {
        LKLogWarning(@"sharedInstance called before +launchWithToken:");
    }
    return _sharedInstance;
}


+ (BOOL) hasLaunched
{
    return (_sharedInstance != nil);
}


- (nonnull instancetype)initWithToken:(NSString *)apiToken
{
    self = [super init];
    if (self) {
        LKLog(@"Creating LaunchKit...");
        if (apiToken == nil) {
            apiToken = @"";
        }
        if (apiToken.length == 0) {
            LKLogError(@"Invalid or empty api token. Please get one from https://launchkit.io/tokens for your team.");
        }
        self.apiToken = apiToken;

        self.launchTime = [NSDate date];

        self.apiClient = [[LKAPIClient alloc] init];
        if (USE_LOCAL_LAUNCHKIT_SERVER) {
            self.apiClient.serverURL = BASE_API_URL_LOCAL;
        } else {
            self.apiClient.serverURL = BASE_API_URL_REMOTE;
        }
        self.apiClient.apiToken = self.apiToken;

#if DEBUG_MEASURE_USAGE
        self.debugMeasureUsage = YES;
        self.apiClient.measureUsage = YES;
#endif

        self.maxOnboardingWaitTimeInterval = DEFAULT_MAX_ONBOARDING_WAIT_TIME_INTERVAL;

        self.bundlesManager = [[LKBundlesManager alloc] initWithAPIClient:self.apiClient];
        self.bundlesManager.delegate = self;

        self.intervalTrackingEnabled = YES;
        self.trackingInterval = DEFAULT_TRACKING_INTERVAL;
        self.trackingRequests = [NSMutableArray array];

        self.uiManager = [[LKUIManager alloc] initWithBundlesManager:self.bundlesManager];
        self.uiManager.delegate = self;

        // Prepare the different tools and unarchive session
        self.sessionParameters = @{};
        self.config = [[LKConfig alloc] initWithParameters:nil];
        self.config.delegate = self;
        self.configReadyBlocks = [NSMutableArray arrayWithCapacity:1];
        self.analytics = [[LKAnalytics alloc] initWithAPIClient:self.apiClient];
        [self retrieveSessionFromArchiveIfAvailable];


        id rawTrackingInterval = self.sessionParameters[@"track_interval"];
        if ([rawTrackingInterval isKindOfClass:[NSNumber class]]) {
            self.trackingInterval = MAX([rawTrackingInterval doubleValue], MIN_TRACKING_INTERVAL);
            if (self.trackingInterval != [rawTrackingInterval doubleValue]) {
                // Our session parameter value is not the same as the value we'll use, so update
                // the session parameter
                NSMutableDictionary *newSessionParameters = [self.sessionParameters mutableCopy];
                newSessionParameters[@"track_interval"] = @(self.trackingInterval);
                self.sessionParameters = newSessionParameters;
            }
        }

        [self createListeners];

        // TODO(Riz): Move this to within LKBundlesManager
#if DEBUG_DESTROY_BUNDLE_CACHE_ON_START
        [LKBundlesManager deleteBundlesCacheDirectory];
#endif

        // TODO(Riz): Move this to within LKBundlesManager
        [self.bundlesManager rebuildLocalBundlesMap];
    }
    return self;
}

- (void)dealloc
{
    [self destroyListeners];
}

- (void)setDebugMode:(BOOL)debugMode
{
    _debugMode = debugMode;
    self.analytics.debugMode = debugMode;
    LKLOG_ENABLED = _debugMode || _verboseLogging;
    self.bundlesManager.debugMode = debugMode;
}

- (void)setVerboseLogging:(BOOL)verboseLogging
{
    _verboseLogging = verboseLogging;
    LKLOG_ENABLED = _debugMode || _verboseLogging;
    self.apiClient.verboseLogging = verboseLogging;
    self.analytics.verboseLogging = verboseLogging;
    self.bundlesManager.verboseLogging = verboseLogging;
}

- (NSString *)version
{
    return LAUNCHKIT_VERSION;
}

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
    [center addObserver:self
               selector:@selector(applicationDidReceiveMemoryWarning:)
                   name:UIApplicationDidReceiveMemoryWarningNotification
                 object:nil];
    /*
    [center addObserver:self
               selector:@selector(applicationWillEnterForeground:)
                   name:UIApplicationWillEnterForegroundNotification
                 object:nil];
     */

    [self.analytics createListeners];
}


- (void)destroyListeners
{
    [self.analytics destroyListeners];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Session Parameters

- (void)setSessionParameters:(NSDictionary *)sessionParameters
{
    _sessionParameters = sessionParameters;
    self.apiClient.sessionParameters = sessionParameters;
}

#pragma mark - Tracking

- (void)restartTrackingFireImmediately:(BOOL)fireFirstTimeImmediately
{
    if (self.trackingTimer == nil || !self.trackingTimer.isValid) {
        if (self.verboseLogging) {
            LKLog(@"Starting Tracking");
        }
    }
    [self stopTracking];
    if (fireFirstTimeImmediately) {
        [self trackingTimerFired];
    }
    self.trackingTimer = [NSTimer scheduledTimerWithTimeInterval:self.trackingInterval
                                                          target:self
                                                        selector:@selector(trackingTimerFired)
                                                        userInfo:nil
                                                         repeats:YES];
    if ([self.trackingTimer respondsToSelector:@selector(setTolerance:)]) {
        self.trackingTimer.tolerance = self.trackingInterval * 0.1; // Allow 10% tolerance
    }
}

- (void)stopTracking
{
    if (self.trackingTimer.isValid) {
        if (self.verboseLogging) {
            LKLog(@"Stopping Tracking");
        }
        [self.trackingTimer invalidate];

        if (self.debugMeasureUsage) {
            [self printUsageMeasurements];
        }
    }
    self.trackingTimer = nil;
}

- (void)trackingTimerFired
{
    [self trackProperties:nil];
}

- (void)trackProperties:(NSDictionary *)properties
{
    [self trackProperties:properties completionHandler:nil];
}

- (void)trackProperties:(NSDictionary *)properties completionHandler:(void (^)())completion
{
    if (self.apiToken.length == 0) {
        if (self.debugMode) {
            LKLogWarning(@"Not tracking, because API Token is empty");
        }
        return;
    }
    if (self.verboseLogging) {
        LKLog(@"Tracking: %@", properties);
    }

    NSMutableDictionary *propertiesToInclude = [NSMutableDictionary dictionaryWithCapacity:3];
    if (properties != nil) {
        [propertiesToInclude addEntriesFromDictionary:properties];
    }
    NSDictionary *trackedAnalytics = [self.analytics commitTrackableProperties];
    [propertiesToInclude addEntriesFromDictionary:trackedAnalytics];

    __weak LaunchKit *_weakSelf = self;

    LKTrackOperation *track = [[LKTrackOperation alloc] initWithAPIClient:self.apiClient propertiesToTrack:propertiesToInclude];

    __weak LKTrackOperation *_weakTrack = track;
    track.completionBlock = ^{
        if (_weakTrack.error) {
            LKLog(@"Error tracking properties: %@", _weakTrack.error);
            // "Update" our config with a nil, which will trigger
            // it to fire a refresh handler, if this is the first launch
            [_weakSelf.config updateParameters:nil];
            [_weakSelf updateServerBundlesUpdatedTimeFromConfig];
        } else {
            NSDictionary *responseDict = _weakTrack.response;
            if (_weakSelf.verboseLogging) {
                LKLog(@"Tracking response: %@", responseDict);
            }
            NSArray *todos = responseDict[@"do"];
            if ([todos isKindOfClass:[NSArray class]]) {
                for (NSDictionary *todo in todos) {
                    if (![todo isKindOfClass:[NSDictionary class]]) {
                        continue;
                    }
                    NSString *command = todo[@"command"];
                    NSDictionary *args = todo[@"args"];
                    [_weakSelf handleCommand:command withArgs:args];
                }
            }
            NSDictionary *config = responseDict[@"config"];
            if ([config isKindOfClass:[NSDictionary class]]) {
                [_weakSelf.config updateParameters:config];
            }
            NSDictionary *user = responseDict[@"user"];
            if ([user isKindOfClass:[NSDictionary class]]) {
                [_weakSelf.analytics updateUserFromDictionary:user reportUpdate:YES];
            }
            [_weakSelf updateServerBundlesUpdatedTimeFromConfig];
            [_weakSelf archiveSession];
        }
        _weakSelf.trackingRequestInProgress = NO;
        _weakSelf.numTrackingRequestsCompleted++;
        [_weakSelf startNextTrackingRequestIfPossible];
        if (completion) {
            completion();
        }
    };
    @synchronized(self.trackingRequests) {
        [self.trackingRequests addObject:track];
    }
    [self startNextTrackingRequestIfPossible];
}

- (void)startNextTrackingRequestIfPossible {
    @synchronized(self.trackingRequests) {
        if (self.trackingRequestInProgress || self.trackingRequests.count == 0) {
            return;
        }

        LKTrackOperation *track = self.trackingRequests.firstObject;
        [[NSOperationQueue mainQueue] addOperation:track];
        [self.trackingRequests removeObjectAtIndex:0];
        self.trackingRequestInProgress = YES;
    }

    if (self.trackingTimer.isValid) {
        if (self.intervalTrackingEnabled) {
            // We have an existing tracking timer, but since we just tracked, restart it
            // NOTE: Even if we don't restart the tracking timer here, it would still
            // fire at the previous interval, as it is a repeating timer.
            [self restartTrackingFireImmediately:NO];
        } else {
            [self stopTracking];
        }
    }
}

#pragma mark - Handling Commands from LaunchKit server

- (void)handleCommand:(NSString *)command withArgs:(NSDictionary *)args
{
    if ([command isEqualToString:@"set-session"]) {
        NSString *key = args[@"name"];
        id value = args[@"value"];
        if ([key isEqualToString:@"report_screens"]) {
            [self.analytics updateReportingScreens:[value boolValue]];
        } else if ([key isEqualToString:@"report_taps"]) {
            [self.analytics updateReportingTaps:[value boolValue]];
        } else if ([key isEqual:@"track_interval"]) {
            // Clamp the value we're saving to reflect what will actually be
            // set in our client
            value = @(MAX([value doubleValue], MIN_TRACKING_INTERVAL));
            [self updateTrackingInterval:[value doubleValue]];
        }

        NSMutableDictionary *updatedSessionParams = [self.sessionParameters mutableCopy];
        if ([value isKindOfClass:[NSNull class]]) {
            [updatedSessionParams removeObjectForKey:key];
        } else {
            updatedSessionParams[key] = value;
        }
        // Triggers an update
        self.sessionParameters = updatedSessionParams;
    } else if ([command isEqualToString:@"log"]) {
        // Log sent from remote server.
        NSLog(@"[LaunchKit] %@ - %@", [args[@"level"] uppercaseString], args[@"message"]);
    }
}

- (void) updateTrackingInterval:(NSTimeInterval)newInterval
{
    newInterval = MAX(newInterval, MIN_TRACKING_INTERVAL);
    if (self.trackingInterval == newInterval) {
        return;
    }
    self.trackingInterval = newInterval;

    if (self.intervalTrackingEnabled) {
        UIApplicationState state = [UIApplication sharedApplication].applicationState;
        if (state == UIApplicationStateActive) {
            [self restartTrackingFireImmediately:YES];
        }
    } else {
        if (self.verboseLogging) {
            LKLog(@"Not restarting tracking timer, because self.intervalTrackingEnabled is NO.");
        }
    }

    if (self.verboseLogging) {
        LKLog(@"Tracking timer interval changed to %.1f via remote command", self.trackingInterval);
    }
}

- (void) updateServerBundlesUpdatedTimeFromConfig
{
    NSTimeInterval interval = [self.config doubleForKey:@"io.launchkit.bundlesUpdatedTime" defaultValue:0.0];
    if (interval > 0.0) {
        // Interval would be 0.0 if timeString was nil, or timeString was not a valid double
        NSDate *timestamp = [NSDate dateWithTimeIntervalSince1970:interval];
        [self.bundlesManager updateServerBundlesUpdatedTimeWithTime:timestamp];
    } else {
        // Pass in nil, to indicate an error
        [self.bundlesManager updateServerBundlesUpdatedTimeWithTime:nil];
    }
}

#pragma mark - Application Lifecycle Events

- (void)applicationWillTerminate:(NSNotification *)notification
{
    [self archiveSession];
}

- (void)applicationWillResignActive:(NSNotification *)notification
{
    // Flush any tracked data
    if (self.intervalTrackingEnabled) {
        [self trackProperties:nil];
    }

    [self stopTracking];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    // Only restart interval tracking if intervalTrackingEnabled is YES, and
    // always let it through if it's the very first tracking request
    if (self.numTrackingRequestsCompleted > 0 && !self.intervalTrackingEnabled) {
        if (self.verboseLogging) {
            LKLog(@"Not restarting track, because `intervalTrackingEnabled` is NO.");
        }
        return;
    }
    // Sometimes (especially on app startup), we might already have
    // manually requested a track call (i.e. for -setUserIdentifier:email:name)
    // So if we're already tracking something then, don't need to fire immediately
    BOOL shouldTrackImmediately = !self.trackingRequestInProgress;
    [self restartTrackingFireImmediately:shouldTrackImmediately];
}

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
    [self archiveSession];
}

- (void)applicationDidReceiveMemoryWarning:(NSNotification *)notification
{
    [self trackProperties:nil];
}

#pragma mark - User Info

- (void) setUserIdentifier:(nullable NSString *)userIdentifier email:(nullable NSString *)userEmail name:(nullable NSString *)userName
{
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[@"command"] = @"set-user";
    // Setting these values to empty string essentially is removing them, as far as API is concerned.
    params[@"unique_id"] = (userIdentifier) ? userIdentifier : @"";
    params[@"email"] = (userEmail) ? userEmail : @"";
    params[@"name"] = (userName) ? userName : @"";
    [self trackProperties:params];
}

- (LKAppUser *) currentUser
{
    return self.analytics.user;
}

- (void)setDebugAppUserIsAlwaysSuper:(BOOL)debugAppUserIsAlwaysSuper
{
    [LKAppUser setDebugUserIsAlwaysSuper:debugAppUserIsAlwaysSuper];
}

- (BOOL)debugAppUserIsAlwaysSuper
{
    return [LKAppUser debugUserIsAlwaysSuper];
}

#pragma mark - What's New

- (BOOL) appReleaseNotesAvailable
{
    // WhatsNew feature is enabled on LaunchKit
    BOOL whatsNewEnabled = LKConfigBool(@"io.launchkit.whatsNewEnabled", YES);
    // Check against our remote bundles manifest if this app version *should* have
    // has WhatsNew bundle.
    BOOL manifestAvailable = self.bundlesManager.latestRemoteBundlesManifestRetrieved;
    if (!manifestAvailable) {
        LKLogWarning(@"Calling %s before LaunchKit is ready", __PRETTY_FUNCTION__);
    }
    LKBundleInfo *info = [self.bundlesManager remoteBundleInfoWithName:@"WhatsNew"];
    return whatsNewEnabled && manifestAvailable && (info != nil);
}

- (void) presentAppReleaseNotesIfNeededFromViewController:(nonnull UIViewController *)viewController
                                               completion:(nullable LKReleaseNotesCompletionHandler)completion
{
    [self presentAppReleaseNotesFromViewController:viewController
                               onDirectUserRequest:NO
                                        completion:completion];
}

- (void) forcePresentationOfAppReleaseNotesFromViewController:(nonnull UIViewController *)viewController
                                                   completion:(nullable LKReleaseNotesCompletionHandler)completion
{
    [self presentAppReleaseNotesFromViewController:viewController
                               onDirectUserRequest:YES
                                        completion:completion];
}

- (void) presentAppReleaseNotesFromViewController:(nonnull UIViewController *)viewController
                              onDirectUserRequest:(BOOL)isDirectUserRequest
                                       completion:(nullable LKReleaseNotesCompletionHandler)completion
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LKLogWarning(@"Attempted to show release notes on a background thread. Adjust your code to call this on the main thread.");
            [self presentAppReleaseNotesFromViewController:viewController
                                       onDirectUserRequest:isDirectUserRequest
                                                completion:completion];
        });
        return;
    }
    // Make a closure here, in case we need to wait for config to be ready
    __weak LaunchKit *_weakSelf = self;
    void (^presentReleaseNotesIfPossible)() = ^ {
        BOOL shouldShowReleaseNotes = [self possibleToPresentAppReleaseNotesIgnoringUserHistory:isDirectUserRequest];
        BOOL debugAlwaysAttemptDisplay = NO;
#if DEBUG
        debugAlwaysAttemptDisplay = self.debugAlwaysPresentAppReleaseNotes;
#endif
        if (shouldShowReleaseNotes || debugAlwaysAttemptDisplay) {
            [_weakSelf.uiManager presentAppReleaseNotesFromViewController:viewController completion:completion];
        } else {
            if (completion) {
                completion(NO);
            }
        }
    };

    if (self.config.isReady) {
        presentReleaseNotesIfPossible();
    } else {
        [self.configReadyBlocks addObject:presentReleaseNotesIfPossible];
    }
}

- (BOOL) possibleToPresentAppReleaseNotesIgnoringUserHistory:(BOOL)ignoreUserHistory
{
    // WhatsNew feature is enabled on LaunchKit
    BOOL whatsNewEnabled = LKConfigBool(@"io.launchkit.whatsNewEnabled", YES);
    if (ignoreUserHistory) {
        return whatsNewEnabled;
    }
    // We have shown this UI before (for this app version)
    BOOL alreadyPresentedForThisAppVersion = [self.uiManager remoteUIPresentedForThisAppVersion:@"WhatsNew"];
    BOOL showToNewUsers = LKConfigBool(@"io.launchkit.whatsNewShowToNewUsers", NO);
    // This session has upgraded app versions at least once
    NSTimeInterval currentVersionDuration = [self.config doubleForKey:@"io.launchkit.currentVersionDuration"
                                                         defaultValue:0.0];
    NSTimeInterval installDurationSinceLK = [self.config doubleForKey:@"io.launchkit.installDuration"
                                                         defaultValue:0.0];
    // Easy case: Since LK was installed, there has been a version update, indicating
    // that currentVersionDuration is less than the total installDuration (since LK was
    // set up on this app).
    // This means that the user is NOT new (to us)
    // (The actual install vs current time can be *slightly* off, so
    // check against a (small) range
    BOOL userHasUsedPreviousVersionOfApp = (fabs(installDurationSinceLK - currentVersionDuration) > 10.0);

    if (!userHasUsedPreviousVersionOfApp) {
        // The user is new (to us). However, the user could actually be
        // NOT new (to the app). We can make a reasonable guess by checking
        // the creation date of the app Documents/ folder
        NSDate *localInstallDate = [self dateDocumentsFolderWasCreated];
        NSDate *lkSessionStartDate = [[NSDate date] dateByAddingTimeInterval:-installDurationSinceLK];
        // (Assumption) localInstallDate should always be <= lkSessionStartdate
        NSTimeInterval timeBetweenInstallAndLKSession = [lkSessionStartDate timeIntervalSinceDate:localInstallDate];
        // If the user is *roughly* more than a day old,
        // consider them an existing user (who has updated)
        userHasUsedPreviousVersionOfApp = (timeBetweenInstallAndLKSession > 86400);
    }

    return (whatsNewEnabled && !alreadyPresentedForThisAppVersion && (userHasUsedPreviousVersionOfApp || showToNewUsers));
}

- (NSDate *)dateDocumentsFolderWasCreated
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *documentsFolderUrl = [fileManager URLsForDirectory:NSDocumentDirectory
                                                    inDomains:NSUserDomainMask].lastObject;
    NSError *error = nil;
    NSDictionary<NSString *,id> *attributes = [fileManager attributesOfItemAtPath:documentsFolderUrl.path
                                                                            error:&error];
    NSDate *documentsFolderCreationDate = attributes[NSFileCreationDate];
    return documentsFolderCreationDate;
}


#pragma mark - Onboarding UI

- (void)presentOnboardingUIOnWindow:(UIWindow *)window
                  completionHandler:(LKOnboardingUICompletionHandler)completionHandler;
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LKLogWarning(@"Attempted to show onboarding UI on a background thread. Adjust your code to call this on the main thread.");
            [self presentOnboardingUIOnWindow:window completionHandler:completionHandler];
        });
        return;
    }
    [self.uiManager presentOnboardingUIOnWindow:window
                            maxWaitTimeInterval:self.maxOnboardingWaitTimeInterval
                              completionHandler:completionHandler];
}

#pragma mark - App Review Card
- (void) presentAppReviewCardIfNeededFromViewController:(nonnull UIViewController *)viewController
                                             completion:(nullable LKAppReviewCardCompletionHandler)completion
{
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LKLogWarning(@"Attempted to show review card on a background thread. Adjust your code to call this on the main thread.");
            [self presentAppReviewCardIfNeededFromViewController:viewController completion:completion];
        });
        return;
    }
    [self.uiManager presentAppReviewCardIfNeededFromViewController:viewController completion:^(LKViewControllerFlowResult flowResult) {

        BOOL agreedToReview = (flowResult == LKViewControllerFlowResultCompleted);
        if (agreedToReview) {
            // Sure!
            //NSString *appStoreUrlString = LKConfigString(@"appStoreUrl", @"itms-apps://itunes.apple.com/app/id596595032");
            //[[UIApplication sharedApplication] openURL:[NSURL URLWithString:appStoreUrlString]];
        } else {
            // No Thanks, or Cancel, or failed
        }

        if (completion) {
            completion(flowResult);
        }
    }];
}

#pragma mark - LKBundlesManagerDelegate

- (void) bundlesManagerRemoteManifestWasRefreshed:(LKBundlesManager *)manager
{
    // Internally, bundles manifest and ui manifest are the same (bundles is the superset
    // of ui), so report ui manifest changes
    if (self.uiManifestRefreshHandler) {
        self.uiManifestRefreshHandler();
    }
}

#pragma mark - LKConfigDelegate

- (void) configIsReady:(nonnull LKConfig *)config
{
    NSMutableArray <void (^)()>*readyBlocks = [self.configReadyBlocks copy];
    dispatch_async(dispatch_get_main_queue(), ^{
        // Load any pending operations when config is ready
        for (void (^readyBlock)() in readyBlocks) {
            readyBlock();
        }
    });
    [self.configReadyBlocks removeAllObjects];
}

#pragma mark - LKUIManagerDelegate

- (void)uiManagerRequestedToReportUIEvent:(nonnull NSString *)eventName
                             uiBundleInfo:(nullable LKBundleInfo *)uiBundleInfo
                     additionalParameters:(nullable NSDictionary *)additionalParameters
{
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    // Add additionalParameters first, so we can overwrite with the 'command' and ui bundle keys, if needed
    if (additionalParameters.count) {
        [params addEntriesFromDictionary:additionalParameters];
    }
    params[@"command"] = eventName;
    if (uiBundleInfo != nil) {
        params[@"ui_name"] = uiBundleInfo.name;
        params[@"ui_version"] = uiBundleInfo.version;
    }
    [self trackProperties:params];
}

#pragma mark - Saving/Persisting our Session

- (void)archiveSession
{
    NSString *filePath = [self sessionArchiveFilePath];
    NSString *directoryPath = [filePath stringByDeletingLastPathComponent];
    NSError *directoryCreateError = nil;
    if (![[NSFileManager defaultManager] createDirectoryAtPath:directoryPath withIntermediateDirectories:YES attributes:nil error:&directoryCreateError]) {
        LKLogError(@"Could not create directory for session archive file: %@", directoryCreateError);
    }
    NSMutableDictionary *session = [NSMutableDictionary dictionaryWithCapacity:3];
    session[@"sessionParameters"] = self.sessionParameters;
    session[@"configurationParameters"] = self.config.parameters;
    if (self.analytics.lastUserDictionary) {
        session[@"analyticsUserDictionary"] = self.analytics.lastUserDictionary;
    }
    if (self.bundlesManager) {
        session[@"bundlesManagerState"] = self.bundlesManager.stateDictionary;
    }
    BOOL success = [NSKeyedArchiver archiveRootObject:session toFile:filePath];
    if (!success) {
        LKLogError(@"Could not archive session parameters");
    }
}

- (void)retrieveSessionFromArchiveIfAvailable
{
    NSString *oldFilePath = [self oldSessionArchiveFilePath];
    NSString *filePath = [self sessionArchiveFilePath];

    // Migration: Move it from (app/Library/) to (app/Library/Application Support/launchkit/)
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:oldFilePath]) {
        NSString *filePathParent = [filePath stringByDeletingLastPathComponent];
        NSError *createFolderError = nil;
        [fileManager createDirectoryAtPath:filePathParent
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:&createFolderError];
        if (createFolderError != nil) {
            LKLogWarning(@"Couldn't create folder at: %@", filePathParent);
        }
        // Move it to the new location
        NSError *moveSessionFileError = nil;
        [fileManager moveItemAtPath:oldFilePath
                             toPath:filePath
                              error:&moveSessionFileError];
        if (moveSessionFileError != nil) {
            if ([moveSessionFileError.domain isEqualToString:@"NSCocoaErrorDomain"] &&
                moveSessionFileError.code == 516) {
                // The file already exists, so we should already be using that file. Just delete this one.
                NSError *deleteOldSessionFileError = nil;
                [fileManager removeItemAtPath:oldFilePath error:&deleteOldSessionFileError];
            } else {
                LKLogWarning(@"Unable to move launchkit session file to new location: %@", moveSessionFileError);
            }
        }
    }

    // Load session from 'filePath'
    id unarchivedObject = nil;
    if (filePath) {
        unarchivedObject = [NSKeyedUnarchiver unarchiveObjectWithFile:filePath];
    }

    if ([unarchivedObject isKindOfClass:[NSDictionary class]]) {
        NSDictionary *unarchivedDict = (NSDictionary *)unarchivedObject;
        // Check to see if our data structure uses any of the older format
        // TODO(Riz): This can probably be removed at this point
        if ([[unarchivedDict allKeys] containsObject:@"configurationParameters"]) {
            // Dict contains both session and configuration parameters
            self.sessionParameters = unarchivedDict[@"sessionParameters"];
            self.config.parameters = unarchivedDict[@"configurationParameters"];
            if ([unarchivedDict[@"analyticsUserDictionary"] isKindOfClass:[NSDictionary class]]) {
                NSDictionary *lastUserDictionary = unarchivedDict[@"analyticsUserDictionary"];
                if ([lastUserDictionary isKindOfClass:[NSDictionary class]]) {
                    [self.analytics updateUserFromDictionary:lastUserDictionary reportUpdate:NO];
                }
            }
            NSDictionary *bundlesManagerState = unarchivedDict[@"bundlesManagerState"];
            if ([bundlesManagerState isKindOfClass:[NSDictionary class]]) {
                [self.bundlesManager updateFromPreviousState:bundlesManagerState];
            }
        } else {
            // Old way, which stored only the session parameters directly
            self.sessionParameters = unarchivedDict;
            self.config.parameters = @{};
        }

        // Update some local settings from known session_parameter variables
        BOOL shouldReportScreens = YES;
        BOOL shouldReportTaps = YES;
        id rawReportScreens = self.sessionParameters[@"report_screens"];
        if ([rawReportScreens isKindOfClass:[NSNumber class]]) {
            shouldReportScreens = [rawReportScreens boolValue];
        }
        id rawReportTaps = self.sessionParameters[@"report_taps"];
        if ([rawReportTaps isKindOfClass:[NSNumber class]]) {
            shouldReportTaps = [rawReportTaps boolValue];
        }
        [self.analytics updateReportingScreens:shouldReportScreens];
        [self.analytics updateReportingTaps:shouldReportTaps];

    } else {
        self.sessionParameters = @{};
        self.config.parameters = @{};
    }
}

- (NSString *)oldSessionArchiveFilePath
{
    if (!self.apiToken) {
        return nil;
    }
    // Separate by apiToken
    NSString *filename = [NSString stringWithFormat:@"launchkit_%@_%@.plist", self.apiToken, @"session"];
    return [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) lastObject]
            stringByAppendingPathComponent:filename];
}


- (NSString *)sessionArchiveFilePath
{
    if (!self.apiToken) {
        return nil;
    }
    // Separate by apiToken
    NSString *filename = [NSString stringWithFormat:@"launchkit_%@_%@.plist", self.apiToken, @"session"];
    NSString *appSupportDir = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).lastObject;
    NSString *launchKitDir = [appSupportDir stringByAppendingPathComponent:@"launchkit"];
    return [launchKitDir stringByAppendingPathComponent:filename];
}


#pragma mark - Debugging (for LaunchKit developers :D)


+ (void)useLocalLaunchKitServer:(BOOL)useLocalLaunchKitServer
{
    NSAssert(_sharedInstance == nil, @"An instance of LaunchKit already has been created. You can only configure whether to use a local server before you have created the shared instance");
    USE_LOCAL_LAUNCHKIT_SERVER = useLocalLaunchKitServer;
}

- (void)printUsageMeasurements
{
    static NSNumberFormatter *numFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        numFormatter = [[NSNumberFormatter alloc] init];
    });
    NSTimeInterval secondsSinceLaunch = -[self.launchTime timeIntervalSinceNow];
    double kBytesReceivedTotal = ((double)self.apiClient.receivedBytes)/1024.0;
    double kBytesSentTotal = ((double)self.apiClient.sentBytes)/1024.0;
    double avgKBytesReceivedPerSecond = kBytesReceivedTotal/secondsSinceLaunch;
    double avgKBytesSentPerSecond = kBytesSentTotal/secondsSinceLaunch;
    LKLog(@"LK Usage: (%.2fKB sent total, %.2fKB rcvd total) over %@ [%.2fKB sent/sec], [%.2fKB rcvd/sec]. %@ API calls",
          kBytesSentTotal,
          kBytesReceivedTotal,
          [self stringFromTimeInterval:secondsSinceLaunch],
          avgKBytesSentPerSecond,
          avgKBytesReceivedPerSecond,
          [numFormatter stringFromNumber:@(self.apiClient.numAPICallsMade)]);
}

// Thanks, http://stackoverflow.com/a/4933139/9849
- (NSString *) stringFromTimeInterval:(NSTimeInterval)interval {
    NSInteger ti = (NSInteger)interval;
    NSInteger seconds = ti % 60;
    NSInteger minutes = (ti / 60) % 60;
    NSInteger hours = (ti / 3600);
    return [NSString stringWithFormat:@"%02ld:%02ld:%02ld", (long)hours, (long)minutes, (long)seconds];
}

@end


#pragma mark - LKConfig Convenience Functions

BOOL LKConfigBool(NSString *__nonnull key, BOOL defaultValue)
{
    return [[LaunchKit sharedInstance].config boolForKey:key defaultValue:defaultValue];
}


NSInteger LKConfigInteger(NSString *__nonnull key, NSInteger defaultValue)
{
    return [[LaunchKit sharedInstance].config integerForKey:key defaultValue:defaultValue];
}

double LKConfigDouble(NSString *__nonnull key, double defaultValue)
{
    return [[LaunchKit sharedInstance].config doubleForKey:key defaultValue:defaultValue];
}

extern NSString * __nullable LKConfigString(NSString *__nonnull key, NSString *__nullable defaultValue)
{
    return [[LaunchKit sharedInstance].config stringForKey:key defaultValue:defaultValue];
}

extern void LKConfigReady(LKConfigReadyHandler _Nullable readyHandler)
{
    [LaunchKit sharedInstance].config.readyHandler = readyHandler;
}

extern void LKConfigRefreshed(LKConfigRefreshHandler _Nullable refreshHandler)
{
    [LaunchKit sharedInstance].config.refreshHandler = refreshHandler;
}


#pragma mark - LKAppUser Convenience Functions

BOOL LKAppUserIsSuper()
{
    return [LaunchKit sharedInstance].currentUser.isSuper;
}


#pragma mark - LaunchKit UI Convenience Functions

extern void LKUIManifestRefreshed(LKUIManifestRefreshHandler _Nullable readyHandler)
{
    [LaunchKit sharedInstance].uiManifestRefreshHandler = readyHandler;
}
