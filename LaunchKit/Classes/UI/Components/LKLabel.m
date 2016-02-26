//
//  LKLabel.m
//  Pods
//
//  Created by Rizwan Sattar on 2/26/16.
//
//

#import "LKLabel.h"

@implementation LKLabel

- (void) layoutSubviews
{
    if (self.lk_updatePreferredMaxLayoutWidthUponLayout) {
        self.preferredMaxLayoutWidth = CGRectGetWidth(self.bounds);
    }
    [super layoutSubviews];
}

@end
