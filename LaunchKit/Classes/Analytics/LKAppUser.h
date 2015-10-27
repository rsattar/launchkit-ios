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

@property (readonly, retain, nonatomic, nullable) NSString *email;
@property (readonly, retain, nonatomic) NSDate *firstVisit;
@property (readonly, retain, nonatomic) NSArray *labels;
@property (readonly, retain, nonatomic, nullable) NSString *name;
@property (readonly, retain, nonatomic) LKAppUserStat *stats;
@property (readonly, retain, nonatomic, nullable) NSString *uniqueId;

- (instancetype)initWithDictionary:(NSDictionary *)dictionary;

@end

NS_ASSUME_NONNULL_END