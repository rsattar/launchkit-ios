//
//  LKAPIClient.m
//  LaunchKit
//
//  Created by Cluster Labs, Inc. on 1/16/15.
//
//

#import "NSString+LKURLEncoded.h"

@implementation NSString (LKURLEncoded)

- (NSString*)lk_urlencoded
{
  NSString *result = (NSString *) CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)self, NULL, CFSTR(":/?#[]@!$&’()*+,;="), kCFStringEncodingUTF8));
  return result;
}

@end
