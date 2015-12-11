//
//  LKCardPresentationController.m
//  LaunchKitRemoteUIBuilding
//
//  Created by Rizwan Sattar on 7/31/15.
//  Copyright (c) 2015 Cluster Labs, Inc. All rights reserved.
//

#import "LKCardPresentationController.h"

#import "LKViewController.h"

@interface LKCardPresentationController ()

@property (strong, nonatomic) UIView *dimmingView;
@property (strong, nonatomic) UIButton *clearDismissButton;

@property (assign, nonatomic) CGFloat lkViewStartingCornerRadius;

@end

@implementation LKCardPresentationController

- (instancetype)initWithPresentedViewController:(UIViewController *)presentedViewController presentingViewController:(UIViewController *)presentingViewController
{
    self = [super initWithPresentedViewController:presentedViewController presentingViewController:presentingViewController];
    if (self) {
        // NOTE(Riz): Is it safe to query the presentedViewController's .view here?
    }
    return self;
}

- (void)presentationTransitionWillBegin {
    [super presentationTransitionWillBegin];
    UIView *roundView = self.presentedViewController.view;
    // For some reason, even if it's set in IB, the main VC's view's clipToBounds is
    // sometimes set back to YES; need to change that to support corners + shadows
    UIView *containingView = roundView;
    if ([self.presentedViewController isKindOfClass:[LKViewController class]]) {
        // cardView is often the same as view, but in some cases (complex
        // shadow + rounded corner situation), it's not
        roundView = ((LKViewController *)self.presentedViewController).cardView;
    }
    self.lkViewStartingCornerRadius = roundView.layer.cornerRadius;
    // This is in case we are about to present the very first time, we need to remove any corner radius that might be
    // set (usually through a LaunchKit remote UI storyboard :))
    if ([self shouldPresentInFullscreen]) {
        roundView.layer.cornerRadius = 0.0;
        containingView.clipsToBounds = YES;
    } else {
        containingView.clipsToBounds = NO;
    }

    self.dimmingView = [[UIView alloc] initWithFrame:CGRectZero];
    self.dimmingView.backgroundColor = [UIColor blackColor];
    self.dimmingView.alpha = 0.4;
    [self.containerView addSubview:self.dimmingView];
    self.dimmingView.frame = self.containerView.bounds;
    self.dimmingView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    self.clearDismissButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.clearDismissButton addTarget:self action:@selector(onClearDismissButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    self.clearDismissButton.backgroundColor = [UIColor clearColor];
    [self.containerView addSubview:self.clearDismissButton];
    self.clearDismissButton.frame = self.containerView.bounds;
    self.clearDismissButton.autoresizingMask = self.dimmingView.autoresizingMask;

    id<UIViewControllerTransitionCoordinator> transitionCoordinator = self.presentingViewController.transitionCoordinator;
    self.dimmingView.alpha = 0.0;
    [transitionCoordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        self.dimmingView.alpha = 0.4;
    } completion:nil];
}

- (void)presentationTransitionDidEnd:(BOOL)completed {
    [super presentationTransitionDidEnd:completed];
    // Remove dimming view if presentation failed for whatever reason
    if (!completed) {
        [self.dimmingView removeFromSuperview];
        self.dimmingView = nil;
    }
}

- (void)dismissalTransitionWillBegin {
    [super dismissalTransitionWillBegin];
    id<UIViewControllerTransitionCoordinator> transitionCoordinator = self.presentingViewController.transitionCoordinator;
    [transitionCoordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        self.dimmingView.alpha = 0.0;
    } completion:nil];
}

- (void)dismissalTransitionDidEnd:(BOOL)completed {
    [super dismissalTransitionDidEnd:completed];
    if (completed) {
        [self.dimmingView removeFromSuperview];
        self.dimmingView = nil;
    }
}

- (BOOL)isSmallerPhone:(CGRect)windowBounds
{
    CGFloat longDimension = MAX(CGRectGetWidth(windowBounds), CGRectGetHeight(windowBounds));
    if (longDimension <= 568.0) {
        return YES;
    }
    return NO;
}

