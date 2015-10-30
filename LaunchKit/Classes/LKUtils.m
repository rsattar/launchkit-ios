//
//  LKUtils.m
//  Pods
//
//  Created by Rizwan Sattar on 10/28/15.
//
//

#import "LKUtils.h"

#import <UIKit/UIKit.h>

@implementation LKUtils

+ (CGSize) currentWindowSize
{
#if TARGET_OS_IOS || TARGET_OS_TV
    UIApplication *app = [UIApplication sharedApplication];
    UIWindow *window = app.keyWindow;
    CGSize windowSize = window.bounds.size;
#if !TARGET_OS_TV
    if (![UIScreen instancesRespondToSelector:@selector(fixedCoordinateSpace)]) {
        // iOS 7 and below always show the windowSize in "portrait-up" dimensions
        // Use status bar orientation to determine if we should report a different
        // window size
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
        UIInterfaceOrientation orientation = app.statusBarOrientation;
#pragma GCC diagnostic pop

        if (UIInterfaceOrientationIsLandscape(orientation)) {
            // Swap the dimensions
            windowSize = CGSizeMake(windowSize.height, windowSize.width);
        }

    }
#endif // !TARGET_OS_TV
    return windowSize;
#else
    return CGSizeZero
#endif // TARGET_OS_IOS || TARGET_OS_TV
}

@end
