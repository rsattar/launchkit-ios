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
@end

@implementation LKPagedUIViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
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
        // Also hide/unhide if there's only 1 page
        pageControl.hidden = (numberOfPages <= 1);
    }
    [self updatePageControls];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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
