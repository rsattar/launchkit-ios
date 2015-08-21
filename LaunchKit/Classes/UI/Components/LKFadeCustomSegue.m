//
//  LKFadeCustomSegue.m
//  LaunchKitRemoteUITest
//
//  Created by Rizwan Sattar on 6/15/15.
//  Copyright (c) 2015 Cluster Labs, Inc. All rights reserved.
//

#import "LKFadeCustomSegue.h"

@implementation LKFadeCustomSegue

- (void) perform
{
    UIViewController *sourceViewController = self.sourceViewController;
    UIViewController *destinationViewController = self.destinationViewController;
    UIView *destinationView = destinationViewController.view;
    UIWindow *window = [UIApplication sharedApplication].keyWindow;

    destinationView.alpha = 0.0;
    destinationView.frame = sourceViewController.view.frame;
    [window insertSubview:destinationView aboveSubview:sourceViewController.view];
    [UIView animateWithDuration:0.35 animations:^{
        destinationView.alpha = 1.0;
    } completion:^(BOOL finished) {
        [sourceViewController.navigationController pushViewController:destinationViewController animated:NO];
    }];
}

@end
