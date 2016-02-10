//
//  LKSimpleStackView.m
//  LaunchKit
//
//  Created by Rizwan Sattar on 8/3/15.
//
//

#import "LKSimpleStackView.h"

@interface LKSimpleStackView ()

@property (strong, nonatomic) NSMutableArray *stackedSubviews;

// The constraint tying the first arranged subview to the superview, along the axis
@property (strong, nonatomic) NSLayoutConstraint *firstAxisConstraint;
// List of all the axis-aligned constraints between arranged subviews
@property (strong, nonatomic) NSMutableArray *spacingConstraints;
// List of all the off-axis constraints making our view larger than subviews
@property (strong, nonatomic) NSMutableArray *offAxisSizeConstraints;
// Constraints on all arranged subviews aligning along axis
@property (strong, nonatomic) NSMutableArray *alignmentConstraints;
// Constraints being applied along axis to make some subviews bigger than others
@property (strong, nonatomic) NSMutableArray *distributionConstraints;
// The constraint tying the last arranged subview to the superview, along the axis
@property (strong, nonatomic) NSLayoutConstraint *lastAxisConstraint;

@property (assign, nonatomic) BOOL shouldRebuildLayout;
@property (readonly, nonatomic) NSString *axisString;
@property (readonly, nonatomic) NSString *offAxisString;
@property (readonly, nonatomic) NSUInteger numVisibleStackedSubviews;
@end

@implementation LKSimpleStackView

+ (BOOL)requiresConstraintBasedLayout
{
    return YES;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {

    }
    return self;
}

- (instancetype)initWithArrangedSubviews:(NSArray*)views
{
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.stackedSubviews = [NSMutableArray arrayWithArray:views];
        for (UIView *view in self.stackedSubviews) {
            [self addSubview:view];
        }
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        //self.stackedSubviews = [NSMutableArray arrayWithCapacity:MAX(1, self.subviews.count)];

        NSArray *constraints = self.constraints;
        NSMutableSet *subviewsSet = [NSMutableSet setWithArray:self.subviews];
        NSMutableSet *constrainedSubviews = [NSMutableSet setWithCapacity:self.subviews.count];
        NSMutableArray *automaticIBConstraintsToRemove = [NSMutableArray array];
        for (NSLayoutConstraint *constraint in constraints) {
            if (constraint.secondAttribute == NSLayoutAttributeNotAnAttribute) {
                continue;
            }
            NSString *className = NSStringFromClass([constraint class]);
            if ([className isEqualToString:@"NSIBPrototypingLayoutConstraint"]) {
                if ([subviewsSet member:constraint.firstItem]) {
                    // We are going to remove this constraint, so don't consider the subview
                    // associated with this constraint to actually be "constrained"
                    [automaticIBConstraintsToRemove addObject:constraint];
                }
                continue;
            }
            if ([subviewsSet member:constraint.firstItem]) {
                [constrainedSubviews addObject:constraint.firstItem];
            } else if ([subviewsSet member:constraint.secondItem]) {
                [constrainedSubviews addObject:constraint.secondItem];
            }
        }
        [self removeConstraints:automaticIBConstraintsToRemove];
        [subviewsSet minusSet:constrainedSubviews];
        self.stackedSubviews = [NSMutableArray arrayWithCapacity:subviewsSet.count];
        for (UIView *subview in self.subviews) {
            if ([subviewsSet member:subview]) {
                [self.stackedSubviews addObject:subview];
            }
        }
    }
    return self;
}

- (NSInteger)alignmentValue
{
    return (NSInteger)self.alignment;
}

- (void)setAlignmentValue:(NSInteger)alignmentValue
{
    self.alignment = (alignmentValue == 1) ? LKSimpleStackViewAlignmentCenter : LKSimpleStackViewAlignmentFill;
    [self setNeedsUpdateConstraints];
}

- (NSInteger)axisValue
{
    return (NSInteger)self.axis;
}

- (void)setAxisValue:(NSInteger)axisValue
{
    self.axis = (axisValue == 1) ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
    [self setNeedsUpdateConstraints];
}

- (NSInteger)distributionValue
{
    return (NSInteger)self.distribution;
}

- (void)setDistributionValue:(NSInteger)distributionValue
{
    self.distribution = (distributionValue == 1) ? LKSimpleStackViewDistributionFillEqually : LKSimpleStackViewDistributionFill;
    [self setNeedsUpdateConstraints];
}

- (NSArray *)arrangedSubviews
{
    NSArray *views = [NSArray arrayWithArray:self.stackedSubviews];
    return views;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self invalidateIntrinsicContentSize];
}

