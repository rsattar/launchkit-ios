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
@property (weak, nonatomic) IBOutlet LKSimpleStackView *bottomStackView;
@property (weak, nonatomic) IBOutlet UIButton *staticContinueButton;

@property (strong, nonatomic) NSArray *staticButtonTitles;

@property (weak, nonatomic) IBOutlet UIImageView *fixedBackgroundImage1;
@property (weak, nonatomic) IBOutlet UIImageView *fixedBackgroundImage2;
@property (strong, nonatomic) NSArray *fixedBackgroundImageNames;
@property (strong, nonatomic) NSMutableDictionary *fixedImageCache;

@property (weak, nonatomic) IBOutlet UIImageView *scrollingBackgroundImage;
@property (strong, nonatomic) IBOutletCollection(NSLayoutConstraint) NSArray *scrollingBackgroundImageConstraints;
// Once our view loads, we will set this constraint to be the either top or left constraint
@property (strong, nonatomic) NSLayoutConstraint *scrollImageOffsetConstraint;

#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_9_0
@property (assign, nonatomic) NSInteger iOS7_pageBeforeRotation;
#endif
@end

@implementation LKPagedUIViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // If the static button isn't being used, make
    // the bottom stackview pass-through touches
    if (self.staticContinueButton &&
        (self.staticContinueButton.hidden || self.staticContinueButton.alpha == 0.0)) {
        self.bottomStackView.userInteractionEnabled = NO;
    }
    [self buildStaticButtonTitlesFromJSONString];
    [self buildFixedBackgroundImageNamesFromJSONString];
    [self prepareScrollingBackgroundImageConstraints];
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

