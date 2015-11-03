//
//  LaunchKit.m
//  Pods
//
//  Created by Cluster Labs, Inc. on 1/13/15.
//
//

#import "LaunchKit.h"

#import "LKAnalytics.h"
#import "LKAPIClient.h"
#import "LKLog.h"

#define DEBUG_MEASURE_USAGE 0

static NSTimeInterval const DEFAULT_TRACKING_INTERVAL = 30.0;
static NSTimeInterval const MIN_TRACKING_INTERVAL = 5.0;

static BOOL USE_LOCAL_LAUNCHKIT_SERVER = NO;
static NSString* const BASE_API_URL_REMOTE = @"https://api.launchkit.io/";
static NSString* const BASE_API_URL_LOCAL = @"http://localhost:9101/";


#pragma mark - Extending LKConfig to allow LaunchKit to modify parameters

@interface LKConfig (Private)

@property (readwrite, strong, nonatomic, nonnull) NSDictionary *parameters;
- (void) updateParameters:(NSDictionary * __nonnull)parameters;

@end

@interface LaunchKit ()

@property (copy, nonatomic) NSString *apiToken;

/** Long-lived, persistent dictionary that is sent up with API requests. */
@property (copy, nonatomic) NSDictionary *sessionParameters;

@property (strong, nonatomic) LKAPIClient *apiClient;
@property (strong, nonatomic) NSTimer *trackingTimer;
@property (assign, nonatomic) NSTimeInterval trackingInterval;

@property (strong, nonatomic) NSDate *launchTime;

// Usage measurement
@property (assign, nonatomic) BOOL debugMeasureUsage;

// Analytics
@property (strong, nonatomic) LKAnalytics *analytics;

// Config
@property (readwrite, strong, nonatomic, nonnull) LKConfig *config;

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

        self.trackingInterval = DEFAULT_TRACKING_INTERVAL;

        self.sessionParameters = @{};
        self.config = [[LKConfig alloc] initWithParameters:nil];
        [self retrieveSessionFromArchiveIfAvailable];

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

        self.analytics = [[LKAnalytics alloc] initWithAPIClient:self.apiClient
                                                screenReporting:shouldReportScreens
                                            tapReportingEnabled:shouldReportTaps];

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
    LKLOG_ENABLED = _debugMode;
}

- (void)setVerboseLogging:(BOOL)verboseLogging
{
    _verboseLogging = verboseLogging;
    self.apiClient.verboseLogging = verboseLogging;
    self.analytics.verboseLogging = verboseLogging;
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
        LKLog(@"Starting Tracking");
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
        LKLog(@"Stopping Tracking");
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
    [self.apiClient trackProperties:propertiesToInclude withSuccessBlock:^(NSDictionary *responseDict) {
        if (_weakSelf.verboseLogging) {
            LKLog(@"Tracking response: %@", responseDict);
        }
        NSArray *todos = responseDict[@"do"];
        for (NSDictionary *todo in todos) {
            NSString *command = todo[@"command"];
            NSDictionary *args = todo[@"args"];
            [_weakSelf handleCommand:command withArgs:args];
        }
        NSDictionary *config = responseDict[@"config"];
        if (config != nil) {
            [_weakSelf.config updateParameters:config];
        }
        NSDictionary *user = responseDict[@"user"];
        if (user != nil) {
            [_weakSelf.analytics updateUserFromDictionary:user];
        }
    } errorBlock:^(NSError *error) {
        LKLog(@"Error tracking properties: %@", error);
    }];
    if (self.trackingTimer.isValid) {
        // We have an existing tracking timer, but since we just tracked, restart it
        // NOTE: Even if we don't restart the tracking timer here, it would still
        // fire at the previous interval, as it is a repeating timer.
        [self restartTrackingFireImmediately:NO];
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
        [self archiveSession];
    } else if ([command isEqualToString:@"log"]) {
        // Log sent from remote server.
        LKLog(@"%@ - %@", [args[@"level"] uppercaseString], args[@"message"]);
    }
}

- (void) updateTrackingInterval:(NSTimeInterval)newInterval
{
    newInterval = MAX(newInterval, MIN_TRACKING_INTERVAL);
    if (self.trackingInterval == newInterval) {
        return;
    }
    self.trackingInterval = newInterval;

    UIApplicationState state = [UIApplication sharedApplication].applicationState;
    if (state == UIApplicationStateActive) {
        [self restartTrackingFireImmediately:YES];
    }

    if (self.verboseLogging) {
        LKLog(@"Tracking timer interval changed to %.1f via remote command", self.trackingInterval);
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
    [self trackProperties:nil];

    [self stopTracking];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    [self restartTrackingFireImmediately:YES];
}

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
    [self archiveSession];
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

#pragma mark - Saving/Persisting our Session

- (void)archiveSession
{
    NSString *filePath = [self sessionArchiveFilePath];
    NSString *directoryPath = [filePath stringByDeletingLastPathComponent];
    NSError *directoryCreateError = nil;
    if (![[NSFileManager defaultManager] createDirectoryAtPath:directoryPath withIntermediateDirectories:YES attributes:nil error:&directoryCreateError]) {
        LKLogError(@"Could not create directory for session archive file: %@", directoryCreateError);
    }
    NSDictionary *session = @{@"sessionParameters": self.sessionParameters,
                              @"configurationParameters": self.config.parameters};
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
        if ([[unarchivedDict allKeys] containsObject:@"configurationParameters"]) {
            // Dict contains both session and configuration parameters
            self.sessionParameters = unarchivedDict[@"sessionParameters"];
            self.config.parameters = unarchivedDict[@"configurationParameters"];
        } else {
            // Old way, which stored only the session parameters directly
            self.sessionParameters = unarchivedDict;
            self.config.parameters = @{};
        }
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


#pragma mark - LKAppUser Convenience Functions

BOOL LKAppUserIsSuper()
{
    return [LaunchKit sharedInstance].currentUser.isSuper;
}
