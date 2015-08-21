//
//  LKNavigationController.m
//  LaunchKitRemoteUITest
//
//  Created by Rizwan Sattar on 6/17/15.
//  Copyright (c) 2015 Cluster Labs, Inc. All rights reserved.
//

#import "LKNavigationController.h"

#import "LKPopCustomSegue.h"
#import "LKViewController.h"

// This class is only required so that we can override the segueForUnwindingToViewController:fromViewController:identifier,
// and allow us to define custom unwind segues from a storyboard (by setting a custom 'unwindSegueClassName' property on
// LKViewController). See: http://blog.dadabeatnik.com/2013/10/13/custom-segues/
@interface LKNavigationController ()

@end

@implementation LKNavigationController

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/


- (UIStoryboardSegue *) segueForUnwindingToViewController:(UIViewController *)toViewController fromViewController:(UIViewController *)fromViewController identifier:(NSString *)identifier
{
    NSString *customUnwindSegueName = nil;
    if ([fromViewController isKindOfClass:[LKViewController class]]) {
        customUnwindSegueName = ((LKViewController *)fromViewController).unwindSegueClassName;
    }

    if ([customUnwindSegueName isEqualToString:@"LKPopCustomSegue"]) {
        return [[LKPopCustomSegue alloc] initWithIdentifier:identifier source:fromViewController destination:toViewController];
    } else {
        return [super segueForUnwindingToViewController:toViewController fromViewController:fromViewController identifier:identifier];
    }
    
}

@end
