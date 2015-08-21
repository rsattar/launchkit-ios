//
//  LKButton.m
//  LaunchKitRemoteUITest
//
//  Created by Rizwan Sattar on 6/17/15.
//  Copyright (c) 2015 Cluster Labs, Inc. All rights reserved.
//

#import "LKButton.h"

@implementation LKButton

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

- (void) commonInit
{
    [self addTarget:self action:@selector(touchedUpInside:) forControlEvents:UIControlEventTouchUpInside];
}

- (instancetype) init
{
    self = [super init];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void) touchedUpInside:(id)sender
{
    if (self.openURL.length > 0) {
        NSURL *url = [NSURL URLWithString:self.openURL];
        if ([[UIApplication sharedApplication] canOpenURL:url]) {
            [[UIApplication sharedApplication] openURL:url];
        } else {
            url = [NSURL URLWithString:@"https://launchkit.io/"];
            [[UIApplication sharedApplication] openURL:url];
        }
    }
}


@end
