//
//  LaunchKit.h
//  LaunchKit
//
//  Created by Cluster Labs, Inc. on 1/13/15.
//
//

#import <Foundation/Foundation.h>

#import "LaunchKitShared.h"
#import "LKAppUser.h"
#import "LKConfig.h"
#import "LKUIManager.h"

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

/*!
 @method

 @abstract
 Returns YES if LaunchKit has been launched with `+launchWithToken`.

 @discussion
 This is useful in case you need to conditionally start LaunchKit
 and need to verify whether it's already started or not.
 */
+ (BOOL)hasLaunched;


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
 * If true, LKAppUserIsSuper() will always return true, ignoring the value from the server.
 * @discussion This only works when debugging (i.e. when DEBUG = 1)
 */
@property (assign, nonatomic) BOOL debugAppUserIsAlwaysSuper;


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

/**
 * Always present App Update Notes, for testing. (Only valid for debug builds).
 * @discussion Note that your LaunchKit account should have Update Notes configured
 * for this version of your app, or nothing will be shown.
 */
@property (assign, nonatomic) BOOL debugAlwaysPresentAppReleaseNotes;


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


#pragma mark - Release Notes

- (void) presentAppReleaseNotesFromViewController:(nonnull UIViewController *)viewController
                                       completion:(nullable LKReleaseNotesCompletionHandler)completion;


#pragma mark - Remote UI
/*!
 @method

 @abstract
 Loads remote UI (generally cached to disk) you have configured at launchkit.io to work with this app.

 @discussion
 Given an id, LaunchKit will look for a UI with that id within its remote UI cache, and perhaps retrieve it
 on demand. The view controller returned is a special view controller that is designed to work with the remote
 nibs retrieved from LaunchKit. You can tell LaunchKit to present this view controller using
 -presentRemoteUIViewController:fromViewController:animated:dismissalHandler

 @param remoteUIId A string representing the id of the UI you want to load. This is configured at launchkit.io.
 @param completion When the remote UI is available, an instance of the view controller is returned. If an error occurred,
 the error is returned as well. You should ret

 */
- (void)loadRemoteUIWithId:(nonnull NSString *)remoteUIId completion:(nonnull LKRemoteUILoadHandler)completion;

/*!
 @method

 @abstract
 Presents loaded remote UI on behalf of the presentingViewController, handling its dismissal.

 @discussion
 Once remote UI is loaded (see -loadRemoteUIWithId:completion:), you should pass it to this method to present it.

 @param viewController The LaunchKit view controller that is generally loaded on demand
 @param presentingViewController The view controller to present the remote UI from.
 @param animated Whether to animate the modal presentation
 @param dismissalHandler When the remote UI has finished its flow, the UI is dismissed, and then this handler
 is called, in case you want to take action after its dismissal.
 */
- (void)presentRemoteUIViewController:(nonnull LKViewController *)viewController
                   fromViewController:(nonnull UIViewController *)presentingViewController
                             animated:(BOOL)animated
                     dismissalHandler:(nullable LKRemoteUIDismissalHandler)dismissalHandler;


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
