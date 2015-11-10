//
//  LKViewController.h
//  LaunchKitRemoteUITest
//
//  Created by Rizwan Sattar on 6/15/15.
//  Copyright (c) 2015 Cluster Labs, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "LKBundleInfo.h"

typedef NS_ENUM(NSInteger, LKViewControllerFlowResult)
{
    LKViewControllerFlowResultNotSet,
    LKViewControllerFlowResultCompleted,
    LKViewControllerFlowResultCancelled,
    LKViewControllerFlowResultFailed,
};

@class LKViewController;
@protocol LKViewControllerFlowDelegate <NSObject>

- (void)launchKitController:(nonnull LKViewController *)controller
        didFinishWithResult:(LKViewControllerFlowResult)result
                   userInfo:(nullable NSDictionary *)userInfo;

@end


@interface LKViewController : UIViewController

@property (weak, nonatomic, nullable) id <LKViewControllerFlowDelegate> flowDelegate;

@property (strong, nonatomic, nullable) LKBundleInfo *bundleInfo;

@property (assign, nonatomic) IBInspectable BOOL statusBarShouldHide;
@property (assign, nonatomic) IBInspectable NSInteger statusBarStyleValue;

@property (strong, nonatomic, nullable) IBInspectable NSString *unwindSegueClassName;
@property (strong, nonatomic, nullable) IBInspectable NSString *presentationStyleName;

@property (assign, nonatomic) IBInspectable CGFloat viewCornerRadius;

// 'cardView' property can be set by a custom IB storyboard, but if it is not set,
// then it will reference self.view (it is set during viewDidLoad)
@property (strong, nonatomic, nullable) IBOutlet UIView *cardView;
@property (assign, nonatomic) IBInspectable BOOL cardPresentationCastsShadow;
@property (assign, nonatomic) CGFloat cardPresentationShadowRadius;
@property (assign, nonatomic) CGFloat cardPresentationShadowAlpha;

#pragma mark - Flow Delegation
- (void) finishFlowWithResult:(LKViewControllerFlowResult)result
                     userInfo:(nullable NSDictionary *)userInfo;

@end
