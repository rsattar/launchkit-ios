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
@property (readwrite, nonatomic) BOOL isReady;

// Define delegate internally here (LaunchKit.m will access via private extension)
@property (weak, nonatomic, nullable) id <LKConfigDelegate> delegate;

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
        self.isReady = NO;
    }
    return self;
}

- (NSDictionary *)dictionaryWithoutLaunchKitKeys:(nonnull NSDictionary *)dictionary
{
    NSMutableDictionary *strippedDict = [NSMutableDictionary dictionaryWithCapacity:dictionary.count];
    for (NSString *key in dictionary) {
        if ([key hasPrefix:@"io.launchkit."]) {
            continue;
        }
        strippedDict[key] = dictionary[key];
    }
    return strippedDict;
}

- (BOOL) updateParameters:(NSDictionary * __nullable)parameters
{
    if (parameters == nil) {
        parameters = self.parameters;
    }
    // Sanity check, in case we get a bad parameter (e.g. NSNull from bad JSON)
    if (![parameters isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    // Also first call ready-handler and refresh-handler the *first* time that
    // config is updated, whether or not it is actually different
    BOOL isFirstRefresh = !self.isReady;
    if (![parameters isEqualToDictionary:_parameters] || isFirstRefresh) {
        NSDictionary *oldParameters = self.parameters;
        self.parameters = [parameters copy];

        self.isReady = YES;

        // Fire ready handler if first refresh
        if (isFirstRefresh) {
            if ([self.delegate respondsToSelector:@selector(configIsReady:)]) {
                [self.delegate configIsReady:self];
            }
            if (self.readyHandler != nil) {
                self.readyHandler();
            }
        }

        NSDictionary *strippedOld = [self dictionaryWithoutLaunchKitKeys:oldParameters];
        NSDictionary *strippedNew = [self dictionaryWithoutLaunchKitKeys:parameters];
        BOOL appVisibleConfigsChanged = ![strippedOld isEqualToDictionary:strippedNew];
        if (appVisibleConfigsChanged) {
            [[NSNotificationCenter defaultCenter] postNotificationName:LKConfigUpdatedNotificationName
                                                                object:self
                                                              userInfo:@{LKConfigOldParametersKey: strippedOld,
                                                                         LKConfigNewParametersKey: strippedNew}];
        }
        // Fire config refresh handler (for both updates and isFirstRefresh)
        if (appVisibleConfigsChanged || isFirstRefresh) {
            if ([self.delegate respondsToSelector:@selector(configWasRefreshed:)]) {
                [self.delegate configWasRefreshed:self];
            }
            if (self.refreshHandler != nil) {
                self.refreshHandler(strippedOld, strippedNew);
            }
        }

        return YES;
    }
    return NO;
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

#pragma mark - Private Convenience Getters

- (nullable NSDate *) dateForKey:(NSString * __nonnull)key defaultValue:(nullable NSDate *)defaultValue
{
    NSTimeInterval timestamp = [self doubleForKey:key defaultValue:-1.0];
    if (timestamp >= 0.0) {
        return [NSDate dateWithTimeIntervalSince1970:timestamp];
    }
    return nil;
}

@end
