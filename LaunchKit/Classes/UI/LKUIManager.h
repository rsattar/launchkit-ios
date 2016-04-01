//
//  LKUIManager.h
//  LaunchKit
//
//  Created by Rizwan Sattar on 1/19/15.
//
//

#import <Foundation/Foundation.h>

#import "LaunchKitShared.h"
#import "LKBundlesManager.h"
#import "LKViewController.h"

typedef void (^LKReleaseNotesCompletionHandler)(BOOL didPresent);
typedef void (^LKRemoteUILoadHandler)(LKViewController * _Nullable viewController, NSError * _Nullable error);
typedef void (^LKRemoteUIDismissalHandler)(LKViewControllerFlowResult flowResult);
// Used internally, returning additional usage stats
typedef void (^LKOnboardingUIDismissHandler)(LKViewControllerFlowResult flowResult,
                                             NSDictionary * _Nullable additionalFlowParameters,
                                             LKBundleInfo * _Nullable bundleInfo,
                                             NSDate * _Nonnull onboardingStartTime,
                                             NSDate * _Nonnull onboardingEndTime,
                                             NSTimeInterval preOnboardingDuration);
// Used externally, to report overall flow result
typedef void (^LKOnboardingUICompletionHandler)(LKViewControllerFlowResult flowResult);
typedef void (^LKAppReviewCardCompletionHandler)(LKViewControllerFlowResult flowResult);

@class LKUIManager;
@protocol LKUIManagerDelegate <NSObject>

- (void)uiManagerRequestedToReportUIEvent:(nonnull NSString *)eventName
                             uiBundleInfo:(nullable LKBundleInfo *)uiBundleInfo
                     additionalParameters:(nullable NSDictionary *)additionalParameters;

@end


@interface LKUIManager : NSObject

@property (weak, nonatomic, nullable) NSObject <LKUIManagerDelegate> *delegate;

- (nonnull instancetype)initWithBundlesManager:(nonnull LKBundlesManager *)bundlesManager;

#pragma mark - Remote UI Loading
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
- (void)loadRemoteUIWithId:(nonnull NSString *)remoteUIId completion:(nullable LKRemoteUILoadHandler)completion;

#pragma mark - Presenting UI


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
- (BOOL)remoteUIPresentedForThisAppVersion:(nonnull NSString *)remoteUIId;

#pragma mark - Onboarding UI
- (void)presentOnboardingUIOnWindow:(nullable UIWindow *)window
                maxWaitTimeInterval:(NSTimeInterval)maxWaitTimeInterval
                  completionHandler:(nullable LKOnboardingUICompletionHandler)completionHandler;

#pragma mark - App Review Card
- (void) presentAppReviewCardIfNeededFromViewController:(nonnull UIViewController *)presentingViewController
                                             completion:(nullable LKAppReviewCardCompletionHandler)completion;

#pragma mark - App Release Notes
- (void) presentAppReleaseNotesFromViewController:(nonnull UIViewController *)viewController
                                       completion:(nullable LKReleaseNotesCompletionHandler)completion;

@end
