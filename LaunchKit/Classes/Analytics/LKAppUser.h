//
//  LKAppUser.h
//  LaunchKit
//
//  Created by Rizwan Sattar on 10/26/15.
//
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LKAppUserStat : NSObject

@property (readonly, nonatomic) NSInteger days;
@property (readonly, nonatomic) NSInteger visits;

@end

@interface LKAppUser : NSObject

@property (readonly, strong, nonatomic, nullable) NSString *email;
@property (readonly, strong, nonatomic) NSDate *firstVisit;
@property (readonly, strong, nonatomic) NSSet *labels;
@property (readonly, strong, nonatomic, nullable) NSString *name;
@property (readonly, strong, nonatomic) LKAppUserStat *stats;
@property (readonly, strong, nonatomic, nullable) NSString *uniqueId;

- (instancetype)initWithDictionary:(NSDictionary *)dictionary;
- (BOOL)isSuper;

@end

NS_ASSUME_NONNULL_END