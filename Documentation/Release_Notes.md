<p align="center"><img src="https://d2kfjaekmjmy1l.cloudfront.net/images/whats-new/icon-v0bb9d08f9206.png" width="100" alt="LaunchKit Cloud Config Logo"/></p>
# LaunchKit Release Notes


### Step 1: Install and Configure LaunchKit iOS SDK

If it is not already, [install the LaunchKit iOS SDK](https://github.com/LaunchKit/launchkit-ios/blob/master/README.md) in your app.



### Step 2: Show Your Release Notes Card

A good time to show the card is after the user logs in, on the main screen of the application, in `viewDidAppear`.

Swift:

```
import LaunchKit

...
override func viewDidAppear(animated: Bool) {
    super.viewDidAppear(animated)
    LaunchKit.sharedInstance().presentAppReleaseNotesIfNeededFromViewController(self) { (didPresent) -> Void in
        if didPresent {
            print("Woohoo, we showed the release notes card!")
        }
    }
}
```

Objective C:

```
#import <LaunchKit/LaunchKit.h>

...
- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [[LaunchKit sharedInstance] presentAppReleaseNotesIfNeededFromViewController:self completion:^(BOOL didPresent) {
        if (didPresent) {
            NSLog(@"Woohoo, we showed the release notes card!");
        }
    }];
}
```

That's pretty much it! LaunchKit will show you release notes in your app if:

* You _have_ release notes available for this particular version of your app, and
* You _haven't_ shown those release notes before, on that device.

#### Debugging
If you'd like to _always_ present the release notes card (ignoring whether LaunchKit has shown them before, while debugging), you can set a debug flag:

Swift:

```
LaunchKit.sharedInstance().debugAlwaysPresentAppReleaseNotes = true
```

Objective C:

```
[LaunchKit sharedInstance].debugAlwaysPresentAppReleaseNotes = YES;
```

---
#### Author

Cluster Labs, Inc., info@launchkit.io

#### License

LaunchKit is available under the Apache 2.0 license. See the LICENSE file for more info.