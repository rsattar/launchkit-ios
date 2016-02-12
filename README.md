<p align="center"><img src="https://d2kfjaekmjmy1l.cloudfront.net/images/icon-v8d70a510a2c9.png" width="100" alt="LaunchKit Logo"/></p>

# LaunchKit iOS SDK

The LaunchKit iOS SDK supports some of the app-level products in [LaunchKit](https://launchkit.io), like [Super Users](https://launchkit.io/users/onboard/install).

## Install and Configure LaunchKit iOS SDK
<!--
We are still learning how to make this easy for you. If you have any feedback, please send it our way.

---


_Warning! This part of the process needs to be completed by someone with access to your mobile app’s source code. If that’s not you, we’ve made it easy to get them involved. Just click here to send them an email with all the info they need._

---
-->

### Step 1

#### Option 1: CocoaPods
LaunchKit is available through [CocoaPods](http://cocoapods.org/). To install it, simply add the following line to your `Podfile`:

```
pod 'LaunchKit'
```

#### Option 2: Carthage
LaunchKit is also available through [Carthage](https://github.com/Carthage/Carthage). Add the following line to your `Cartfile`:

```
github "LaunchKit/launchkit-ios"
```

#### Option 3: Manual Installation
You can install the LaunchKit SDK manually by [cloning the repo](https://github.com/launchkit/launchkit-ios) or [downloading the latest release](https://github.com/launchkit/launchkit-ios/releases), and copy the files in:

```
LaunchKit/Classes
```
...to your project. Additionally, you will also have to:

1. Add `zlib` as a dependency on your app target.
2. Set `LAUNCHKIT_MANUAL_IMPORT=1` in your target's Build Settings, for all configurations (Debug and Release, by default). [See Screenshot](http://cl.ly/2a41171u0q1q)
 

### Step 2
#### Add to your App Delegate
##### _Objective C_
Somewhere near the top of your `-applicationDidFinishLaunching:withOptions:`, add `[LaunchKit launchWithToken:@"YOUR_API_TOKEN"]`, where `YOUR_API_TOKEN` is [a special token you can get here](https://launchkit.io/account/sdk-tokens).

```objc
#import <LaunchKit/LaunchKit.h>

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Add this line
    [LaunchKit launchWithToken:@"YOUR_API_TOKEN"]

    ...
}
```

##### _Swift_

```swift
import LaunchKit

...
func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
    // Add this line
    LaunchKit.launchWithToken("YOUR_API_TOKEN")

    ...
}
```
<!--
### Step 3 (Xcode 7 / iOS 9)
LaunchKit access some resources in Amazon AWS, and Amazon isn't fully TLS ready (yet). They have [documented the issue](https://mobile.awsblog.com/post/Tx2QM69ZE6BGTYX/Preparing-Your-Apps-for-iOS-9).

In your app's `Info.plist` file, add the following properties to `NSAppTransportSecurity`:

```
<key>NSAppTransportSecurity</key>
<dict>
	<key>NSAllowsArbitraryLoads</key>
	<false/>
	<key>NSExceptionDomains</key>
       <dict>
           <key>amazonaws.com</key>
           <dict>
               <key>NSThirdPartyExceptionMinimumTLSVersion</key>
               <string>TLSv1.0</string>
               <key>NSThirdPartyExceptionRequiresForwardSecrecy</key>
               <false/>
               <key>NSIncludesSubdomains</key>
               <true/>
           </dict>
           <key>amazonaws.com.cn</key>
           <dict>
               <key>NSThirdPartyExceptionMinimumTLSVersion</key>
               <string>TLSv1.0</string>
               <key>NSThirdPartyExceptionRequiresForwardSecrecy</key>
               <false/>
               <key>NSIncludesSubdomains</key>
               <true/>
           </dict>
	</dict>
</dict>
```

### (Optional) Step 4
#### Add Build Phase
If you are using remote resources like What's New, this script will retrieve any resource NSBundles and place them within your App Bundle as a cache. That way, those resources will be available immediately upon app start. On subsequent starts, LaunchKit will download any newer available versions of those resources, in case you make changes after building your app!

##### _Click Project in Xcode, and go to Build Phases_
![](http://i.imgur.com/2t4s3ua.png =800x)


##### _Click the + icon, and add a Script Phase_
![](http://i.imgur.com/7x0C22e.png =600x)

##### _Paste the following_

```
SCRIPT=`/usr/bin/find "${SRCROOT}/.." -name LaunchKitRemoteBundlesScript.playground | head -n 1`
xcrun -sdk macosx swift "${SCRIPT}/Contents.swift" "YOUR_API_TOKEN"
```
![](http://i.imgur.com/y9NUjpn.png =800x)
-->

---
### Author

Cluster Labs, Inc., info@launchkit.io

### License

LaunchKit is available under the Apache 2.0 license. See the LICENSE file for more info.