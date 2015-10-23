//
//  LKAPIClient.m
//  LaunchKit
//
//  Created by Cluster Labs, Inc. on 1/16/15.
//
//

#import "NSDictionary+LKFormEncoded.h"


NSString *lk_EncodedValueForObject(NSObject *object) {
    if (![object isKindOfClass:[NSNull class]]) {
        return [[object description] lk_urlencoded];
    }
    return @"";
}


@implementation NSDictionary (LKFormEncoded)


- (NSString*)lk_toFormEncodedString
{  
    NSMutableArray *array = [NSMutableArray array];
  
    for (NSObject *key in self) {
        NSObject *value = [self objectForKey:key];

        NSString *encodedKey = [[key description] lk_urlencoded];
        if ([value isKindOfClass:[NSArray class]]) {
            for (NSObject *multiValue in (NSArray*)value) {
                [array addObject:[NSString stringWithFormat:@"%@=%@", encodedKey, lk_EncodedValueForObject(multiValue)]];
            }
        } else {
            [array addObject:[NSString stringWithFormat:@"%@=%@", encodedKey, lk_EncodedValueForObject(value)]];
        }
    }

    return [array componentsJoinedByString:@"&"];
}


@end
