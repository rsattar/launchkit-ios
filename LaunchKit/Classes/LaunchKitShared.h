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
#import "LKViewController.h"

#define LAUNCHKIT_VERSION @"2.1.4"

#pragma mark - LKConfig Convenience Functions

extern BOOL LKConfigBool(NSString *__nonnull key, BOOL defaultValue);
extern NSInteger LKConfigInteger(NSString *__nonnull key, NSInteger defaultValue);
extern double LKConfigDouble(NSString *__nonnull key, double defaultValue);
extern NSString * __nullable LKConfigString(NSString *__nonnull key, NSString *__nullable defaultValue);
/**
 * A block to LKConfigReady will get called on the very first
 * update to the configuration (whether or not the configuration is different
 * from the previous configuration). This is an easy place to do some "set once"
 * tasks for your app.
 */
extern void LKConfigReady(LKConfigReadyHandler _Nullable readyHandler);
/**
 * A block to LKConfigRefreshed will get called on the very first
 * network retrieval of the configuration (whether or not the configuration is different
 * from the previous configuration), and all subsequent changes. This is an easy place
 * to do some global property setting for your app.
 */
extern void LKConfigRefreshed(LKConfigRefreshHandler _Nullable refreshHandler);

#pragma mark - LKAppUser Convenience Functions
extern BOOL LKAppUserIsSuper();

#pragma mark - Remote UI

#endif