- (BOOL)shouldPresentInFullscreen
{
    CGRect windowBounds = [UIApplication sharedApplication].keyWindow.bounds;
    return [self isSmallerPhone:windowBounds];
}

- (BOOL)shouldPresentInFullscreenForSize:(CGSize)size
{
    CGRect simulatedWindowBounds = CGRectMake(0, 0, size.width, size.height);
    return [self isSmallerPhone:simulatedWindowBounds];
}

- (CGRect)frameOfPresentedViewInContainerView {
    if ([self shouldPresentInFullscreen]) {
        return self.containerView.bounds;
    } else {
        CGRect bounds = self.containerView.bounds;
        CGRect maxRect = CGRectInset(bounds, 32.0, 64.0);
        // Make our largest dimension equal to what a typical
        // "form sheet" view size is.
        CGSize formSheetDimensions = CGSizeMake(540, 620);
        CGSize preferredSize = maxRect.size;
        if ([self.presentedViewController isKindOfClass:[LKViewController class]]) {
            LKViewController *presentedLKVC = (LKViewController *)self.presentedViewController;
            if (presentedLKVC.hasMeasureableSize) {
                // Measure the size fitting within our maxRect, but allowing height to be measured as close to zero
                // as possible (smallest height)
                CGSize measuredSize = [self.presentedViewController.view systemLayoutSizeFittingSize:CGSizeMake(maxRect.size.width, 0)
                                                                       withHorizontalFittingPriority:UILayoutPriorityRequired
                                                                             verticalFittingPriority:UILayoutPriorityDefaultHigh];
                preferredSize = CGSizeMake(MIN(maxRect.size.width, measuredSize.width),
                                           MIN(maxRect.size.height, measuredSize.height));
            }
        }
        if (self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular &&
            self.traitCollection.verticalSizeClass == UIUserInterfaceSizeClassRegular) {
            preferredSize = formSheetDimensions;
        } else if (CGRectGetWidth(bounds) == 375) {
            // Ugh, hardcoded for iPhone 6 size :(
            maxRect = bounds;
            preferredSize = CGSizeMake(320, 568);
        }
        // Pick the smallest of each dimension
        preferredSize.width = MIN(formSheetDimensions.width, MIN(preferredSize.width, CGRectGetWidth(maxRect)));
        preferredSize.height = MIN(formSheetDimensions.height, MIN(preferredSize.height, CGRectGetHeight(maxRect)));
        CGRect frame = CGRectMake(floor((CGRectGetWidth(bounds)-preferredSize.width)/2.0),
                                  floor((CGRectGetHeight(bounds)-preferredSize.height)/2.0),
                                  preferredSize.width,
                                  preferredSize.height);
        return frame;
    }
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];

    UIView *roundView = self.presentedViewController.view;
    UIView *containingView = roundView;
    // For some reason, even if it's set in IB, the main VC's view's clipToBounds is
    // sometimes set back to YES; need to change that to support corners + shadows
    if ([self.presentedViewController isKindOfClass:[LKViewController class]]) {
        // cardView is often the same as view, but in some cases (complex
        // shadow + rounded corner situation), it's not
        roundView = ((LKViewController *)self.presentedViewController).cardView;
    }
    if ([self shouldPresentInFullscreenForSize:size]) {
        roundView.layer.cornerRadius = 0.0;
        containingView.clipsToBounds = YES;
    } else {
        roundView.layer.cornerRadius = self.lkViewStartingCornerRadius;
        containingView.clipsToBounds = NO;
    }
}

- (void)containerViewWillLayoutSubviews
{
    [super containerViewWillLayoutSubviews];
    self.presentedView.frame = [self frameOfPresentedViewInContainerView];
}

#pragma mark - Clear Dismiss Button

- (void) onClearDismissButtonTapped:(UIButton *)sender
{
    if ([self.presentedViewController isKindOfClass:[LKViewController class]]) {
        [((LKViewController *)self.presentedViewController) finishFlowWithResult:LKViewControllerFlowResultCancelled userInfo:nil];
    } else {
        // NOTE: This doesn't make any callbacks to LKUIManager, in case LKUIManager is presenting this view controller.
        [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
    }
}

@end