- (void)setNeedsUpdateConstraints
{
    [super setNeedsUpdateConstraints];
    self.shouldRebuildLayout = YES;
}
- (void)updateConstraints
{
    [super updateConstraints];
    if (self.shouldRebuildLayout) {
        // EXPENSIVE!
        [self rebuildLayoutConstraints];
        self.shouldRebuildLayout = NO;
    }
}

//- (void)addArrangedSubview:(UIView *)subview
//{
//    [self.stackedSubviews addObject:subview];
//    [self addSubview:subview];
//}
//
//- (void)removeArrangedSubview:(UIView *)subview
//{
//    if ([self.stackedSubviews containsObject:subview]) {
//        [self.stackedSubviews removeObject:subview];
//    }
//    [subview removeFromSuperview];
//}

- (void)iterateVisibleArrangedSubviews:(void (^)(UIView *previous, UIView *current, BOOL *stop))iterationBlock
{
    UIView *previous = nil;
    BOOL shouldStop = NO;
    for (NSInteger i = 0; i < self.stackedSubviews.count; i++) {
        UIView *current = self.stackedSubviews[i];
        if (current.hidden) {
            continue;
        }

        iterationBlock(previous, current, &shouldStop);

        if (shouldStop) {
            break;
        }
        previous = current;
    }
    if (!shouldStop && previous != nil) {
        // Send the last one
        iterationBlock(previous, nil, &shouldStop);
    }
}


#pragma mark - Content Size
/*
- (CGSize)intrinsicContentSize
{
    CGSize noIntrinsicMetricSize = CGSizeMake(UIViewNoIntrinsicMetric, UIViewNoIntrinsicMetric);
    CGSize contentSize = [super intrinsicContentSize];


    BOOL foundActualIntrinsicSize = !CGSizeEqualToSize(contentSize, noIntrinsicMetricSize);
    CGFloat maxOffAxisDimension = MAX(0.0, (self.axis == UILayoutConstraintAxisVertical) ? contentSize.width : contentSize.height);
    CGFloat totalAxisDimension = MAX(0.0, (self.axis == UILayoutConstraintAxisVertical) ? contentSize.height : contentSize.width);
    for (UIView *subview in self.stackedSubviews) {
        if (subview.hidden) {
            continue;
        }
        CGSize subviewIntrinsicSize = subview.intrinsicContentSize;
        if (CGSizeEqualToSize(subviewIntrinsicSize, noIntrinsicMetricSize)) {
            continue;
        }
        foundActualIntrinsicSize = YES;
        if (self.axis == UILayoutConstraintAxisVertical) {
            // Width should just be max of subviews
            maxOffAxisDimension = MAX(maxOffAxisDimension, subviewIntrinsicSize.width);
            totalAxisDimension += MAX(0.0, subviewIntrinsicSize.height);
        } else {
            maxOffAxisDimension = MAX(maxOffAxisDimension, subviewIntrinsicSize.height);
            totalAxisDimension += MAX(0.0, subviewIntrinsicSize.width);
        }
    }

    NSUInteger numVisibleStackedSubviews = self.numVisibleStackedSubviews;
    if (foundActualIntrinsicSize) {
        // Don't add spacing if none of our views actually have an intrinsic size? ¯\_(ツ)_/¯
        totalAxisDimension += self.spacing * (numVisibleStackedSubviews-1);
        
        if (self.layoutMarginsRelativeArrangement && numVisibleStackedSubviews > 0) {
            if (self.axis == UILayoutConstraintAxisVertical) {
                totalAxisDimension += self.lkMargins.top + self.lkMargins.bottom;
                maxOffAxisDimension += self.lkMargins.left + self.lkMargins.right;
            } else {
                totalAxisDimension += self.lkMargins.left + self.lkMargins.right;
                maxOffAxisDimension += self.lkMargins.top + self.lkMargins.bottom;
            }
        }
    }

    // If our content size still has not produced any reasonable size, return invalid
    if (!foundActualIntrinsicSize && totalAxisDimension == 0.0 && maxOffAxisDimension == 0.0) {
        return noIntrinsicMetricSize;
    }

    return CGSizeMake(maxOffAxisDimension, totalAxisDimension);
}
*/

#pragma mark - Layout

- (NSString *)axisString
{
    return (self.axis == UILayoutConstraintAxisVertical) ? @"V" : @"H";
}


- (NSString *)offAxisString
{
    return (self.axis == UILayoutConstraintAxisVertical) ? @"H" : @"V";
}

