//
//  LaunchKitTests.m
//  LaunchKitTests
//
//  Created by Rizwan Sattar on 01/12/2015.
//  Copyright (c) 2014 Rizwan Sattar. All rights reserved.
//

#import <LaunchKit/LaunchKit.h>
#import <LaunchKit/LKAPIClient.h>
#import <LaunchKit/LKAnalytics.h>

NSString *const LAUNCHKIT_TEST_API_TOKEN = @"-0zvS4K8dMZRFrfUJdexflRpoRCuU4wmppfNfcoHkugo";

@interface LaunchKit (TestingAdditions)

@property (copy, nonatomic) NSString *apiToken;
/** Long-lived, persistent dictionary that is sent up with API requests. */
@property (copy, nonatomic) NSDictionary *sessionParameters;
@property (strong, nonatomic) LKAPIClient *apiClient;
@property (strong, nonatomic) NSTimer *trackingTimer;
@property (assign, nonatomic) NSTimeInterval trackingInterval;
// Analytics
@property (strong, nonatomic) LKAnalytics *analytics;
// Config
@property (readwrite, strong, nonatomic, nonnull) LKConfig *config;
// Bundles
@property (strong, nonatomic) LKBundlesManager *bundlesManager;

- (nonnull instancetype)initWithToken:(NSString *)apiToken;
- (void)archiveSession;
- (void)retrieveSessionFromArchiveIfAvailable;
- (void)trackProperties:(NSDictionary *)properties completionHandler:(void (^)())completion;

@end

@interface LKConfig (TestingAdditions)

@property (readwrite, strong, nonatomic, nonnull) NSDictionary *parameters;
- (NSDictionary *)dictionaryWithoutLaunchKitKeys:(nonnull NSDictionary *)dictionary;

@end

@interface LKAPIClient (TestingAdditions)

@property (strong, nonatomic) NSString *cachedBundleIdentifier; // E.g.: com.yourcompany.appname
@property (strong, nonatomic) NSString *cachedBundleVersion;    // E.g.: 1.2
@property (strong, nonatomic) NSString *cachedBuildNumber;      // E.g.: 14
@property (strong, nonatomic) NSString *cachedOSVersion;        // E.g.: iOS 8.1.3
@property (strong, nonatomic) NSString *cachedHardwareModel;    // E.g.: iPhone 7,1
@property (strong, nonatomic) NSString *cachedLocaleIdentifier; // E.g.: en_US, system's current language + region
@property (strong, nonatomic) NSString *cachedAppLocalization;  // E.g.: en, the localization the app is running as

@end

@interface LKBundlesManager (TestingAdditions)

- (LKBundleInfo *)localBundleInfoWithName:(NSString *)name;
- (LKBundleInfo *)remoteBundleInfoWithName:(NSString *)name;
- (void)retrieveAndCacheAvailableRemoteBundlesWithAssociatedServerTimestamp:(NSDate *)serverTimestamp completion:(void (^)(NSError *error))completion;

@end

SpecBegin(LaunchKitTest)

describe(@"LaunchKit", ^{

    __block LaunchKit *launchKit = nil;
    beforeAll(^{
        launchKit = [[LaunchKit alloc] initWithToken:LAUNCHKIT_TEST_API_TOKEN];
    });

    afterAll(^{
        launchKit = nil;
    });

    
    it(@"stores the API Token passed in", ^{
        expect(launchKit.apiToken).to.equal(LAUNCHKIT_TEST_API_TOKEN);
    });

    it(@"can restore its session parameters", ^{
        NSMutableDictionary *params = [NSMutableDictionary dictionaryWithDictionary:launchKit.sessionParameters];
        NSTimeInterval timeInterval = [[NSDate date] timeIntervalSince1970];
        params[@"test"] = @(timeInterval);
        launchKit.sessionParameters = params;
        [launchKit archiveSession];
        [launchKit retrieveSessionFromArchiveIfAvailable];
        expect(launchKit.sessionParameters).to.equal(params);
    });

    it(@"can handle multiple track calls, in sequence", ^{
        __block NSString *firstSessionId = nil;
        __block NSString *secondSessionId = nil;

        waitUntil(^(DoneCallback done) {
            launchKit.sessionParameters = @{};
            [launchKit trackProperties:nil completionHandler:^{
                // Should give us a new session Id
                firstSessionId = launchKit.sessionParameters[@"session_id"];
            }];
            [launchKit trackProperties:nil completionHandler:^{
                // Should give us the same session id
                secondSessionId = launchKit.sessionParameters[@"session_id"];
                done();
            }];
        });
        expect(firstSessionId).to.equal(secondSessionId);
    });

});

