//
//  RootViewController.swift
//  LaunchKitSampleSwift
//
//  Created by Rizwan Sattar on 7/23/15.
//  Copyright (c) 2015 Cluster Labs, Inc. All rights reserved.
//

import UIKit
import LaunchKit

enum FirstLaunchUI {
    case releaseNotes
    case reviewCard
}

class RootViewController: UIViewController {

    @IBOutlet weak var showAppReleaseNotesButton: UIButton!

    let firstLaunchUI = FirstLaunchUI.releaseNotes

    override func viewDidLoad() {
        super.viewDidLoad()
        LKUIManifestRefreshed { () -> Void in
            // If App Release Notes are not available, disable the button
            self.showAppReleaseNotesButton.enabled = LaunchKit.sharedInstance().appReleaseNotesAvailable()
        }
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        switch firstLaunchUI {
        case .releaseNotes:
            LaunchKit.sharedInstance().presentAppReleaseNotesIfNeededFromViewController(self) { (success) -> Void in
                print("Release notes finished with success: \(success)")
            }
        case .reviewCard:
            LaunchKit.sharedInstance().presentAppReviewCardIfNeededFromViewController(self) { (flowResult) -> Void in
                print("App review card finished with flow result: \(NSStringFromViewControllerFlowResult(flowResult))")
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func onShowAppReleaseNotesButtonTriggered(sender: UIButton) {
        LaunchKit.sharedInstance().forcePresentationOfAppReleaseNotesFromViewController(self) { (success) -> Void in
            print("Release notes shown on demand, finished with success: \(success)")
        }
    }
}