- (NSUInteger)numVisibleStackedSubviews
{
    NSUInteger count = 0;
    for (UIView *subview in self.stackedSubviews) {
        if (!subview.hidden) {
            count++;
        }
    }
    return count;
}

// NOTE: This is very inefficient, but should work on a "barebones" perspective (and if the stacked UI is not dynamic)
- (void)rebuildLayoutConstraints
{
    NSMutableArray *constraintsToRemove = [NSMutableArray arrayWithCapacity:self.stackedSubviews.count*2];
    if (self.firstAxisConstraint) {
        [constraintsToRemove addObject:self.firstAxisConstraint];
    }
    if (self.lastAxisConstraint) {
        [constraintsToRemove addObject:self.lastAxisConstraint];
    }
    if (self.spacingConstraints.count > 0) {
        [constraintsToRemove addObjectsFromArray:self.spacingConstraints];
    }
    if (self.offAxisSizeConstraints.count > 0) {
        [constraintsToRemove addObjectsFromArray:self.offAxisSizeConstraints];
    }
    if (self.alignmentConstraints.count > 0) {
        [constraintsToRemove addObjectsFromArray:self.alignmentConstraints];
    }
    if (self.distributionConstraints.count > 0) {
        [constraintsToRemove addObjectsFromArray:self.distributionConstraints];
    }
    [self removeConstraints:constraintsToRemove];

    self.spacingConstraints = [NSMutableArray arrayWithCapacity:self.stackedSubviews.count];
    self.offAxisSizeConstraints = [NSMutableArray arrayWithCapacity:self.stackedSubviews.count];
    self.alignmentConstraints = [NSMutableArray arrayWithCapacity:self.stackedSubviews.count];
    self.distributionConstraints = [NSMutableArray arrayWithCapacity:self.stackedSubviews.count];
    self.firstAxisConstraint = nil;
    self.lastAxisConstraint = nil;

    NSLayoutFormatOptions alignmentOptions = 0;
    CGFloat axisMarginLeading = 0.0;
    CGFloat axisMarginTrailing = 0.0;
    if (self.axis == UILayoutConstraintAxisVertical) {
        alignmentOptions = NSLayoutFormatAlignAllCenterX;
        if (self.layoutMarginsRelativeArrangement) {
            axisMarginLeading = self.lkMargins.top;
            axisMarginTrailing = self.lkMargins.bottom;
        }
    } else {
        alignmentOptions = NSLayoutFormatAlignAllCenterY;
        if (self.layoutMarginsRelativeArrangement) {
            axisMarginLeading = self.lkMargins.left;
            axisMarginTrailing = self.lkMargins.right;
        }
    }

    NSString *spaceToPreviousFormat = [NSString stringWithFormat:@"%@:[previous]-(spacing)-[current]", self.axisString];
    NSDictionary *spacingMetrics = @{@"spacing" : @(self.spacing)};

    [self iterateVisibleArrangedSubviews:^(UIView *previous, UIView *current, BOOL *stop) {

        // Spacing
        if (previous != nil) {
            if (current != nil) {
                // Space to previous subview
                [self.spacingConstraints addObjectsFromArray:
                 [NSLayoutConstraint constraintsWithVisualFormat:spaceToPreviousFormat
                                                         options:0
                                                         metrics:spacingMetrics
                                                           views:NSDictionaryOfVariableBindings(previous, current)]];
            } else {
                // Last subview is 'previous', attach to trailing axis
                NSString *lastSubviewFormat = [NSString stringWithFormat:@"%@:[previous]-(axisMarginTrailing)-|", self.axisString];
                self.lastAxisConstraint =
                [NSLayoutConstraint constraintsWithVisualFormat:lastSubviewFormat
                                                        options:0
                                                        metrics:@{@"axisMarginTrailing" : @(axisMarginTrailing)}
                                                          views:NSDictionaryOfVariableBindings(previous)][0];
            }
        } else {
            // Space to leading superview on-axis-edge
            NSString *firstSubviewFormat = [NSString stringWithFormat:@"%@:|-(axisMarginLeading)-[current]", self.axisString];
            self.firstAxisConstraint =
            [NSLayoutConstraint constraintsWithVisualFormat:firstSubviewFormat
                                                    options:0
                                                    metrics:@{@"axisMarginLeading" : @(axisMarginLeading)}
                                                      views:NSDictionaryOfVariableBindings(current)][0];
        }
        // Add constraints here that make the stack view >= size of all the subviews
        // e.g. like ">= subview.height", if axis is horizontal
        if (current != nil) {
            // Add a low priority constraint to make our view larger than our subview, in the off-axis
            NSLayoutConstraint *constraint = nil;
            NSLayoutAttribute attribute = NSLayoutAttributeWidth;
            CGFloat totalMargins = 0.0;
            if (self.axis == UILayoutConstraintAxisVertical) {
                attribute = NSLayoutAttributeWidth;
                if (self.layoutMarginsRelativeArrangement) {
                    totalMargins += (self.lkMargins.left + self.lkMargins.right);
                }
            } else {
                attribute = NSLayoutAttributeHeight;
                if (self.layoutMarginsRelativeArrangement) {
                    totalMargins += (self.lkMargins.top + self.lkMargins.bottom);
                }
            }
            constraint = [NSLayoutConstraint constraintWithItem:self
                                                      attribute:attribute
                                                      relatedBy:NSLayoutRelationGreaterThanOrEqual
                                                         toItem:current
                                                      attribute:attribute
                                                     multiplier:1.0
                                                       constant:totalMargins];
            constraint.priority = UILayoutPriorityDefaultLow;
            [self.offAxisSizeConstraints addObject:constraint];
        }
    }];

    [self.alignmentConstraints addObjectsFromArray:[self buildAlignmentConstraintsForArrangedSubviews]];
    [self.distributionConstraints addObjectsFromArray:[self buildDistributionConstraintsForArrangedSubviews]];

    NSMutableArray *constraintsToAdd = [NSMutableArray arrayWithArray:self.spacingConstraints];
    [constraintsToAdd addObjectsFromArray:self.offAxisSizeConstraints];
    [constraintsToAdd addObjectsFromArray:self.alignmentConstraints];
    [constraintsToAdd addObjectsFromArray:self.distributionConstraints];
    if (self.firstAxisConstraint) {
        [constraintsToAdd addObject:self.firstAxisConstraint];
    }
    if (self.lastAxisConstraint) {
        [constraintsToAdd addObject:self.lastAxisConstraint];
    }
    [self addConstraints:constraintsToAdd];
}

