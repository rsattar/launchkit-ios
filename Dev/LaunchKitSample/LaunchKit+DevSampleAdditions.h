//
//  LaunchKit+DevSampleAdditions.h
//  LaunchKitSample
//
//  Created by Rizwan Sattar on 8/25/15.
//  Copyright (c) 2015 Cluster Labs, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <LaunchKit/LaunchKit.h>

@interface LaunchKit (DevSampleAdditions)

@property (copy, nonatomic) NSString *apiToken;
/** Long-lived, persistent dictionary that is sent up with API requests. */
@property (copy, nonatomic) NSDictionary *sessionParameters;
//@property (strong, nonatomic) LKAPIClient *apiClient;
//@property (strong, nonatomic) NSTimer *trackingTimer;
@property (assign, nonatomic) NSTimeInterval trackingInterval;
//// Analytics
//@property (strong, nonatomic) LKAnalytics *analytics;
//// Config
//@property (readwrite, strong, nonatomic, nonnull) LKConfig *config;
//- (nonnull instancetype)initWithToken:(NSString *)apiToken;
//- (void)archiveSession;
//- (void)retrieveSessionFromArchiveIfAvailable;

@end
