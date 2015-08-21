//
//  LKBundleInfo.h
//  Pods
//
//  Created by Rizwan Sattar on 7/24/15.
//
//

#import <Foundation/Foundation.h>

@interface LKBundleInfo : NSObject <NSCoding>

@property (readonly, nonatomic) NSDate *createTime;
@property (readonly, nonatomic) NSString *name;
@property (readonly, nonatomic) NSURL *url;
@property (readonly, nonatomic) NSString *version;

- (instancetype) initWithAPIDictionary:(NSDictionary *)dictionary;
- (instancetype) initWithName:(NSString *)name
                      version:(NSString *)version
                          url:(NSURL *)url
                   createTime:(NSDate *)date;

@end
