//
//  LKAnalytics.h
//  LaunchKit
//
//  Created by Rizwan Sattar on 8/13/15.
//
//

#import <UIKit/UIKit.h>

#import "LKAPIClient.h"

@interface LKAnalytics : NSObject

@property (assign, nonatomic) BOOL debugMode;
@property (assign, nonatomic) BOOL verboseLogging;

@property (readonly, nonatomic) BOOL shouldReportScreens;
@property (readonly, nonatomic) BOOL shouldReportTaps;

- (instancetype)initWithAPIClient:(LKAPIClient *)apiClient screenReporting:(BOOL)shouldReportScreens tapReportingEnabled:(BOOL)shouldReportTaps;

- (NSDictionary *)trackableProperties;
- (void)clearTrackableProperties;

- (void) updateReportingScreens:(BOOL)shouldReport;
- (void) updateReportingTaps:(BOOL)shouldReport;

- (void) createListeners;
- (void) destroyListeners;

#pragma mark - Convenience Methods

+ (double)angleForInterfaceOrientation:(UIInterfaceOrientation)orientation;

@end
