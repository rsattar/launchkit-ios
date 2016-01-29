//
//  LKGradientView.h
//  Pods
//
//  Created by Rizwan Sattar on 1/28/16.
//
//

#import <UIKit/UIKit.h>

IB_DESIGNABLE
@interface LKGradientView : UIView

@property (strong, nonatomic) IBInspectable UIColor *gradientColor1;
@property (strong, nonatomic) IBInspectable UIColor *gradientColor2;
@property (assign, nonatomic) IBInspectable CGFloat angleDegrees;

@end
