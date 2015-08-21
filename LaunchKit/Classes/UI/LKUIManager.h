//
//  LKUIManager.h
//  Pods
//
//  Created by Rizwan Sattar on 1/19/15.
//
//

#import <Foundation/Foundation.h>

#import "LaunchKitShared.h"
#import "LKBundlesManager.h"
#import "LKViewController.h"

@class LKUIManager;
@protocol LKUIManagerDelegate <NSObject>

@end




@interface LKUIManager : NSObject

@property (weak, nonatomic) NSObject <LKUIManagerDelegate> *delegate;

- (instancetype)initWithBundlesManager:(LKBundlesManager *)bundlesManager;

#pragma mark - Remote UI Loading
- (void)loadRemoteUIWithId:(NSString *)remoteUIId completion:(LKRemoteUILoadHandler)completion;

#pragma mark - Presenting UI
- (void)presentRemoteUIViewController:(LKViewController *)viewController
                   fromViewController:(UIViewController *)presentingViewController
                             animated:(BOOL)animated
                     dismissalHandler:(LKRemoteUIDismissalHandler)dismissalHandler;


@end
