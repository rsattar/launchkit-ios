//
//  LKBundleInfo.h
//  LaunchKit
//
//  Created by Rizwan Sattar on 7/24/15.
//
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, LKResourceVersion) {
    LKResourceVersionInvalid,
    LKResourceVersionNewest,
    LKResourceVersionLocalCache,
    LKResourceVersionPrepackaged,
};

@interface LKBundleInfo : NSObject <NSCoding, NSCopying>

@property (readonly, nonatomic) NSDate *createTime;
@property (readonly, nonatomic) NSString *name;
@property (readonly, nonatomic) NSURL *url;
@property (readonly, nonatomic) NSString *version;

// Locally synthesized version
@property (readonly, nonatomic) LKResourceVersion resourceVersion;

- (instancetype) initWithAPIDictionary:(NSDictionary *)dictionary;
- (instancetype) initWithName:(NSString *)name
                      version:(NSString *)version
                          url:(NSURL *)url
                   createTime:(NSDate *)date
              resourceVersion:(LKResourceVersion)resourceVersion;

@end
