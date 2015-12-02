//
//  UIView+LKAdditions.m
//  LaunchKit
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

- (CGFloat)lk_borderWidth
{
    if ([self.layer respondsToSelector:@selector(borderWidth)]) {
        return [self.layer borderWidth];
    }
    return 0.0;
}

- (void)setLk_borderWidth:(CGFloat)lk_borderWidth
{
    if ([self.layer respondsToSelector:@selector(setBorderWidth:)]) {
        self.layer.borderWidth = lk_borderWidth;
    }
}

- (UIColor *)lk_borderColor
{
    if ([self.layer respondsToSelector:@selector(borderColor)]) {
        CGColorRef borderColorRef = self.layer.borderColor;
        if (borderColorRef != NULL) {
            return [UIColor colorWithCGColor:borderColorRef];
        }
    }
    return nil;
}

- (void)setLk_borderColor:(UIColor *)lk_borderColor
{
    if ([self.layer respondsToSelector:@selector(setBorderColor:)]) {
        self.layer.borderColor = lk_borderColor.CGColor;
    }
}



@end
