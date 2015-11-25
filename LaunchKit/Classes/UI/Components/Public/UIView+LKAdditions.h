//
//  UIView+LKAdditions.h
//  LaunchKit
//
//  Created by Rizwan Sattar on 8/10/15.
//
//

#import <UIKit/UIKit.h>

@interface UIView (LKAdditions)

@property (assign, nonatomic) CGFloat lk_cornerRadius;
@property (assign, nonatomic) CGFloat lk_borderWidth;
@property (strong, nonatomic, nullable) UIColor *lk_borderColor;

@end
