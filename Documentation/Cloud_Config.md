<p align="center"><img src="https://d2kfjaekmjmy1l.cloudfront.net/images/config/icon-vdbbe8113cc85.png" width="100" alt="LaunchKit Cloud Config Logo"/></p>
# LaunchKit Cloud Config Setup


### Step 1: Install and Configure LaunchKit iOS SDK

If it is not already, [install the LaunchKit iOS SDK](https://github.com/LaunchKit/launchkit-ios/blob/master/README.md) in your app.

### Step 2: Add Some Keys For Your App

LaunchKit Cloud Config works like a simple key-value system. [Go and add some config keys for your app on LaunchKit's website](https://launchkit.io/config/onboard).

### Step 3: That's it!

Just start using Cloud Config by replace settings in your code using the following functions:



## Booleans
# 
Use `LKConfigBool(key, defaultValue)`

Swift:

```swift
let showGoogleLogin = LKConfigBool("showGoogleLogin", false);
```

Objective C:

```objc
BOOL showGoogleLogin = LKConfigBool(@"showGoogleLogin", NO);
```




## Integers
# 
Use `LKConfigInteger(key, defaultValue)`

Swift:

```swift
let maxCharactersAllowed = LKConfigInteger("maxCharactersAllowed", 400);
```

Objective C:

```objc
NSInteger maxCharactersAllowed = LKConfigInteger(@"maxCharactersAllowed", 400);
```




## Doubles
# 
Use `LKConfigDouble(key, defaultValue)`

Swift:

```swift
let maxVideoDuration = LKConfigDouble("maxVideoDuration", 15.0);
```

Objective C:

```objc
NSTimeInterval maxVideoDuration = LKConfigDouble(@"maxVideoDuration", 15.0);
```




## Strings
# 
Use `LKConfigString(key, defaultValue)`

Swift:

```swift
let paymentProviderIdToUse = LKConfigString("paymentProviderId", "stripe");
```

Objective C:

```objc
NSString *paymentProviderIdToUse = LKConfigString(@"paymentProviderId", @"stripe");
```


---
#### Author

Cluster Labs, Inc., info@launchkit.io

#### License

LaunchKit is available under the Apache 2.0 license. See the LICENSE file for more info.