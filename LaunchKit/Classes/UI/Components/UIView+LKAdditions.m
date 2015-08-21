//
//  UIView+LKAdditions.m
//  Pods
//
//  Created by Rizwan Sattar on 8/10/15.
//
//

#import "UIView+LKAdditions.h"

@implementation UIView (LKAdditions)

- (CGFloat)lk_cornerRadius
{
    if ([self.layer respondsToSelector:@selector(cornerRadius)]) {
        return [self.layer cornerRadius];
    }
    return 0.0;
}

- (void) setLk_cornerRadius:(CGFloat)lk_cornerRadius
{
    if ([self.layer respondsToSelector:@selector(setCornerRadius:)]) {
        self.layer.cornerRadius = lk_cornerRadius;
    }
}

@end
