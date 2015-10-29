//
//  LKConfig.h
//  LaunchKit
//
//  Created by Rizwan Sattar on 8/21/15.
//
//

#import <Foundation/Foundation.h>

extern NSString *const __nonnull LKConfigUpdatedNotificationName;
extern NSString *const __nonnull LKConfigOldParametersKey;
extern NSString *const __nonnull LKConfigNewParametersKey;

@interface LKConfig : NSObject

/**
 * The parameters dictionary, directly accessible, if needed.
 */
@property (readonly, strong, nonatomic, nonnull) NSDictionary *parameters;

- (nonnull instancetype)initWithParameters:(nullable NSDictionary *)configParameters;

#pragma mark - Casted getters
- (BOOL) boolForKey:(NSString * __nonnull)key defaultValue:(BOOL)defaultValue;
- (NSInteger) integerForKey:(NSString * __nonnull)key defaultValue:(NSInteger)defaultValue;
- (double) doubleForKey:(NSString * __nonnull)key defaultValue:(double)defaultValue;
- (nullable NSString *) stringForKey:(NSString * __nonnull)key defaultValue:(nullable NSString *)defaultValue;

@end
