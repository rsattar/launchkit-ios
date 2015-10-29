//
//  LKAppUser.m
//  LaunchKit
//
//  Created by Rizwan Sattar on 10/26/15.
//
//

#import "LKAppUser.h"

@interface LKAppUserStat ()

// Definition of readonly properties
@property (assign, nonatomic) NSInteger days;
@property (assign, nonatomic) NSInteger visits;

@end

@implementation LKAppUserStat

- (instancetype)initWithDictionary:(NSDictionary *)dictionary
{
    self = [super init];
    if (self) {
        if ([dictionary[@"days"] isKindOfClass:[NSNumber class]]) {
            self.days = [dictionary[@"days"] integerValue];
        }
        if ([dictionary[@"visits"] isKindOfClass:[NSNumber class]]) {
            self.visits = [dictionary[@"visits"] integerValue];
        }
    }
    return self;
}

@end

static NSString *const LKAppUserLabelSuper = @"super";

@interface LKAppUser ()

// Definition of readonly properties
@property (strong, nonatomic) NSString *email;
@property (strong, nonatomic) NSDate *firstVisit;
@property (strong, nonatomic) NSSet *labels;
@property (strong, nonatomic) NSString *name;
@property (strong, nonatomic) LKAppUserStat *stats;
@property (strong, nonatomic) NSString *uniqueId;

@end

@implementation LKAppUser


- (instancetype)initWithDictionary:(NSDictionary *)dictionary
{
    self = [super init];
    if (self) {
        if ([dictionary[@"email"] isKindOfClass:[NSString class]]) {
            self.email = dictionary[@"email"];
        }
        if ([dictionary[@"firstVisit"] isKindOfClass:[NSNumber class]]) {
            self.firstVisit = [NSDate dateWithTimeIntervalSince1970:[dictionary[@"firstVisit"] doubleValue]];
        } else {
            self.firstVisit = [NSDate date];
        }
        if ([dictionary[@"labels"] isKindOfClass:[NSArray class]]) {
            self.labels = [NSSet setWithArray:dictionary[@"labels"]];
        } else {
            self.labels = [NSSet set];
        }
        if ([dictionary[@"name"] isKindOfClass:[NSString class]]) {
            self.name = dictionary[@"name"];
        }
        if ([dictionary[@"stats"] isKindOfClass:[NSDictionary class]]) {
            self.stats = [[LKAppUserStat alloc] initWithDictionary:dictionary[@"stats"]];
        } else {
            self.stats = [[LKAppUserStat alloc] init];
        }
        if ([dictionary[@"uniqueId"] isKindOfClass:[NSString class]]) {
            self.uniqueId = dictionary[@"uniqueId"];
        }
    }
    return self;
}

- (BOOL)isSuper
{
    return [self.labels member:LKAppUserLabelSuper] != nil;
}


@end
