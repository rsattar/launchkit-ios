//
//  LKAPIClient.m
//  Pods
//
//  Created by Cluster Labs, Inc. on 1/16/15.
//
//

#import "LKAPIClient.h"

#import "LaunchKitShared.h"
#import "LKLog.h"
#import "LKUtils.h"
#import "NSDictionary+LKFormEncoded.h"
#import <sys/utsname.h>

NSString* const LKAPIFailedAuthenticationChallenge = @"LKAPIFailedAuthenticationChallenge";

static NSString* const API_ERROR_DOMAIN = @"LaunchKitAPI";

#define LK_DEBUG_LOG_REQUESTS 0

static NSCalendar *_globalGregorianCalendar;

@interface LKAPIClient ()

@property (strong, nonatomic) NSURLSessionConfiguration *urlSessionConfiguration;
@property (strong, nonatomic) NSURLSession *urlSession;

@property (assign, nonatomic) NSTimeInterval serverTimeOffset;

@property (strong, nonatomic) NSString *oauthAccessToken;
@property (strong, nonatomic) NSString *oauthTokenType;

@property (strong, nonatomic) NSString *cachedBundleIdentifier; // E.g.: com.yourcompany.appname
@property (strong, nonatomic) NSString *cachedBundleVersion;    // E.g.: 1.2
@property (strong, nonatomic) NSString *cachedBuildNumber;      // E.g.: 14
@property (strong, nonatomic) NSString *cachedOSVersion;        // E.g.: iOS 8.1.3
@property (strong, nonatomic) NSString *cachedHardwareModel;    // E.g.: iPhone 7,1

// Measuring usage
@property (assign, nonatomic) int64_t receivedBytes;
@property (assign, nonatomic) int64_t sentBytes;
@property (assign, nonatomic) int64_t numAPICallsMade;

@end

@implementation LKAPIClient


- (instancetype) init
{
    self = [super init];
    if (self) {
        _cachedBundleIdentifier = [LKAPIClient bundleIdentifier];
        _cachedBundleVersion = [LKAPIClient bundleVersion];;
        _cachedBuildNumber = [LKAPIClient buildNumber];
        _cachedOSVersion = [NSString stringWithFormat:@"iOS %@", [LKAPIClient softwareVersion]];
        _cachedHardwareModel = [LKAPIClient hardwareModel];

        _urlSessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
        _urlSessionConfiguration.networkServiceType = NSURLNetworkServiceTypeBackground;
        _urlSessionConfiguration.timeoutIntervalForRequest = 20.0; // 20 second timeout (default is 60 seconds)
        _urlSessionConfiguration.HTTPAdditionalHeaders = @{@"User-Agent" : [LKAPIClient userAgentString]};
        _urlSession = [NSURLSession sessionWithConfiguration:_urlSessionConfiguration
                                                    delegate:nil
                                               delegateQueue:[NSOperationQueue mainQueue]];
        _urlSession.sessionDescription = @"LaunchKit SDK URL Session";
    }
    return self;
}


#pragma mark - Tracking Calls


- (void) trackProperties:(NSDictionary *)properties
        withSuccessBlock:(void (^)(NSDictionary *responseDict))successBlock
              errorBlock:(void(^)(NSError *error))errorBlock
{
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[@"token"] = self.apiToken;
    params[@"bundle"] = self.cachedBundleIdentifier;
    params[@"version"] = self.cachedBundleVersion;
    params[@"build"] = self.cachedBuildNumber;
    params[@"os_version"] = self.cachedOSVersion;
    params[@"hardware"] = self.cachedHardwareModel;
    params[@"screen"] = [LKAPIClient currentWindowInfo];
#if DEBUG
    // Notify LK servers when the app is running in debug mode
    params[@"debug_build"] = @(YES);
#else
    params[@"debug_build"] = @(NO);
#endif
    if (self.sessionParameters.count > 0) {
        params[@"session"] = self.sessionParameters;
    }
    if (properties.count > 0) {
        [params addEntriesFromDictionary:properties];
    }

    [self objectFromPath:@"v1/track" method:@"POST" params:params successBlock:^(NSDictionary *responseDict) {
        if (successBlock) {
            successBlock(responseDict);
        }
    } failureBlock:errorBlock];
}


#pragma mark - Sending requests



- (void) objectFromPath:(NSString*)path
                 method:(NSString*)method
                 params:(NSDictionary*)params
           successBlock:(void(^)(NSDictionary *))successBlock
           failureBlock:(void(^)(NSError *))failureBlock
{
    [self objectFromPath:path
                  method:method
                  params:params
              JSONparams:YES
            successBlock:successBlock
            failureBlock:failureBlock];
}


