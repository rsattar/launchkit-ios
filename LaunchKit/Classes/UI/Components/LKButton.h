//
//  LKButton.h
//  LaunchKitRemoteUITest
//
//  Created by Rizwan Sattar on 6/17/15.
//  Copyright (c) 2015 Cluster Labs, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "LKViewController.h"

// This class adds some useful methods and functionality that are needed to help define UI just from a storyboard
@interface LKButton : UIButton

@property (strong, nonatomic, nullable) IBInspectable UIColor *highlightedBackgroundColor;
@property (strong, nonatomic, nullable) IBInspectable NSString *openURL;

@end
