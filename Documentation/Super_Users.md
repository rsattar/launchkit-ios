<p align="center"><img src="https://d2kfjaekmjmy1l.cloudfront.net/images/users/icon-vf7b3589fac18.png" width="100" alt="LaunchKit Cloud Config Logo"/></p>
# LaunchKit Super Users


### Step 1: Install and Configure LaunchKit iOS SDK

If it is not already, [install the LaunchKit iOS SDK](https://github.com/LaunchKit/launchkit-ios/blob/master/README.md) in your app.

### Step 2: That's It!

Having the LaunchKit SDK configured will automatically begin measuring how your app is being used. You can check out your app's dashboard to see the different session.

## Optional: Set Optional User Info (If Available)

If your app has identifiable users, and you'd like to see their names in the Dashboard (rather than seeing anonymous sessions), you can set them optionally using the `setUserIdentifier:email:name:` method.

You can add as little or as much information as you'd like, and it is completely optional. We recommend you at least provide a userId. This is something that you have, or your server provides you, that uniquely identifies your user in a a way that is only meaningful against your database. 

For your convenience, you may add the user's name and/or email address, if that makes it easier for you to visualize the data on LaunchKit. You should make sure providing the user information to a trusted 3rd party like LaunchKit is covered in your Privacy Policy.


#### When the user logs in (or is already logged in on app start):

Swift:

```
import LaunchKit

...

// When the user finishes logging in, or is already logged in on start
LaunchKit.sharedInstance().setUserIdentifier("qxb49bd", email: "bob@loblaw.org", name: "Bob Loblaw")
```

Objective C:

```
#import <LaunchKit/LaunchKit.h>

...

// When the user finishes logging in, or is already logged in on start
[[LaunchKit sharedInstance] setUserIdentifier:@"qxb49bd" 
                                        email:@"bob@loblaw.org" 
                                         name:@"Bob Loblaw"];
```

#### When the user logs out:

Swift:

```
import LaunchKit

...

// Clear user info
LaunchKit.sharedInstance().setUserIdentifier(nil, email: nil, name: nil)
```

Objective C:

```
#import <LaunchKit/LaunchKit.h>

...

// Clear user info
[[LaunchKit sharedInstance] setUserIdentifier:nil
                                        email:nil
                                         name:nil];
```

## Using User Flags In Your App


Once you have set up the LaunchKit SDK, LaunchKit will report back to the SDK whether or not your app's user is a Super User. You can query this value simply by this call:

Objective C or Swift:

```
if (LKAppUserIsSuper()) {
    // User is a Super User, so you can perform different tasks for that user.
    enableAwesomeFeature();
}
```

Depending on how you configure the Super User criteria, LaunchKit may not immediately report your app's user as a Super User.

### When User Info Changes
If you'd like to be notified when the app user info changes, you can register for the `LKAppUserUpdatedNotificationName` event in `NSNotificationCenter`



---
#### Author

Cluster Labs, Inc., info@launchkit.io

#### License

LaunchKit is available under the Apache 2.0 license. See the LICENSE file for more info.