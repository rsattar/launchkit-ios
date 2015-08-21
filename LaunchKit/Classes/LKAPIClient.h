//
//  LKAPIClient.h
//  Pods
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

#pragma mark - Tracking Calls
- (void) trackProperties:(NSDictionary *)properties
        withSuccessBlock:(void (^)(NSDictionary *responseDict))successBlock
              errorBlock:(void(^)(NSError *error))errorBlock;

#pragma mark - Remote UI Loading
- (void) retrieveAvailableRemoteUIInfoWithSuccessBlock:(void (^)(NSArray *bundleInfos))successBlock
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

@end
