//
//  LaunchKitShared.h
//  LaunchKit
//
//  Created by Rizwan Sattar on 6/19/15.
//
//

#ifndef LaunchKitShared_h
#define LaunchKitShared_h

#import <UIKit/UIKit.h>

#import "LKViewController.h"

typedef void (^LKRemoteUILoadHandler)(LKViewController *__nullable viewController, NSError *__nullable error);
typedef void (^LKRemoteUIDismissalHandler)(LKViewControllerFlowResult flowResult);

#endif