- (void) objectFromPath:(NSString*)path
                 method:(NSString*)method
                 params:(NSDictionary*)params
             JSONparams:(BOOL)JSONparams
           successBlock:(void(^)(NSDictionary *))successBlock
           failureBlock:(void(^)(NSError *))failureBlock
{
    NSMutableString *urlString = [[self.serverURL stringByAppendingString:path] mutableCopy];

    if ([method isEqualToString:@"GET"] && params != nil) {
        NSString *formEncodedParams = [params lk_toFormEncodedString];
        // Adjust our urlString and append our params
        if ([urlString rangeOfString:@"?"].location != NSNotFound) {
            // urlString already has a '?'
            if ([urlString hasSuffix:@"?"]) {
                // '?' is at the end, so params are clean
                [urlString appendString:formEncodedParams];
            } else {
                // urlString already has some params, just append our own
                [urlString appendFormat:@"&%@", formEncodedParams];
            }
        } else {
            // No ? to start parameter string. Clean path so far.
            [urlString appendFormat:@"?%@", formEncodedParams];
        }
    }

#if LK_DEBUG_LOG_REQUESTS
    LKLog(@"API request: %@ %@", method, urlString);
#endif

    NSURL *url = [NSURL URLWithString:urlString];

    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];

    [request setHTTPMethod:method];

    if (self.oauthAccessToken != nil && self.oauthTokenType != nil) {
        NSString *authorization = [NSString stringWithFormat:@"%@ %@", self.oauthTokenType, self.oauthAccessToken];
        [request setValue:authorization forHTTPHeaderField:@"Authorization"];
        [request setHTTPShouldHandleCookies:NO];
    } else {
        [request setHTTPShouldHandleCookies:YES];
    }

    if ([method isEqualToString:@"POST"] && params != nil) {
        NSData *body;
        if (!JSONparams) {
            [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
            body = [[params lk_toFormEncodedString] dataUsingEncoding:NSUTF8StringEncoding];
        } else {
            [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
            NSError *serializationError = nil;
            body = [NSJSONSerialization dataWithJSONObject:params options:0 error:&serializationError];
            if (serializationError != nil) {
                if (self.verboseLogging) {
                    LKLogError(@"Could not serialize JSON: %@", serializationError);
                }
            }
        }
#if LK_DEBUG_LOG_REQUESTS
        LKLog(@"  post body: %@", [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding]);
#endif
        [request setHTTPBody:body];
    }

    NSDate *startTime = [NSDate date];

    __block NSURLSessionDataTask *dataTask;

    void (^completionHandler)() = ^(NSData *data, NSURLResponse *response, NSError *error) {
        if (self.measureUsage) {
            self.receivedBytes += dataTask.countOfBytesReceived;
            self.sentBytes += dataTask.countOfBytesSent;
        }
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        NSInteger code = [httpResponse statusCode];

        NSDictionary *headers = [httpResponse allHeaderFields];
        NSString *contentType = headers[@"Content-Type"];
        BOOL isJSON = [contentType rangeOfString:@"json"].location != NSNotFound;

        // Don't trust server time if we're dealing with very long-lived requests.
        if (ABS([startTime timeIntervalSinceNow]) < 30.0) {
            NSTimeInterval serverTimestamp = [headers[@"X-API-Time"] doubleValue];
            if (serverTimestamp > 0) {
                NSDate *serverTime = [NSDate dateWithTimeIntervalSince1970:serverTimestamp];
                // The -1 is necessary to get us to the same format AWS skew value expects.
                self.serverTimeOffset = [serverTime timeIntervalSinceNow] * -1;
            }
        }

        NSDictionary *dict = nil;
        if (error == nil && data != nil && isJSON) {
            NSError *jsonError = nil;
            dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];

            if (jsonError != nil) {
                if (self.verboseLogging) {
                    LKLogError(@"Bad JSON response: %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                }
                if (failureBlock) {
                    failureBlock(jsonError);
                }
                return;
            }
        }

        if (code != 200 || error != nil) {
            if (self.verboseLogging) {
                LKLogError(@"Oh noes, an error for request to %@: %ld; %@; %@", path, (long)code, [error description], [error userInfo]);
                if (dict) {
                    LKLogError(@"Here's the data: %@", dict);
                }
            }

            if (failureBlock) {
                if (error == nil) {
                    // is this weird?
                    error = [NSError errorWithDomain:API_ERROR_DOMAIN code:code userInfo:dict];
                }
                failureBlock(error);
            }

            if ([error.domain isEqualToString:NSURLErrorDomain] &&
                error.code == NSURLErrorUserCancelledAuthentication) { // == -1012
                                                                       // We essentially got a 401 error (whose authentication
                                                                       // challenge is automatically 'cancelled' since we can't
                                                                       // handle it while using the block-based NSURLConnection
                                                                       // sendAsynchronousRequest:queue:completionHandler:
                [[NSNotificationCenter defaultCenter] postNotificationName:LKAPIFailedAuthenticationChallenge
                                                                    object:self userInfo:@{@"path": path,
                                                                                           @"error": error}];

            }
            return;
        }

        if (successBlock) {
            successBlock(dict);
        }
    };

    dataTask = [self.urlSession dataTaskWithRequest:request
                                  completionHandler:completionHandler];
    dataTask.taskDescription = [NSString stringWithFormat:@"LaunchKit: %@ %@", method, path];
    [dataTask resume];
    if (self.measureUsage) {
        self.numAPICallsMade++;
    }
}

// Returns a dictionary (e.g. {'width' : 414, 'height' : 736, 'scale' : 3.0})
+ (NSDictionary *) currentWindowInfo
{
    CGSize windowSize = [LKUtils currentWindowSize];
    CGFloat mainScreenScale = [UIScreen mainScreen].scale;
    return @{@"width" : @(windowSize.width),
             @"height" : @(windowSize.height),
             @"scale" : @(mainScreenScale)};
}


+ (NSString *) userAgentString
{
    NSString *userAgent = [NSString stringWithFormat:@"LaunchKit iOS SDK %@", LAUNCHKIT_VERSION];
    return userAgent;
}


+ (NSDate *) dateFromAPIDateString:(NSString *)string
{
    if (string == nil) {
        return nil;
    }

    if ([string isKindOfClass:[NSNumber class]]) {
        NSNumber *timestamp = (NSNumber*) string;
        return [NSDate dateWithTimeIntervalSince1970:[timestamp doubleValue]];
    }

    NSDateComponents *components = [[NSDateComponents alloc] init];

    NSArray *dateAndTime = [string componentsSeparatedByString:@" "];
    if (dateAndTime.count != 2) {
        return nil;
    }

    NSString *dateString = dateAndTime[0];
    NSArray *dateParts = [dateString componentsSeparatedByString:@"/"];
    if (dateParts.count != 3) {
        return nil;
    }
    [components setMonth:[dateParts[0] integerValue]];
    [components setDay:[dateParts[1] integerValue]];
    [components setYear:[dateParts[2] integerValue]];

    NSString *timeString = dateAndTime[1];
    NSArray *timeParts = [timeString componentsSeparatedByString:@":"];
    if (timeParts.count != 3) {
        return nil;
    }
    [components setHour:[timeParts[0] integerValue]];
    [components setMinute:[timeParts[1] integerValue]];
    [components setSecond:[timeParts[2] integerValue]];

    if (!_globalGregorianCalendar) {
        _globalGregorianCalendar = [[NSCalendar alloc]
                                    initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    }
    _globalGregorianCalendar.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
    NSDate *date = [_globalGregorianCalendar dateFromComponents:components];
    return date;
}


#pragma mark - Measuring Usage


- (void) resetUsageMeasurements
{
    self.receivedBytes = 0;
    self.sentBytes = 0;
    self.numAPICallsMade = 0;
}


#pragma mark - System Information getters


+ (NSString *)bundleIdentifier
{
    NSString *bundle = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString*)kCFBundleIdentifierKey];
    return bundle;
}


+ (NSString *)bundleVersion
{
    // Example: 1.5.2
    NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    if (!version) {
        version = @"(unknown)";
    }
    return version;
}


+ (NSString *)buildNumber
{
    // Example: 10
    NSString *build = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    if (!build) {
        build = @"(unknown)";
    }
    return build;
}


+ (NSString *)softwareVersion
{
    return [[UIDevice currentDevice] systemVersion];
}


+ (NSString *)hardwareModel
{
    // See: http://stackoverflow.com/a/8304788/9849
    /*
     @"i386"      on the simulator
     @"iPod1,1"   on iPod Touch
     @"iPod2,1"   on iPod Touch Second Generation
     @"iPod3,1"   on iPod Touch Third Generation
     @"iPod4,1"   on iPod Touch Fourth Generation
     @"iPhone1,1" on iPhone
     @"iPhone1,2" on iPhone 3G
     @"iPhone2,1" on iPhone 3GS
     @"iPad1,1"   on iPad
     @"iPad2,1"   on iPad 2
     @"iPhone3,1" on iPhone 4
     @"iPhone4,1" on iPhone 4S
     */

    static NSString *modelName = nil;

    if (modelName == nil) {
        struct utsname systemInfo;
        
        uname(&systemInfo);
        
        modelName = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    }
    
    return modelName;
}

@end
