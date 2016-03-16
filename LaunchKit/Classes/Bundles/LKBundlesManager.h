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

@class LKBundlesManager;
@protocol LKBundlesManagerDelegate <NSObject>

- (void) bundlesManagerRemoteManifestWasRefreshed:(LKBundlesManager *)manager;

@end

@interface LKBundlesManager : NSObject

@property (weak, nonatomic) NSObject <LKBundlesManagerDelegate> *delegate;

@property (assign, nonatomic) BOOL debugMode;
@property (assign, nonatomic) BOOL verboseLogging;

@property (readonly, nonatomic) BOOL hasNewestRemoteBundles;
@property (readonly, nonatomic) BOOL retrievingRemoteBundles;
@property (readonly, nonatomic) BOOL latestRemoteBundlesManifestRetrieved;
@property (readonly, nonatomic) BOOL remoteBundlesDownloaded;

@property (readonly, strong, nonatomic) NSDate *lastManifestRetrievalTime;

- (instancetype) initWithAPIClient:(LKAPIClient *)apiClient;

- (void) rebuildLocalBundlesMap;
- (void) loadBundleWithId:(NSString *)bundleId completion:(LKRemoteBundleLoadHandler)completion;
- (LKBundleInfo *)localBundleInfoWithName:(NSString *)name;
- (LKBundleInfo *)remoteBundleInfoWithName:(NSString *)name;

+ (NSBundle *)cachedBundleFromInfo:(LKBundleInfo *)info;
+ (void)deleteBundlesCacheDirectory;

- (void) updateServerBundlesUpdatedTimeWithTime:(NSDate *)bundlesUpdatedTime;
@end