describe(@"LKConfig", ^{

    __block LKConfig *config = nil;
    beforeAll(^{
        config = [[LKConfig alloc] initWithParameters:@{}];
    });

    beforeEach(^{
        config.parameters = @{};
    });

    afterAll(^{
        config = nil;
    });

    it(@"returns BOOL correctly", ^{
        config.parameters = @{@"key" : @(YES)};
        BOOL extracted = [config boolForKey:@"key" defaultValue:NO];
        expect(extracted).to.equal(YES);
    });

    it(@"BOOL returns defaultValue if invalid", ^{
        config.parameters = @{@"key" : @"Not a bool"};
        BOOL extracted = [config boolForKey:@"key" defaultValue:YES];
        expect(extracted).to.equal(YES);
    });

    it(@"returns NSInteger correctly", ^{
        NSInteger originalValue = 15;
        config.parameters = @{@"key" : @(originalValue)};
        NSInteger extracted = [config integerForKey:@"key" defaultValue:-1];
        expect(extracted).to.equal(originalValue);
    });

    it(@"NSInteger returns defaultValue if invalid", ^{
        config.parameters = @{@"key" : @"Not an integer"};
        NSInteger extracted = [config integerForKey:@"key" defaultValue:-1];
        expect(extracted).to.equal(-1);
    });

    it(@"returns double correctly", ^{
        double originalValue = [[NSDate date] timeIntervalSince1970];
        config.parameters = @{@"key" : @(originalValue)};
        double extracted = [config doubleForKey:@"key" defaultValue:0.0];
        expect(extracted).to.equal(originalValue);
    });

    it(@"double returns defaultValue if invalid", ^{
        config.parameters = @{@"key" : @"Not a double"};
        double extracted = [config integerForKey:@"key" defaultValue:0.0];
        expect(extracted).to.equal(0.0);
    });

    it(@"returns NSString* correctly", ^{
        NSString *originalValue = @"Oh look, a string!";
        config.parameters = @{@"key" : originalValue};
        NSString *extracted = [config stringForKey:@"key" defaultValue:@"invalid string"];
        expect(extracted).to.equal(originalValue);
    });

    it(@"NSString* returns defaultValue if invalid", ^{
        config.parameters = @{@"key" : @(34)};
        NSString *extracted = [config stringForKey:@"key" defaultValue:@"invalid string"];
        expect(extracted).to.equal(@"invalid string");
    });

    it(@"strips internal keys", ^{
        NSDictionary *parameters = @{@"io.launchkit.currentVersionDuration" : @(0.018598),
                                     @"io.launchkit.installDuration" : @(0.018624)};
        NSDictionary *stripped = [config dictionaryWithoutLaunchKitKeys:parameters];
        expect(stripped.count).to.equal(0);
    });
});


describe(@"LKBundlesManager", ^{


    __block LaunchKit *launchKit = nil;
    beforeAll(^{
        [LKBundlesManager deleteBundlesCacheDirectory];

        launchKit = [[LaunchKit alloc] initWithToken:LAUNCHKIT_TEST_API_TOKEN];
        launchKit.apiClient.cachedBundleIdentifier = @"com.getcluster.LaunchKitSample.LKBundlesTest";
    });

    afterAll(^{
        launchKit = nil;
    });

    it(@"does not have local release notes bundle", ^{
        LKBundleInfo *info = [launchKit.bundlesManager localBundleInfoWithName:@"WhatsNew"];
        expect(info).to.beNil();
    });

    it(@"can find the release notes bundle for 1.0", ^{
        launchKit.apiClient.cachedBundleVersion = @"1.0";
        waitUntil(^(DoneCallback done) {
            [launchKit.bundlesManager retrieveAndCacheAvailableRemoteBundlesWithAssociatedServerTimestamp:nil completion:^(NSError *error) {
                done();
            }];
        });
        LKBundleInfo *info = [launchKit.bundlesManager localBundleInfoWithName:@"WhatsNew"];
        expect(info).to.beInstanceOf([LKBundleInfo class]);
    });

    it(@"up-to-date manifest can return a bundle immediately, if available", ^{
        // Ensure that we save our remote bundles with an actual timestamp that's testable
        NSDate *now = [NSDate date];
        waitUntil(^(DoneCallback done) {
            [launchKit.bundlesManager retrieveAndCacheAvailableRemoteBundlesWithAssociatedServerTimestamp:now completion:^(NSError *error) {
                done();
            }];
        });
        // Now create a new LK instance, with a new bundles manager instance
        LaunchKit *newLKInstance = [[LaunchKit alloc] initWithToken:LAUNCHKIT_TEST_API_TOKEN];
        newLKInstance.apiClient.cachedBundleIdentifier = @"com.getcluster.LaunchKitSample.LKBundlesTest";
        newLKInstance.apiClient.cachedBundleVersion = @"1.0";

        // Simulate how the bundlesManager might be told it is up-to-date
        //NSLog(@"Marking bundles manager as 'up-to-date'");
        [newLKInstance.bundlesManager updateServerBundlesUpdatedTimeWithTime:now];

        waitUntil(^(DoneCallback done) {
            //NSLog(@"Waiting 2.0 secs...");
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                done();
            });
        });
        __block BOOL loadedBundle = NO;
        waitUntilTimeout(2.0, ^(DoneCallback done) {
            //NSLog(@"loading 'WhatsNew' bundle in uptodate bundles manager...");
            [newLKInstance.bundlesManager loadBundleWithId:@"WhatsNew" completion:^(NSBundle *bundle, NSError *error) {
                //NSLog(@"'WhatsNew' bundle did load in the bundles manager!");
                loadedBundle = (bundle != nil);
                done();
            }];
        });
        expect(loadedBundle).to.beTruthy();
    });

    it(@"can delete expired bundles", ^{
        launchKit.apiClient.cachedBundleVersion = @"2.0";
        waitUntil(^(DoneCallback done) {
            [launchKit.bundlesManager retrieveAndCacheAvailableRemoteBundlesWithAssociatedServerTimestamp:nil completion:^(NSError *error) {
                done();
            }];
        });
        LKBundleInfo *info = [launchKit.bundlesManager localBundleInfoWithName:@"WhatsNew"];
        expect(info).to.beNil();
    });

});

/*
describe(@"these will fail", ^{

    it(@"can do maths", ^{
        expect(1).to.equal(2);
    });

    it(@"can read", ^{
        expect(@"number").to.equal(@"string");
    });
    
    it(@"will wait and fail", ^AsyncBlock {
        
    });
});

describe(@"these will pass", ^{
    
    it(@"can do maths", ^{
        expect(1).beLessThan(23);
    });
    
    it(@"can read", ^{
        expect(@"team").toNot.contain(@"I");
    });
    
    it(@"will wait and succeed", ^AsyncBlock {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            done();
        });
    });
});
*/

SpecEnd
