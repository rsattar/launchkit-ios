//
//  UIView+LKAdditions.h
//  Pods
//
//  Created by Rizwan Sattar on 8/10/15.
//
//

#import <UIKit/UIKit.h>

@interface UIView (LKAdditions)

#if LK_IB_DESIGNABLE
@property (assign, nonatomic) IBInspectable CGFloat lk_cornerRadius;
#endif

@end
