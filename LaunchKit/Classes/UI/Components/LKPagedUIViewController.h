//
//  LKPagedUIViewController.h
//  Pods
//
//  Created by Rizwan Sattar on 1/22/16.
//
//

#import <UIKit/UIKit.h>

#import "LKViewController.h"

@interface LKPagedUIViewController : LKViewController <UIScrollViewDelegate>

// A single string, with static titles represented as JSON
@property (strong, nonatomic) IBInspectable NSString *staticButtonTitlesString;
// A single string, with bundled image names represented as JSON
@property (strong, nonatomic) IBInspectable NSString *fixedBackgroundImageNamesString;

@end
