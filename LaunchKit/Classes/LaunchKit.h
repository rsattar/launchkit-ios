//
//  LaunchKit.h
//  Pods
//
//  Created by Cluster Labs, Inc. on 1/13/15.
//
//

#import <Foundation/Foundation.h>

#import "LaunchKitShared.h"
#import "LKAppUser.h"
#import "LKConfig.h"

//! Project version number for LaunchKit.
FOUNDATION_EXPORT double LaunchKitVersionNumber;

//! Project version string for LaunchKit.
FOUNDATION_EXPORT const unsigned char LaunchKitVersionString[];

@interface LaunchKit : NSObject

/*!
 @method

 @abstract
 Initializes a singleton instance of LaunchKit and returns it.

 @discussion
 This is the starting point a LaunchKit session. Supply the apiToken for your
 account.

 @param apiToken        your project token

 */
+ (nonnull instancetype)launchWithToken:(nonnull NSString *)apiToken;


/*!
 @method
 
 @abstract
 Returns the shared singleton instance that was previously set up by 
 `+launchWithToken`.
 
 @discussion
 Calling this before calling `+launchWithToken:` will return nil.
 */
+ (nonnull instancetype)sharedInstance;


/**
 *  Unavailable. Use `+sharedInstance` to retrieve the shared LaunchKit instance.
 */
- (nullable id)init __attribute__((unavailable("Use +launchWithToken: to initialize LaunchKit, and +sharedInstance to retrieve the shared LaunchKit instance.")));

/**
 * User-configurable parameters that you may have set in LaunchKit's Cloud Config tool. See https://launchkit.io/config
 */
@property (readonly, strong, nonatomic, nonnull) LKConfig *config;


/**
 * According to LaunchKit, what information is availabe for the current app user. See https://launchkit.io/users
 */
@property (readonly, nonatomic, nullable) LKAppUser *currentUser;


/** 
 * Useful to see log statements from LaunchKit in your console. Only useful when DEBUG macro = 1
 */
@property (assign, nonatomic) BOOL debugMode;

/**
 * If you want to see verbose log statements. Only useful when DEBUG macro = 1
 */
@property (assign, nonatomic) BOOL verboseLogging;

/**
 * The version of the LaunchKit library
 */
@property (readonly, nonatomic, nonnull) NSString *version;


/*!
 @method

 @abstract
 Sets optional data identifying the user that is currently using your app.

 @discussion
 This is optional, and helps identify a particular user when viewing LaunchKit data.
 You should make sure that sending user data to LaunchKit is acceptable per your
 application's Terms of Use and Privacy Policy.

 @param userIdentifier An arbitrary string, like a database index or hash, that ties an user to your system.
 @param email The user's email address, if your system supports it
 @param name The user's name or username/screenname, if your system supports it.

 */
- (void) setUserIdentifier:(nullable NSString *)userIdentifier email:(nullable NSString *)userEmail name:(nullable NSString *)userName;


#pragma mark - Debugging (for LaunchKit developers :D)

/*!
 @method

 @abstract
 For LaunchKit internal development. It lets us tell LaunchKit to talk to our own local computer to make
 it easier to iterate while working on new features, debugging, etc.

 @discussion
 Set to YES if you want the LaunchKit instance to be talking to your local computer. Be sure you have
 the local LaunchKit server running. Also ensure that you are using a local API token, and not your
 production token, as it won't be recognized by the local LaunchKit server.
 
 This can only be set BEFORE you have called launchWithToken: or sharedInstance.

 @param useLocalLaunchKitServer Set to YES if you want the LaunchKit instance to be talking to your local computer.

 */
+ (void)useLocalLaunchKitServer:(BOOL)useLocalLaunchKitServer;
@end
