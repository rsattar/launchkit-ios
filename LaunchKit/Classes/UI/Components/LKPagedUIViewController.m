//
//  LKPagedUIViewController.m
//  Pods
//
//  Created by Rizwan Sattar on 1/22/16.
//
//

#import "LKPagedUIViewController.h"

#import "LKSimpleStackView.h"

@interface LKPagedUIViewController ()

@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
@property (weak, nonatomic) IBOutlet LKSimpleStackView *pagesStackView;
@property (weak, nonatomic) IBOutlet UIButton *skipButton;
@property (strong, nonatomic) IBOutletCollection(UIPageControl) NSArray *pageControls;

#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_9_0
@property (assign, nonatomic) NSInteger iOS7_pageBeforeRotation;
#endif
@end

@implementation LKPagedUIViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    BOOL isPad = [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad;
    if (isPad) {
        return UIInterfaceOrientationMaskAll;
    } else {
        return UIInterfaceOrientationMaskPortrait;
    }
}

- (NSUInteger)numberOfPages
{
    NSUInteger numberOfPages = 0;
    for (UIView *subview in self.pagesStackView.arrangedSubviews) {
        if (!subview.hidden) {
            numberOfPages++;
        }
    }
    return numberOfPages;
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    NSUInteger numberOfPages = [self numberOfPages];
    for (UIPageControl *pageControl in self.pageControls) {
        pageControl.numberOfPages = numberOfPages;
        // Also hide if there's only 1 page
        // NOTE: We don't unhide here, because there are number of
        // page controls that are hidden by default. This just hides
        // any page control if it's NOT hidden and there's only 1 page
        if (numberOfPages <= 1) {
            pageControl.hidden = YES;
        }
    }
    [self updatePageControls];
}

// iOS 7 code, works in iOS 8. However if this is built with
// a deployment target of iOS 9 and up, this code will not be
// called
#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_9_0
- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    self.iOS7_pageBeforeRotation = [self currentPage];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    CGFloat sizePerPage = [self singlePageSize];
    CGFloat offsetAmount = sizePerPage * self.iOS7_pageBeforeRotation;
    CGPoint contentOffset = self.scrollView.contentOffset;
    UILayoutConstraintAxis axis = self.pagesStackView.axis;
    if (axis == UILayoutConstraintAxisHorizontal) {
        contentOffset.x = offsetAmount;
    } else {
        contentOffset.y = offsetAmount;
    }
    [UIView animateWithDuration:duration animations:^{
        [self.scrollView setContentOffset:contentOffset animated:YES];
    }];
}
#endif

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    // Our iOS 9+ the interface orientation work will be be called, so we must handle the rotation of the UI here
    NSOperatingSystemVersion iOS9 = {9,0,0};
    if ([[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:iOS9]) {

        NSInteger currentPage = [self currentPage];
        [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
            // Page size will be accurate for current orientation here
            CGFloat sizePerPage = [self singlePageSize];
            CGFloat offsetAmount = sizePerPage * currentPage;
            CGPoint contentOffset = self.scrollView.contentOffset;
            UILayoutConstraintAxis axis = self.pagesStackView.axis;
            if (axis == UILayoutConstraintAxisHorizontal) {
                contentOffset.x = offsetAmount;
            } else {
                contentOffset.y = offsetAmount;
            }
            [self.scrollView setContentOffset:contentOffset animated:YES];
        } completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
            
        }];
    }
}

#pragma mark - Paging measurements

- (CGFloat) currentScrollOffset
{
    UILayoutConstraintAxis axis = self.pagesStackView.axis;
    CGPoint contentOffset = self.scrollView.contentOffset;
    CGFloat offset;
    if (axis == UILayoutConstraintAxisHorizontal) {
        offset = contentOffset.x;
    } else {
        offset = contentOffset.y;
    }
    return offset;
}

- (CGFloat) totalContentSize
{
    UILayoutConstraintAxis axis = self.pagesStackView.axis;
    CGSize contentSize = self.scrollView.contentSize;
    CGFloat total;
    if (axis == UILayoutConstraintAxisHorizontal) {
        total = contentSize.width;
    } else {
        total = contentSize.height;
    }
    return total;
}

- (CGFloat) singlePageSize
{
    CGFloat total = [self totalContentSize];
    CGFloat pageSize = total / [self numberOfPages];
    return pageSize;
}

- (NSInteger) currentPage
{
    CGFloat offset = [self currentScrollOffset];
    CGFloat pageSize = [self singlePageSize];
    CGFloat page = floor((double)offset/(double)pageSize);
    return (NSInteger)page;
}

#pragma mark - Navigation
/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/
- (IBAction)moveToNextOnboardingPage:(UIStoryboardSegue *)segue
{
    if ([self currentPage] == [self numberOfPages] - 1) {
        [self finishFlowWithResult:LKViewControllerFlowResultCompleted userInfo:nil];
    } else {
        [self scrollToNextPageAnimated:YES];
    }
}

- (void) scrollToNextPageAnimated:(BOOL)animated
{
    CGFloat offsetInAxis = [self currentScrollOffset];
    offsetInAxis += [self singlePageSize];

    UILayoutConstraintAxis axis = self.pagesStackView.axis;
    CGPoint contentOffset = self.scrollView.contentOffset;
    if (axis == UILayoutConstraintAxisHorizontal) {
        contentOffset.x = offsetInAxis;
    } else {
        contentOffset.y = offsetInAxis;
    }
    [self.scrollView setContentOffset:contentOffset animated:animated];
}

#pragma mark - Page Controls
- (void) updatePageControls
{

    for (UIPageControl *pageControl in self.pageControls) {
        pageControl.currentPage = [self currentPage];
    }
}

- (void) scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    [self updatePageControls];
}

- (void) scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (!decelerate) {
        [self updatePageControls];
    }
}

- (void) scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
    [self updatePageControls];
}

@end
