//
//  UIView+LKAdditions.h
//  LaunchKit
//
//  Created by Rizwan Sattar on 8/10/15.
//
//

#import <UIKit/UIKit.h>

@interface UIView (LKAdditions)

@property (assign, nonatomic) IBInspectable CGFloat lk_cornerRadius;
@property (assign, nonatomic) IBInspectable CGFloat lk_borderWidth;
@property (strong, nonatomic, nullable) IBInspectable UIColor *lk_borderColor;

@end