- (nullable NSArray<NSString *> *) paddedArrayFromConfigurationJSONString:(NSString *)configString
{
    if (configString.length == 0) {
        return nil;
    }
    NSData *jsonData = [configString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *jsonParsingError = nil;
    id jsonObject = [NSJSONSerialization JSONObjectWithData:jsonData
                                                    options:NSJSONReadingMutableContainers
                                                      error:&jsonParsingError];
    if (jsonParsingError != nil || jsonObject == nil || ![jsonObject isKindOfClass:[NSMutableArray class]]) {
        return nil;
    }
    NSMutableArray<NSString *> *items = (NSMutableArray<NSString *> *)jsonObject;
    if (items.count == 0) {
        return nil;
    }
    // There may intentionally be *less* items than number of pages,
    // so fill-in from the front, if needed
    NSUInteger numPages = [self numberOfPages];
    if (items.count < numPages) {
        NSString *firstItem = items.firstObject;
        while (items.count < numPages) {
            [items insertObject:firstItem atIndex:0];
        }
    } else if (items.count > numPages) {
        // Remove titles from the front to match the size
        // The assumption here is that the *last* title is
        // generally the one we'll want for the last button
        // so adjust the remainder titles to allow that to happen
        NSUInteger difference = items.count - numPages;
        [items removeObjectsInRange:NSMakeRange(0, difference)];
    }
    return items;
}

#pragma mark - Static Button Titles

- (void) buildStaticButtonTitlesFromJSONString
{
    self.staticButtonTitles = [self paddedArrayFromConfigurationJSONString:self.staticButtonTitlesString];;
}

- (void) updateStaticButtonTitleForCurrentPage
{
    if (self.staticButtonTitles.count == 0) {
        return;
    }

    NSInteger index = [self currentPage];
    NSString *title = self.staticButtonTitles[index];
    [self.staticContinueButton setTitle:title forState:UIControlStateNormal];
}

#pragma mark - Fixed Background Images

- (void) buildFixedBackgroundImageNamesFromJSONString
{
    self.fixedBackgroundImageNames = [self paddedArrayFromConfigurationJSONString:self.fixedBackgroundImageNamesString];
}

- (void) updateFixedBackgroundImageForCurrentScroll
{
    CGFloat pageSize = [self singlePageSize];
    NSUInteger numPages = [self numberOfPages];
    NSInteger currentPage = [self currentPage];
    CGFloat offset = [self currentScrollOffset];
    if (offset < 0.0) {
        // Trying to rubber-band negative, skip
        return;
    }
    if ((currentPage + 1) >= numPages) {
        // Nothing to animate *to*, this is the last image
        return;
    }
    CGFloat currentPageOffset = pageSize * currentPage;
    // currentOffset should always be >= currentPageOffset
    CGFloat currentOffset = [self currentScrollOffset];
    CGFloat offsetDifference = currentOffset - currentPageOffset;
    if (offsetDifference == 0.0) {
        return;
    }

    UIImage *currentPageImage = [self fixedImageAtIndex:currentPage clampToPages:NO];
    self.fixedBackgroundImage1.image = currentPageImage;
    UIImage *nextImage = [self fixedImageAtIndex:currentPage+1 clampToPages:NO];
    self.fixedBackgroundImage2.image = nextImage;

    CGFloat percentageScrolledToNextPage = offsetDifference / pageSize;

    self.fixedBackgroundImage1.alpha = 1.0-percentageScrolledToNextPage;
    if (self.fixedBackgroundImage1.image == nil) {
        // Fading from nil image to a valid image, so fade it in
        self.fixedBackgroundImage2.alpha = percentageScrolledToNextPage;
    }
}

- (void) updateFixedBackgroundImageForCurrentPageAnimated:(BOOL)animated
{
    if (self.fixedBackgroundImageNames.count == 0) {
        return;
    }

    NSInteger index = [self currentPage];
    UIImage *image = [self fixedImageAtIndex:index clampToPages:YES];
    if (!animated) {
        self.fixedBackgroundImage1.image = image;
        // Ensure we are back at alpha 1.0, unless we are
        // dragging, in which case we're going to be updating our
        // alpha values in -updateFixedBackgroundImageForCurrentScroll
        if (!self.scrollView.isDragging) {
            self.fixedBackgroundImage1.alpha = 1.0;
        }
    } else {
        // Animate image1 to transparent, with image 2 behind,
        // then snap image2 to image1 (and make image 1 opaque)
        // Animate into image2, and fade image2 in over image1
        self.fixedBackgroundImage2.image = image; // ensure image2 is set
        [UIView animateWithDuration:0.35 animations:^{
            self.fixedBackgroundImage1.alpha = 0.0;
            // in case we were fading from a nil image
            self.fixedBackgroundImage2.alpha = 1.0;
        } completion:^(BOOL finished) {
            // Swap image into image1, hide image2
            self.fixedBackgroundImage1.image = image;
            self.fixedBackgroundImage2.image = nil;
            self.fixedBackgroundImage1.alpha = 1.0;
            self.fixedBackgroundImage2.alpha = 1.0;
        }];
    }
}

- (nullable UIImage *) fixedImageAtIndex:(NSInteger)index clampToPages:(BOOL)clampToPages
{
    if (self.fixedBackgroundImageNames.count == 0) {
        return nil;
    }
    NSUInteger numPages = [self numberOfPages];
    if (index < 0 || index >= numPages) {
        if (clampToPages) {
            index = MAX(0,MIN(index, numPages-1));
        } else {
            return nil;
        }
    }
    NSString *imageName = self.fixedBackgroundImageNames[index];
    UIImage *image = self.fixedImageCache[imageName];
    if (!image) {
        image = [self imageInBundleWithName:imageName];
        if (!self.fixedImageCache) {
            self.fixedImageCache = [NSMutableDictionary dictionaryWithCapacity:numPages];
        }
        self.fixedImageCache[imageName] = image;
    }
    return image;
}

- (nullable UIImage *) imageInBundleWithName:(NSString *)imageName
{
    if (imageName.length == 0) {
        return nil;
    }
    NSBundle *bundle = [NSBundle mainBundle];
    if (self.bundleInfo != nil) { //  && [self.bundleInfo.url.scheme isEqualToString:@"file"]
        NSURL *url = self.bundleInfo.url;
        bundle = [NSBundle bundleWithURL:url];
    }
    UIImage *image = nil;
    if ([self respondsToSelector:@selector(traitCollection)]) {
        image = [UIImage imageNamed:imageName inBundle:bundle compatibleWithTraitCollection:nil];
    } else {
        // iOS 7 and below :(
        // Try and find the named image manually in the bundle
        NSMutableArray<NSString *> *scaleSuffixes = [@[@"@3x", @"@2x", @""] mutableCopy];
        // Move our current display scale to the front, so we try it first
        CGFloat scale = [UIScreen mainScreen].scale;
        NSString *currentScaleSuffix = [NSString stringWithFormat:@"@%ldx", (long)scale];
        if ([scaleSuffixes indexOfObject:currentScaleSuffix] != NSNotFound) {
            [scaleSuffixes removeObject:currentScaleSuffix];
            [scaleSuffixes insertObject:currentScaleSuffix atIndex:0];
        }
        NSString *filename = nil;
        NSString *foundFilePath = nil;
        NSArray<NSString *> *fileExtensions = @[@"png", @"jpg"];
        for (NSString *scaleSuffix in scaleSuffixes) {
            for (NSString *fileExtension in fileExtensions) {
                filename = [NSString stringWithFormat:@"%@%@", imageName, scaleSuffix];
                foundFilePath = [bundle pathForResource:filename ofType:fileExtension];
                if (foundFilePath.length > 0) {
                    break;
                }
            }
            if (foundFilePath.length > 0) {
                break;
            }
        }

        if (foundFilePath.length > 0) {
            image = [UIImage imageWithContentsOfFile:foundFilePath];
        }
    }

    return image;
}

#pragma mark - Scrolling Background Image

- (void) prepareScrollingBackgroundImageConstraints
{
    if (self.scrollingBackgroundImage.image == nil) {
        return;
    }

    [self.view removeConstraints:self.scrollingBackgroundImageConstraints];
    self.scrollingBackgroundImageConstraints = nil;

    NSMutableArray *newConstraints = [NSMutableArray arrayWithCapacity:4];
    UILayoutConstraintAxis axis = self.pagesStackView.axis;
    // Top and Left Constraint
    NSLayoutConstraint *topConstraint = [self createConstraintForAttribute:NSLayoutAttributeTop];
    NSLayoutConstraint *leftConstraint = [self createConstraintForAttribute:NSLayoutAttributeLeading];
    if (axis == UILayoutConstraintAxisVertical) {
        self.scrollImageOffsetConstraint = topConstraint;
    } else {
        self.scrollImageOffsetConstraint = leftConstraint;
    }
    [newConstraints addObject:topConstraint];
    [newConstraints addObject:leftConstraint];

    // Bottom or Right constraint
    NSLayoutConstraint *thirdConstraint = nil;
    if (axis == UILayoutConstraintAxisVertical) {
        thirdConstraint = [self createConstraintForAttribute:NSLayoutAttributeTrailing];
    } else {
        thirdConstraint = [self createConstraintForAttribute:NSLayoutAttributeBottom];
    }
    [newConstraints addObject:thirdConstraint];

    self.scrollingBackgroundImageConstraints = newConstraints;

    [self.view addConstraints:newConstraints];
}

- (NSLayoutConstraint *)createConstraintForAttribute:(NSLayoutAttribute)attribute
{
    NSLayoutConstraint *constraint = [NSLayoutConstraint constraintWithItem:self.scrollingBackgroundImage attribute:attribute relatedBy:NSLayoutRelationEqual toItem:self.view attribute:attribute multiplier:1.0 constant:0.0];

    return constraint;
}

- (void) updateScrollingBackgroundImageOffset
{
    if (self.scrollingBackgroundImage.image == nil) {
        return;
    }
    UILayoutConstraintAxis axis = self.pagesStackView.axis;
    CGFloat imageViewSize = 0.0;
    if (axis == UILayoutConstraintAxisHorizontal) {
        imageViewSize = CGRectGetWidth(self.scrollingBackgroundImage.bounds);
    } else {
        imageViewSize = CGRectGetHeight(self.scrollingBackgroundImage.bounds);
    }
    CGFloat totalPageSize = [self totalContentSize];
    CGFloat singlePageSize = [self singlePageSize];
    // Add some total overscroll buffer, let's say 5% of image size
    CGFloat overscrollBuffer = MIN(64.0, imageViewSize*0.05);
    CGFloat singleSideOverscroll = (overscrollBuffer / 2.0);
    if (singlePageSize == 0.0 || singlePageSize == totalPageSize) {
        return;
    }
    CGFloat scrollOffset = [self currentScrollOffset];
    CGFloat pageScrollPercentage = scrollOffset / (totalPageSize - singlePageSize);

    // Mark what the max and min scroll values will be, then set the offset
    CGFloat maxImageScrollRange = (imageViewSize-singlePageSize-overscrollBuffer);
    CGFloat offset = (maxImageScrollRange * pageScrollPercentage);
    // Ensure we have clamp offset when underscrolling
    offset = MAX(offset, -singleSideOverscroll);
    // Ensure we have clamp offset when overscrolling
    offset = MIN(maxImageScrollRange+singleSideOverscroll, offset);
    // Add the necessary starting offset
    offset += singleSideOverscroll;
    self.scrollImageOffsetConstraint.constant = -offset;
    [self.view setNeedsLayout];
}

#pragma mark - Counting / Measuring Pages

- (void) updateUIForCurrentPage
{
    [self updatePageControls];
    [self updateStaticButtonTitleForCurrentPage];
    [self updateFixedBackgroundImageForCurrentPageAnimated:NO];
    [self updateScrollingBackgroundImageOffset];
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
    [self updateUIForCurrentPage];
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
    if (pageSize == 0) {
        // We may not be layed out yet
        return 0;
    }
    CGFloat page = floor((double)offset/(double)pageSize);
    return MAX(0,(NSInteger)page);
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
- (IBAction)onSkipButtonTriggered:(UIButton *)sender
{
    NSDictionary *info = @{@"current_page": @([self currentPage])};
    [self finishFlowWithResult:LKViewControllerFlowResultCancelled userInfo:info];
}

- (IBAction)onStaticContinueButtonTriggered:(UIButton *)sender
{
    [self moveToNextOnboardingPage:nil];
}

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
    NSInteger page = [self currentPage];
    for (UIPageControl *pageControl in self.pageControls) {
        pageControl.currentPage = page;
    }
}

- (void) scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    [self updateUIForCurrentPage];
}

- (void) scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (!decelerate) {
        [self updateUIForCurrentPage];
    }
}

- (void) scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView
{
    [self updateUIForCurrentPage];
}

- (void) scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self updateFixedBackgroundImageForCurrentScroll];
    [self updateScrollingBackgroundImageOffset];
}

@end
