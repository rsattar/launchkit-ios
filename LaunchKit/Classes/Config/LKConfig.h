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

@end
