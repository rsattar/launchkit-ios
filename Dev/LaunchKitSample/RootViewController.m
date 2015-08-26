//
//  RootViewController.m
//  LaunchKit
//
//  Created by Rizwan Sattar on 01/12/2015.
//  Copyright (c) 2014 Rizwan Sattar. All rights reserved.
//

#import "RootViewController.h"

#import <LaunchKit/LaunchKit.h>

@interface RootViewController ()

@end

@implementation RootViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    [[LaunchKit sharedInstance] presentAppUpdateNotesFromViewController:self completion:^(BOOL didPresent) {
        NSLog(@"Did present: %d", didPresent);
    }];

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)showUIWithName:(NSString *)uiName
{
    __weak RootViewController *_weakSelf = self;
    [[LaunchKit sharedInstance] loadRemoteUIWithId:uiName completion:^(LKViewController *viewController, NSError *error) {
        if (viewController) {
            [[LaunchKit sharedInstance] presentRemoteUIViewController:viewController fromViewController:_weakSelf animated:YES dismissalHandler:nil];
        } else {
            NSString *message = nil;
            if (error) {
                NSString *reason = @"";
                NSString *errorMessage = error.userInfo[@"message"];
                if (errorMessage.length > 0) {
                    reason = errorMessage;
                }
                message = [NSString stringWithFormat:@"Could not load UI named %@.\n\nError %ld - %@", uiName, (long)error.code, reason];
            } else {
                message = [NSString stringWithFormat:@"Could not load UI named %@.", uiName];
            }
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"UI not found"
                                                                message:message
                                                               delegate:nil
                                                      cancelButtonTitle:@"OK"
                                                      otherButtonTitles:nil];
            [alertView show];
        }
    }];
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll;
}

@end
