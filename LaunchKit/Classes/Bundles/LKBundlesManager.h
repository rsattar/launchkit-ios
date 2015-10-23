//
//  LKBundlesManager.h
//  LaunchKit
//
//  Created by Rizwan Sattar on 7/27/15.
//
//

#import <Foundation/Foundation.h>

#import "LKAPIClient.h"
#import "LKBundleInfo.h"

extern NSString *const LKBundlesManagerDidFinishRetrievingBundlesManifest;
extern NSString *const LKBundlesManagerDidFinishDownloadingRemoteBundles;

typedef void (^LKRemoteBundleLoadHandler)(NSBundle * bundle, NSError * error);

@interface LKBundlesManager : NSObject

@property (assign, nonatomic) BOOL debugMode;
@property (assign, nonatomic) BOOL verboseLogging;

@property (readonly, nonatomic) BOOL retrievingRemoteBundles;
@property (readonly, nonatomic) BOOL remoteBundlesManifestRetrieved;
@property (readonly, nonatomic) BOOL remoteBundlesDownloaded;

//+ (instancetype) defaultManager;
- (instancetype) initWithAPIClient:(LKAPIClient *)apiClient;

- (void) rebuildLocalBundlesMap;
- (void) retrieveAndCacheAvailableRemoteBundlesWithCompletion:(void (^)(NSError *error))completion;
- (void) loadBundleWithId:(NSString *)bundleId completion:(LKRemoteBundleLoadHandler)completion;
- (LKBundleInfo *)localBundleInfoWithName:(NSString *)name;
- (LKBundleInfo *)remoteBundleInfoWithName:(NSString *)name;

+ (NSBundle *)cachedBundleFromInfo:(LKBundleInfo *)info;
+ (void)deleteBundlesCacheDirectory;
@end