#pragma mark - Distribution

- (NSArray *)buildDistributionConstraintsForArrangedSubviews
{
    NSMutableArray *constraints = [NSMutableArray arrayWithCapacity:self.stackedSubviews.count*2];

    NSLayoutAttribute axisDimensionAttribute = (self.axis == UILayoutConstraintAxisVertical) ? NSLayoutAttributeHeight : NSLayoutAttributeWidth;

    UILayoutPriority lowestHuggingPriority = UILayoutPriorityRequired;
    UIView *leastHuggingSubview = nil;

    UILayoutPriority lowestCompressionPriority = UILayoutPriorityRequired;
    UIView *leastCompressingSubview = nil;

    for (UIView *subview in self.stackedSubviews) {
        if (subview.hidden) {
            continue;
        }
        UILayoutPriority huggingPriority = [subview contentHuggingPriorityForAxis:self.axis];
        if (!leastHuggingSubview || huggingPriority < lowestHuggingPriority) {
            lowestHuggingPriority = huggingPriority;
            leastHuggingSubview = subview;
        }

        UILayoutPriority compressionPriority = [self contentCompressionResistancePriorityForAxis:self.axis];
        if (!leastCompressingSubview || compressionPriority < lowestCompressionPriority) {
            lowestCompressionPriority = compressionPriority;
            leastCompressingSubview = subview;
        }
    }
    if (self.distribution == LKSimpleStackViewDistributionFillEqually) {
        [self iterateVisibleArrangedSubviews:^(UIView *previous, UIView *current, BOOL *stop) {
            if (previous != nil && current != nil) {
                [constraints addObject:
                 [NSLayoutConstraint constraintWithItem:previous
                                              attribute:axisDimensionAttribute
                                              relatedBy:NSLayoutRelationEqual
                                                 toItem:current
                                              attribute:axisDimensionAttribute
                                             multiplier:1.0
                                               constant:0.0]];
            }
            
        }];
    } else if (self.distribution == LKSimpleStackViewDistributionFill) {
        CGFloat currentLength = (self.axis == UILayoutConstraintAxisVertical) ? CGRectGetHeight(self.bounds) : CGRectGetWidth(self.bounds);

        CGSize ourNaturalSize = self.intrinsicContentSize;
        CGFloat intrinsicLength = (self.axis == UILayoutConstraintAxisVertical) ? ourNaturalSize.height : ourNaturalSize.width;
        BOOL stretchingRequired = NO;
        BOOL compressionRequired = NO;

        if (intrinsicLength < currentLength) {
            stretchingRequired = YES;
        } else if (intrinsicLength > currentLength) {
            compressionRequired = YES;
        }


    }

    return constraints;
}


