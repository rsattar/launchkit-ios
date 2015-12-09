//
//  LKTrackOperation.m
//  LaunchKit
//
//  Created by Rizwan Sattar on 12/8/15.
//
//

#import "LKTrackOperation.h"

@interface LKTrackOperation ()

@property (strong, nonatomic, nullable) NSDictionary *response;
@property (strong, nonatomic, nullable) NSError *error;
@property (strong, nonatomic, nonnull) LKAPIClient *apiClient;

@property (assign, nonatomic) BOOL requestInProgress;
@property (assign, nonatomic) BOOL requestFinished;

@end

@implementation LKTrackOperation

- (nonnull instancetype)initWithAPIClient:(nonnull LKAPIClient *)apiClient propertiesToTrack:(nullable NSDictionary *)properties
{
    self = [super init];
    if (self) {
        _apiClient = apiClient;
        _properties = properties;
    }
    return self;
}

- (BOOL)isConcurrent
{
    return YES;
}

- (void)start
{
    if (self.isCancelled) {
        // Move immediately to finished
        [self willChangeValueForKey:@"isFinished"];
        self.requestFinished = YES;
        [self didChangeValueForKey:@"isFinished"];
        return;
    }

    self.requestInProgress = NO;
    self.requestFinished = NO;
    self.response = nil;
    self.error = nil;

    // According to Apple Docs, this is how to start the main method execution
    // See: https://developer.apple.com/library/ios/documentation/General/Conceptual/ConcurrencyProgrammingGuide/OperationObjects/OperationObjects.html#//apple_ref/doc/uid/TP40008091-CH101-SW8
    [NSThread detachNewThreadSelector:@selector(main) toTarget:self withObject:nil];
}

- (void)main
{
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    self.requestInProgress = YES;
    self.requestFinished = NO;
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];

    [self.apiClient trackProperties:self.properties withSuccessBlock:^(NSDictionary *responseDict) {
        self.response = responseDict;
        [self completeOperation];
    } errorBlock:^(NSError *error) {
        self.error = error;
        [self completeOperation];
    }];
}

- (void)completeOperation
{
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];

    self.requestInProgress = NO;
    self.requestFinished = YES;

    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}

- (BOOL)isExecuting
{
    return self.requestInProgress;
}

- (BOOL)isFinished
{
    return self.requestFinished;
}

@end
