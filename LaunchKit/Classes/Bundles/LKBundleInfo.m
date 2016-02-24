//
//  LKBundleInfo.m
//  LaunchKit
//
//  Created by Rizwan Sattar on 7/24/15.
//
//

#import "LKBundleInfo.h"

@interface LKBundleInfo ()

@property (strong, nonatomic) NSDate *createTime;
@property (strong, nonatomic) NSString *name;
@property (strong, nonatomic) NSURL *url;
@property (strong, nonatomic) NSString *version;

// Locally synthesized version
@property (readwrite, assign, nonatomic) LKResourceVersion resourceVersion;

@end

@implementation LKBundleInfo

- (instancetype) initWithAPIDictionary:(NSDictionary *)dictionary
{
    self = [super init];
    if (self) {
        NSTimeInterval rawCreateTime = [dictionary[@"createTime"] doubleValue];
        self.createTime = [NSDate dateWithTimeIntervalSince1970:rawCreateTime];
        self.name = dictionary[@"name"];
        NSString *urlString = dictionary[@"url"];
        self.url = [NSURL URLWithString:urlString];
        self.version = dictionary[@"version"];
        self.resourceVersion = LKResourceVersionNewest;
    }
    return self;
}

- (instancetype) initWithName:(NSString *)name
                      version:(NSString *)version
                          url:(NSURL *)url
                   createTime:(NSDate *)date
              resourceVersion:(LKResourceVersion)resourceVersion;
{
    self = [super init];
    if (self) {
        self.name = name;
        self.version = version;
        self.url = url;
        self.createTime = date;
        self.resourceVersion = resourceVersion;
    }
    return self;
}

- (instancetype) initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self) {
        self.createTime = [aDecoder decodeObjectForKey:@"createTime"];
        self.name = [aDecoder decodeObjectForKey:@"name"];
        self.url = [aDecoder decodeObjectForKey:@"url"];
        self.version = [aDecoder decodeObjectForKey:@"version"];
        self.resourceVersion = [aDecoder decodeIntegerForKey:@"resourceVersion"];
    }
    return self;
}

- (void) encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:self.createTime forKey:@"createTime"];
    [aCoder encodeObject:self.name forKey:@"name"];
    [aCoder encodeObject:self.url forKey:@"url"];
    [aCoder encodeObject:self.version forKey:@"version"];
    [aCoder encodeInteger:self.resourceVersion forKey:@"resourceVersion"];
}

- (id)copyWithZone:(nullable NSZone *)zone
{
    LKBundleInfo *copy = [[[self class] allocWithZone:zone] initWithName:[self.name copy]
                                                                 version:[self.version copy]
                                                                     url:[self.url copy]
                                                              createTime:[self.createTime copy]
                                                         resourceVersion:self.resourceVersion];
    return copy;
}

- (void) markResourceVersionAsNewest
{
    self.resourceVersion = LKResourceVersionNewest;
}

@end
