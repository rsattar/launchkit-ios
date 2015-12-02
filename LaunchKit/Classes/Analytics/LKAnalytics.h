//
//  LKAnalytics.h
//  LaunchKit
//
//  Created by Rizwan Sattar on 8/13/15.
//
//

#import <UIKit/UIKit.h>

#import "LKAPIClient.h"
#import "LKAppUser.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString *const LKAppUserUpdatedNotificationName;
extern NSString *const LKPreviousAppUserKey;
extern NSString *const LKCurrentAppUserKey;

@interface LKAnalytics : NSObject

@property (assign, nonatomic) BOOL debugMode;
@property (assign, nonatomic) BOOL verboseLogging;

@property (readonly, nonatomic) BOOL shouldReportScreens;
@property (readonly, nonatomic) BOOL shouldReportTaps;

@property (readonly, strong, nonatomic, nullable) LKAppUser *user;

- (instancetype)initWithAPIClient:(LKAPIClient *)apiClient;

- (NSDictionary *)commitTrackableProperties;

- (void) updateReportingScreens:(BOOL)shouldReport;
- (void) updateReportingTaps:(BOOL)shouldReport;

- (void) createListeners;
- (void) destroyListeners;

#pragma mark - Current User Data

- (void) updateUserFromDictionary:(NSDictionary *)dictionary reportUpdate:(BOOL)reportUpdate;

@end

NS_ASSUME_NONNULL_END
