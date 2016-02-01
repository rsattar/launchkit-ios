//
//  LKPageControl.m
//  Pods
//
//  Created by Rizwan Sattar on 1/29/16.
//
//

#import "LKPageControl.h"

@implementation LKPageControl

- (void) setVertical:(BOOL)vertical
{
    if (_vertical == vertical) {
        return;
    }
    _vertical = vertical;
    if (_vertical) {
        self.transform = CGAffineTransformMakeRotation(M_PI / 2.0);
    } else {
        self.transform = CGAffineTransformIdentity;
    }
    [self setNeedsDisplay];
}

- (CGSize) intrinsicContentSize
{
    CGSize normalSize = [super intrinsicContentSize];
    if (_vertical) {
        return CGSizeMake(normalSize.height, normalSize.width);
    }
    return normalSize;
}

@end
