//
//  LKImageView.h
//  LaunchKit
//
//  Created by Rizwan Sattar on 8/28/15.
//
//

#import <UIKit/UIKit.h>

@interface LKImageView : UIImageView

@property (assign, nonatomic) IBInspectable BOOL lk_templateAlways;
@property (assign, nonatomic) IBInspectable BOOL lk_heightConstrainedToAspectWidth;

@end
