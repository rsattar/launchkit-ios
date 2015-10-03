//
//  UIView+LKAdditions.h
//  Pods
//
//  Created by Rizwan Sattar on 8/10/15.
//
//

#import <UIKit/UIKit.h>

@interface UIView (LKAdditions)

// Unfortunately, I don't want to #define all IBInspectable's to nothing
// so duplicate each property :-/
#if LK_IB_DESIGNABLE
@property (assign, nonatomic) IBInspectable CGFloat lk_cornerRadius;
#else
@property (assign, nonatomic) CGFloat lk_cornerRadius;
#endif

@end
