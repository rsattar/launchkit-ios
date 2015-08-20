//
//  AppDelegate.m
//  LaunchKit
//
//  Created by CocoaPods on 01/12/2015.
//  Copyright (c) 2014 Rizwan Sattar. All rights reserved.
//

#import "AppDelegate.h"

#import <LaunchKit/LaunchKit.h>

#define USE_LOCAL_LAUNCHKIT_SERVER 0

static NSString *const LAUNCHKIT_TOKEN = @"YOUR_LAUNCHKIT_TOKEN";

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [self.window makeKeyAndVisible];
    
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{@"launchKitToken" : LAUNCHKIT_TOKEN}];
    // In case, you the developer, has directly modified the launchkit token here
    NSString *launchKitToken = LAUNCHKIT_TOKEN;
    if ([launchKitToken isEqualToString:@"YOUR_LAUNCHKIT_TOKEN"]) {
        // Otherwise fetch the launchkit token from the Settings bundle
        launchKitToken = [[NSUserDefaults standardUserDefaults] objectForKey:@"launchKitToken"];
    }
    if (launchKitToken.length == 0 || [launchKitToken isEqualToString:@"YOUR_LAUNCHKIT_TOKEN"]) {
        // We don't have a valid launch kit token, so prompt
        NSString *title = @"Set LaunchKit Token";
        NSString *msg = @"You must go to Settings and enter "
                         "in your LaunchKit token.";
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
        if (NSClassFromString(@"UIAlertController") != nil) {

            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
            [alertController addAction:[UIAlertAction actionWithTitle:@"Okay" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
            }]];
            [self.window.rootViewController presentViewController:alertController animated:YES completion:nil];
            
        } else {
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:msg delegate:nil cancelButtonTitle:@"Okay" otherButtonTitles:nil];
            [alertView show];
        }
#else
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:msg delegate:nil cancelButtonTitle:@"Okay" otherButtonTitles:nil];
        [alertView show];
#endif
    } else {
        // Valid token, so create LaunchKit instance
#if USE_LOCAL_LAUNCHKIT_SERVER
        [LaunchKit useLocalLaunchKitServer:YES];
#endif
        [LaunchKit launchWithToken:launchKitToken];
        [LaunchKit sharedInstance].debugMode = YES;
        [LaunchKit sharedInstance].verboseLogging = YES;
    }
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
