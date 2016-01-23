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
    }
    [self updatePageControls];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (void) updatePageControls
{
    UILayoutConstraintAxis axis = self.pagesStackView.axis;
    CGPoint contentOffset = self.scrollView.contentOffset;
    CGSize contentSize = self.scrollView.contentSize;
    CGFloat offset;
    CGFloat total;
    if (axis == UILayoutConstraintAxisHorizontal) {
        offset = contentOffset.x;
        total = contentSize.width;
    } else {
        offset = contentOffset.y;
        total = contentSize.height;
    }
    CGFloat pageSize = total / [self numberOfPages];
    CGFloat page = floor((double)offset/(double)pageSize);

    for (UIPageControl *pageControl in self.pageControls) {
        pageControl.currentPage = page;
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
