//
//  LKAPIClient.h
//  LaunchKit
//
//  Created by Cluster Labs, Inc. on 1/16/15.
//
//

#import <Foundation/Foundation.h>

#import "LKBundleInfo.h"

extern NSString* const LKAPIFailedAuthenticationChallenge;

@interface LKAPIClient : NSObject

@property (copy, nonatomic) NSString *apiToken;
@property (copy, nonatomic) NSString *serverURL;
@property (copy, nonatomic) NSDictionary *sessionParameters;
@property (readonly, nonatomic) NSTimeInterval serverTimeOffset;
@property (assign, nonatomic) BOOL verboseLogging;

@property (assign, nonatomic) BOOL measureUsage;
@property (readonly, nonatomic) int64_t receivedBytes;
@property (readonly, nonatomic) int64_t sentBytes;
@property (readonly, nonatomic) int64_t numAPICallsMade;


#pragma mark - Tracking Calls
- (void) trackProperties:(NSDictionary *)properties
        withSuccessBlock:(void (^)(NSDictionary *responseDict))successBlock
              errorBlock:(void(^)(NSError *error))errorBlock;

#pragma mark - Remote UI Loading
- (void) retrieveBundlesManifestWithSuccessBlock:(void (^)(NSArray *bundleInfos))successBlock
                                             errorBlock:(void(^)(NSError *error))errorBlock;

#pragma mark - Sending requests
- (void) objectFromPath:(NSString*)path
                 method:(NSString*)method
                 params:(NSDictionary*)params
           successBlock:(void(^)(NSDictionary *))successBlock
           failureBlock:(void(^)(NSError *))failureBlock;

- (void) objectFromPath:(NSString*)path
                 method:(NSString*)method
                 params:(NSDictionary*)params
             JSONparams:(BOOL)JSONparams
           successBlock:(void(^)(NSDictionary *))successBlock
           failureBlock:(void(^)(NSError *))failureBlock;

#pragma mark - Measuring Usage
- (void) resetUsageMeasurements;

#pragma mark - System Information getters
+ (NSString *)appBundleIdentifier;
+ (NSString *)appBundleVersion;
+ (NSString *)appBuildNumber;

@end
