//
//  LaunchKitShared.h
//  LaunchKit
//
//  Created by Rizwan Sattar on 6/19/15.
//
//

#ifndef LaunchKitShared_h
#define LaunchKitShared_h

#import <UIKit/UIKit.h>
#import "LKConfig.h"

#define LAUNCHKIT_VERSION @"1.0.3"

#pragma mark - LKConfig Convenience Functions

extern BOOL LKConfigBool(NSString *__nonnull key, BOOL defaultValue);
extern NSInteger LKConfigInteger(NSString *__nonnull key, NSInteger defaultValue);
extern double LKConfigDouble(NSString *__nonnull key, double defaultValue);
extern NSString * __nullable LKConfigString(NSString *__nonnull key, NSString *__nullable defaultValue);
extern void LKConfigReady(LKConfigReadyHandler _Nullable readyHandler);
extern void LKConfigRefreshed(LKConfigRefreshHandler _Nullable refreshHandler);

#pragma mark - LKAppUser Convenience Functions

extern BOOL LKAppUserIsSuper();

#endif
