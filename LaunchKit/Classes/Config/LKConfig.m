//
//  LKConfig.m
//  LaunchKit
//
//  Created by Rizwan Sattar on 8/21/15.
//
//

#import "LKConfig.h"

NSString *const LKConfigUpdatedNotificationName = @"LKConfigUpdatedNotificationName";
NSString *const LKConfigOldParametersKey = @"LKConfigOldParametersKey";
NSString *const LKConfigNewParametersKey = @"LKConfigNewParametersKey";

@interface LKConfig ()

@property (readwrite, strong, nonatomic, nonnull) NSDictionary *parameters;

@end

@implementation LKConfig

- (instancetype)initWithParameters:(nullable NSDictionary *)configParameters
{
    self = [super init];
    if (self) {
        if (configParameters != nil) {
            _parameters = [configParameters copy];
        } else {
            _parameters = @{};
        }
    }
    return self;
}

- (void) updateParameters:(NSDictionary * __nonnull)parameters
{
    if (parameters == nil) {
        return;
    }
    if (![parameters isEqualToDictionary:_parameters]) {
        NSDictionary *oldParameters = self.parameters;
        self.parameters = [parameters copy];
        [[NSNotificationCenter defaultCenter] postNotificationName:LKConfigUpdatedNotificationName
                                                            object:self
                                                          userInfo:@{LKConfigOldParametersKey: oldParameters,
                                                                     LKConfigNewParametersKey: self.parameters}];
    }
}

- (BOOL) boolForKey:(NSString * __nonnull)key defaultValue:(BOOL)defaultValue
{
    id value = self.parameters[key];
    if ([value isKindOfClass:[NSNumber class]]) {
        return ((NSNumber *)value).boolValue;
    }
    return defaultValue;
}

- (NSInteger) integerForKey:(NSString * __nonnull)key defaultValue:(NSInteger)defaultValue
{
    id value = self.parameters[key];
    if ([value isKindOfClass:[NSNumber class]]) {
        return ((NSNumber *)value).integerValue;
    }
    return defaultValue;
}

- (double) doubleForKey:(NSString * __nonnull)key defaultValue:(double)defaultValue
{
    id value = self.parameters[key];
    if ([value isKindOfClass:[NSNumber class]]) {
        return ((NSNumber *)value).doubleValue;
    }
    return defaultValue;
}

- (nullable NSString *) stringForKey:(NSString * __nonnull)key defaultValue:(nullable NSString *)defaultValue
{
    id value = self.parameters[key];
    if ([value isKindOfClass:[NSString class]]) {
        return (NSString *)value;
    }
    return defaultValue;
}

@end
