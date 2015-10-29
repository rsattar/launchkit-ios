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

NSString *const LAUNCHKIT_TEST_API_TOKEN = @"73UhwH5CXba6MZSSa9oynByf3_NtQjQlACPpenAhuGbf";

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
- (nonnull instancetype)initWithToken:(NSString *)apiToken;
- (void)archiveSession;
- (void)retrieveSessionFromArchiveIfAvailable;

@end

@interface LKConfig (TestingAdditions)

@property (readwrite, strong, nonatomic, nonnull) NSDictionary *parameters;
- (NSDictionary *)dictionaryWithoutLaunchKitKeys:(nonnull NSDictionary *)dictionary;

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
