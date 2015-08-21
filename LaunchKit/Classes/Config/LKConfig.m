//
//  LKConfig.m
//  LaunchKit
//
//  Created by Rizwan Sattar on 8/21/15.
//
//

#import "LKConfig.h"

#import "LKLog.h"

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
    } else if (value != nil) {
        LKLogWarning(@"LKConfig returned value for '%@' is %@, not a BOOL. Returning default: %d",
                     key,
                     NSStringFromClass([value class]),
                     defaultValue);
    }
    return defaultValue;
}

- (NSInteger) integerForKey:(NSString * __nonnull)key defaultValue:(NSInteger)defaultValue
{
    id value = self.parameters[key];
    if ([value isKindOfClass:[NSNumber class]]) {
        return ((NSNumber *)value).integerValue;
    } else if (value != nil) {
        LKLogWarning(@"LKConfig returned value for '%@' is %@, not an NSInteger. Returning default: %ld",
                     key,
                     NSStringFromClass([value class]),
                     (long)defaultValue);
    }
    return defaultValue;
}

- (double) doubleForKey:(NSString * __nonnull)key defaultValue:(double)defaultValue
{
    id value = self.parameters[key];
    if ([value isKindOfClass:[NSNumber class]]) {
        return ((NSNumber *)value).doubleValue;
    } else if (value != nil) {
        LKLogWarning(@"LKConfig returned value for '%@' is %@, not a double. Returning default: %@",
                     key,
                     NSStringFromClass([value class]),
                     [NSNumber numberWithDouble:defaultValue]);
    }
    return defaultValue;
}

- (nullable NSString *) stringForKey:(NSString * __nonnull)key defaultValue:(nullable NSString *)defaultValue
{
    id value = self.parameters[key];
    if ([value isKindOfClass:[NSString class]]) {
        return (NSString *)value;
    } else if (value != nil) {
        LKLogWarning(@"LKConfig returned value for '%@' is %@, not an NSString. Returning default: %@",
                     key,
                     NSStringFromClass([value class]),
                     defaultValue);
    }
    return defaultValue;
}

@end
