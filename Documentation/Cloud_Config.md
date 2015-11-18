<p align="center"><img src="https://d2kfjaekmjmy1l.cloudfront.net/images/config/icon-vdbbe8113cc85.png" width="100" alt="LaunchKit Cloud Config Logo"/></p>
# LaunchKit Cloud Config Setup


### Step 1: Install and Configure LaunchKit iOS SDK

If it is not already, [install the LaunchKit iOS SDK](https://github.com/LaunchKit/launchkit-ios/blob/master/README.md) in your app.

### Step 2: Add Some Keys For Your App

LaunchKit Cloud Config works like a simple key-value system. [Go and add some config keys for your app on LaunchKit's website](https://launchkit.io/config/onboard).

### Step 3: Access Those Keys with the SDK

Replace hardcoded settings in your code with calls to access config using the LaunchKit SDK.

## Usage
LaunchKit Cloud Config allows you to store config as Booleans, Integers, Doubles, and Strings. Here are examples on what the code would look like:

### Booleans
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




### Integers
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




### Doubles
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




### Strings
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

## Default Values

Immediately upon app launch, LaunchKit will retrieve the current configuration for your app and store it on disk. It will also periodically ping the LaunchKit server for new config (such as when the app returns from the background).

There is always the unlikely chance that LaunchKit can't get the _any_ configuration. Each SDK call to read a config requires that you provide a **reasonable default value** for that key. This could be the value you previously had hard-coded. The default value is returned if (and only if) that configuration key is not available locally (i.e. config that includes the key was _never_ retrieved and persisted). If a cached value for that key is available, that is returned instead.

Since some form of configuration is always available locally, the SDK doesn't require a callback-based retrieval of each configuration value. You can simple access it using the methods above.

## Ready Handler

In some cases, you might want to update some settings at the launch (or very close to launch) of your app. For that, the SDK has the `LKConfigReady(callback)` function. You can pass in an Objective C block or Swift closure:

Swift:

```swift
func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
    
    // Configure and start LaunchKit
    LaunchKit.launchWithToken(launchKitToken)
    
    // Add ready-handler
    LKConfigReady({
        print("Config is ready")
    })
    
    return true
}

```

Objective C:

```objc
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	// Configure and start LaunchKit
	[LaunchKit launchWithToken:launchKitToken];
	
	// Add ready-handler
	LKConfigReady(^{
		NSLog(@"Config is ready");
	});	
	
	return YES;
}

```

This callback is called only once per app session, when LaunchKit has first retrieved the configuration over the network. Note that the configuration may be the same as what is already cached locally. This gives you the assurance that the config is the _newest_ available to the SDK.

If you'd like to be notified whenever LaunchKit has the newest config available _and subsequent changes_, you should use the `LKConfigRefreshed()` method instead.

---
#### Author

Cluster Labs, Inc., info@launchkit.io

#### License

LaunchKit is available under the Apache 2.0 license. See the LICENSE file for more info.