//
//  RootViewController.swift
//  LaunchKitSampleSwift
//
//  Created by Rizwan Sattar on 7/23/15.
//  Copyright (c) 2015 Cluster Labs, Inc. All rights reserved.
//

import UIKit
import LaunchKit

class RootViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        LaunchKit.sharedInstance().presentAppReleaseNotesFromViewController(self) { (success) -> Void in
            print("Release notes finished with success: \(success)")
        }

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func showUIWithName(uiName:String) {
        LaunchKit.sharedInstance().uiManager.loadRemoteUIWithId(uiName, completion: { [unowned self] (viewController, error) -> Void in
            if let viewController = viewController {
                LaunchKit.sharedInstance().presentRemoteUIViewController(viewController, fromViewController: self, animated: true, dismissalHandler: nil);
            } else {
                let message: String
                if let error = error {
                    let reason: String
                    if let errorMessage = error.userInfo["message"] as? String {
                        reason = errorMessage
                    } else {
                        reason = ""
                    }
                    message = "Could not load UI named '\(uiName)'.\n\nError \(error.code) - \(reason)"
                } else {
                    message = "Could not load UI named '\(uiName)'."
                }
                let alertController = UIAlertController(title: "UI not found", message: message, preferredStyle: .Alert);
                alertController.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: nil))
                self.presentViewController(alertController, animated: true, completion: nil)
            }
        })
    }

}

