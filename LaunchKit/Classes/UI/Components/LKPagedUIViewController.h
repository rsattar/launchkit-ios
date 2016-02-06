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

// A single string, with static titles separated by '@@'
@property (strong, nonatomic) IBInspectable NSString *staticButtonTitlesString;
// A single string, with bundled image names separated by '@@'
@property (strong, nonatomic) IBInspectable NSString *fixedBackgroundImageNamesString;

@end
