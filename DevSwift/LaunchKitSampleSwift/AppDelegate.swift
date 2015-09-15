//
//  AppDelegate.swift
//  LaunchKitSampleSwift
//
//  Created by Rizwan Sattar on 7/23/15.
//  Copyright (c) 2015 Cluster Labs, Inc. All rights reserved.
//

import UIKit
import LaunchKit

let USE_LOCAL_LAUNCHKIT_SERVER = false
let LAUNCHKIT_TOKEN: String = "YOUR_LAUNCHKIT_TOKEN"

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        NSUserDefaults.standardUserDefaults().registerDefaults(["launchKitToken" : LAUNCHKIT_TOKEN])
        // In case, you the developer, has directly modified the launchkit token here
        var launchKitToken = LAUNCHKIT_TOKEN
        if launchKitToken == "YOUR_LAUNCHKIT_TOKEN" {
            // Otherwise fetch the launchkit token from the Settings bundle
            if let token = NSUserDefaults.standardUserDefaults().objectForKey("launchKitToken") as? String {
                launchKitToken = token
            }
        }
        if launchKitToken.characters.count == 0 || launchKitToken == "YOUR_LAUNCHKIT_TOKEN" {
            // We don't have a valid launchkit token, so prompt
            let title = "Set LaunchKit Token"
            let msg = "You must go to Settings and enter in your LaunchKit token."

            if NSClassFromString("UIAlertController") != nil {
                let alert = UIAlertController(title: title, message: msg, preferredStyle: .Alert)
                alert.addAction(UIAlertAction(title: "Close", style: UIAlertActionStyle.Cancel, handler: nil))
                alert.addAction(UIAlertAction(title: "Settings", style: .Default, handler: { (action) -> Void in
                    UIApplication.sharedApplication().openURL(NSURL(string: UIApplicationOpenSettingsURLString)!)
                }))

                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1*Double(NSEC_PER_SEC))), dispatch_get_main_queue(), { () -> Void in
                    self.window?.rootViewController?.presentViewController(alert, animated: true, completion: nil)
                })
            } else {
                let alertView = UIAlertView(title: title, message: msg, delegate: nil, cancelButtonTitle: "Okay")
                alertView.show()
            }
        } else {
            // Valid token, so create LaunchKit instance
            if USE_LOCAL_LAUNCHKIT_SERVER {
                LaunchKit.useLocalLaunchKitServer(true)
            }
            LaunchKit.launchWithToken(launchKitToken)
            LaunchKit.sharedInstance().debugMode = true
            LaunchKit.sharedInstance().verboseLogging = true
        }

        return true
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


}

