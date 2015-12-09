//
//  LKTrackOperation.h
//  LaunchKit
//
//  Created by Rizwan Sattar on 12/8/15.
//
//

#import <Foundation/Foundation.h>

#import "LKAPIClient.h"

@interface LKTrackOperation : NSOperation

@property (readonly, nonatomic, nullable) NSDictionary *properties;
@property (readonly, nonatomic, nullable) NSDictionary *response;
@property (readonly, nonatomic, nullable) NSError *error;

- (nonnull instancetype)initWithAPIClient:(nonnull LKAPIClient *)apiClient propertiesToTrack:(nullable NSDictionary *)properties;

@end
