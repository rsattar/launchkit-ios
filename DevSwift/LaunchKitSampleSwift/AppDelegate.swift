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
class AppDelegate: UIResponder, UIAlertViewDelegate, UIApplicationDelegate {

    var window: UIWindow?

    // token warning
    var alertController: UIAlertController?
    var alertView: UIAlertView?

    // TODO: Listen for NSUserDefaultsDidChangeNotification and start launch kit again if so


    var availableLaunchKitToken: String? {

        var launchKitToken: String? = LAUNCHKIT_TOKEN
        if let token = launchKitToken where token == "YOUR_LAUNCHKIT_TOKEN" {
            // Otherwise fetch the launchkit token from the Settings bundle
            if let tokenInSettings = NSUserDefaults.standardUserDefaults().objectForKey("launchKitToken") as? String {
                launchKitToken = tokenInSettings
            }
        }
        if (launchKitToken != nil && (launchKitToken!.characters.count == 0 || launchKitToken! == "YOUR_LAUNCHKIT_TOKEN")) {
            // Our token is non-nil but is not valid (empty or unusable default)
            return nil
        }
        return launchKitToken
    }


    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        NSUserDefaults.standardUserDefaults().registerDefaults(["launchKitToken" : LAUNCHKIT_TOKEN])
        // In case, you the developer, has directly modified the launchkit token here

        self.startLaunchKitIfPossible()
        LaunchKit.sharedInstance().presentOnboardingUIOnWindow(self.window!, completionHandler: nil)
        return true
    }

    func startLaunchKitIfPossible() -> Bool {
        guard let launchKitToken = self.availableLaunchKitToken where !LaunchKit.hasLaunched() else {
            return false
        }

        // Valid token, so create LaunchKit instance
        if USE_LOCAL_LAUNCHKIT_SERVER {
            LaunchKit.useLocalLaunchKitServer(true)
        }
        LaunchKit.launchWithToken(launchKitToken)
        LaunchKit.sharedInstance().debugMode = true
        LaunchKit.sharedInstance().verboseLogging = true
        LaunchKit.sharedInstance().debugAppUserIsAlwaysSuper = true
        // Use convenience method for setting up the ready-handler
        LKConfigReady({
            print("Config is ready")
        })
        // Use the normal method for setting up the refresh handler
        LaunchKit.sharedInstance().config.refreshHandler = { (oldParameters, newParameters) -> Void in
            print("Config was refreshed!")
            if LKAppUserIsSuper() {
                print("User is considered super!")
            }
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

        if self.availableLaunchKitToken != nil {

            if self.alertController != nil {
                self.window?.rootViewController?.dismissViewControllerAnimated(true, completion: nil)
            } else if self.alertView != nil {
                self.alertView?.dismissWithClickedButtonIndex(self.alertView!.cancelButtonIndex, animated: true)
            }
            self.alertController = nil
            self.alertView = nil

            if !LaunchKit.hasLaunched() {
                self.startLaunchKitIfPossible()
            }

        } else {
            if self.alertController == nil && self.alertView == nil {
                // If we've never shown this alert before
                let title = "Set LaunchKit Token"
                let msg = "You must go to Settings and enter in your LaunchKit token."

                if NSClassFromString("UIAlertController") != nil {
                    self.alertController = UIAlertController(title: title, message: msg, preferredStyle: .Alert)
                    self.alertController!.addAction(UIAlertAction(title: "Close", style: UIAlertActionStyle.Cancel, handler: { [unowned self] (action) -> Void in
                        self.alertController = nil
                    }))
                    self.alertController!.addAction(UIAlertAction(title: "Settings", style: .Default, handler: { [unowned self] (action) -> Void in
                        self.alertController = nil
                        UIApplication.sharedApplication().openURL(NSURL(string: UIApplicationOpenSettingsURLString)!)
                    }))
                    self.window?.rootViewController?.presentViewController(self.alertController!, animated: true, completion: nil)
                } else {
                    self.alertView = UIAlertView(title: title, message: msg, delegate: self, cancelButtonTitle: "Okay")
                    self.alertView!.show()
                }
            }
        }
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    // MARK: - UIAlertViewDelegate
    func alertView(alertView: UIAlertView, didDismissWithButtonIndex buttonIndex: Int) {
        self.alertView = nil
    }


}

