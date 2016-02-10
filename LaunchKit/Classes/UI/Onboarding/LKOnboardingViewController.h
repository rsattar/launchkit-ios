//
//  LKOnboardingViewController.h
//  Pods
//
//  Created by Rizwan Sattar on 1/25/16.
//
//

#import <UIKit/UIKit.h>

#import "LKViewController.h"
#import "LKUIManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface LKOnboardingViewController : LKViewController

@property (assign, nonatomic) NSTimeInterval maxWaitTimeInterval;
@property (copy, nonatomic, nullable) LKRemoteUIDismissalHandler dismissalHandler;

- (void) setActualOnboardingUI:(UIViewController *)actualOnboardingUI;
- (void) finishOnboardingWithResult:(LKViewControllerFlowResult)result;

@end

NS_ASSUME_NONNULL_END