#pragma mark - Alignment

- (NSArray *)buildAlignmentConstraintsForArrangedSubviews
{
    NSLayoutFormatOptions alignmentOptions = 0;
    CGFloat offAxisMarginLeading = 0.0;
    CGFloat offAxisMarginTrailing = 0.0;
    if (self.axis == UILayoutConstraintAxisVertical) {
        alignmentOptions = NSLayoutFormatAlignAllCenterX;
        if (self.layoutMarginsRelativeArrangement) {
            offAxisMarginLeading = self.lkMargins.left;
            offAxisMarginTrailing = self.lkMargins.right;
        }
    } else {
        alignmentOptions = NSLayoutFormatAlignAllCenterY;
        if (self.layoutMarginsRelativeArrangement) {
            offAxisMarginLeading = self.lkMargins.top;
            offAxisMarginTrailing = self.lkMargins.bottom;
        }
    }

    NSMutableArray *constraints = [NSMutableArray arrayWithCapacity:self.stackedSubviews.count*2];

    // Either we'll fill in the off-axis direction, or center
    NSString *alignmentFillFormat = [NSString stringWithFormat:@"%@:|-(marginLeading)-[current]-(marginTrailing)-|", self.offAxisString];
    NSDictionary *alignmentFillMetrics = @{@"marginLeading" : @(offAxisMarginLeading), @"marginTrailing" : @(offAxisMarginTrailing)};

    NSLayoutAttribute centerAttribute = (self.axis == UILayoutConstraintAxisVertical) ? NSLayoutAttributeCenterX : NSLayoutAttributeCenterY;

    [self iterateVisibleArrangedSubviews:^(UIView *previous, UIView *current, BOOL *stop) {
        // First, add any alignment constraints (for all currents)
        if (current != nil) {
            if (self.alignment == LKSimpleStackViewAlignmentCenter) {
                // Center in the off-hand axis
                [constraints addObject:
                 [NSLayoutConstraint constraintWithItem:current
                                              attribute:centerAttribute
                                              relatedBy:NSLayoutRelationEqual
                                                 toItem:self
                                              attribute:centerAttribute
                                             multiplier:1.0
                                               constant:0.0]];
            } else {
                // Fill
                [constraints addObjectsFromArray:
                 [NSLayoutConstraint constraintsWithVisualFormat:alignmentFillFormat
                                                         options:alignmentOptions
                                                         metrics:alignmentFillMetrics
                                                           views:NSDictionaryOfVariableBindings(current)]];
            }
        }
    }];

    return constraints;
}

#pragma mark - Debugging


- (void) debug_printLayout {
    //var arrangedConstraints: [NSLayoutConstraint] = []
    for (UIView *arrangedSubview in self.stackedSubviews) {
        NSInteger index = [self.stackedSubviews indexOfObject:arrangedSubview];
        NSLog(@"Arranged subview: %ld %@", (long)(index+1), arrangedSubview);
        NSLog(@"---------------------------------");
        NSArray *constraints = arrangedSubview.constraints;
        for (NSLayoutConstraint *constraint in constraints) {
            NSString *className = NSStringFromClass([constraint class]);

            if ([className isEqualToString:@"NSIBPrototypingLayoutConstraint"] ||
                [className isEqualToString:@"NSAutoresizingMaskLayoutConstraint"]) {
                    //continue
                }

            UIView *firstView = constraint.firstItem;
            if ([arrangedSubview.subviews containsObject:firstView]) {
                //continue;
            }

            //                if !constraint.active {
            //                    continue
            //                }
            //                if className == "NSIBPrototypingLayoutConstraint" ||
            //                   className == "NSAutoresizingMaskLayoutConstraint" {
            //                    continue
            //                }
            //
            //                if let secondView = constraint.secondItem as? NSObject
            //                    where firstView != arrangedSubview && secondView != arrangedSubview {
            //                        continue
            //                }
            NSLog(@"%@", constraint);
        }
        NSLog(@"");
        NSLog(@"");
    }
    NSArray *constraints = self.constraints;
    for (NSLayoutConstraint *constraint in constraints) {
        NSString *className = NSStringFromClass([constraint class]);

        if ([className isEqualToString:@"NSIBPrototypingLayoutConstraint"] ||
            [className isEqualToString:@"NSAutoresizingMaskLayoutConstraint"]) {
            //continue
        }
        NSLog(@"%@", constraint);

    }
}



@end
