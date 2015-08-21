//
//  LKPopCustomSegue.m
//  LaunchKitRemoteUITest
//
//  Created by Rizwan Sattar on 6/17/15.
//  Copyright (c) 2015 Cluster Labs, Inc. All rights reserved.
//

#import "LKPopCustomSegue.h"

@implementation LKPopCustomSegue

- (void) perform
{
    UIViewController *sourceViewController = self.sourceViewController;
    UIViewController *destinationViewController = self.destinationViewController;
    UIView *sourceView = sourceViewController.view;
    UIView *destinationView = destinationViewController.view;

    CGRect sourceStartFrame = sourceViewController.view.frame;
    CGRect destinationStartFrame = CGRectOffset(sourceStartFrame, -CGRectGetWidth(sourceStartFrame), 0.0);
    CGRect sourceEndFrame = CGRectOffset(sourceStartFrame, +CGRectGetWidth(sourceStartFrame), 0.0);
    CGRect destinationEndFrame = sourceStartFrame;

    //UIWindow *window = [UIApplication sharedApplication].keyWindow;
    [sourceView.superview insertSubview:destinationView aboveSubview:sourceView];


    destinationView.alpha = 0.0;
    destinationView.frame = destinationStartFrame;
    [destinationView layoutIfNeeded];

    [UIView animateWithDuration:0.35 animations:^{
        sourceView.alpha = 0.0;
        sourceView.frame = sourceEndFrame;

        destinationView.alpha = 1.0;
        destinationView.frame = destinationEndFrame;

    } completion:^(BOOL finished) {
        [sourceViewController.navigationController popToViewController:destinationViewController animated:NO];
        sourceView.alpha = 1.0;
        
    }];
}

@end
