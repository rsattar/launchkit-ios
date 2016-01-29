//
//  LKGradientView.m
//  Pods
//
//  Created by Rizwan Sattar on 1/28/16.
//
//

#import "LKGradientView.h"

@implementation LKGradientView

+ (Class) layerClass
{
    return [CAGradientLayer class];
}

- (void) commonInit
{
    self.angleDegrees = 90.0;
    self.gradientColor1 = [UIColor clearColor];
    self.gradientColor2 = [UIColor clearColor];
    [self updateGradient];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void) updateGradient
{
    CAGradientLayer *gradientLayer = (CAGradientLayer *)self.layer;

    UIColor *color1 = self.gradientColor1 ? self.gradientColor1 : [UIColor clearColor];
    UIColor *color2 = self.gradientColor2 ? self.gradientColor2 : [UIColor clearColor];

    gradientLayer.colors = @[(id)color1.CGColor,
                             (id)color2.CGColor];
    gradientLayer.locations = @[@(0.0),
                                @(1.0)];
    // Going left to right, by default
    CGPoint start = CGPointMake(0.0, 0.5);
    CGPoint end = CGPointMake(1.0, 0.5);
    CGPoint origin = CGPointMake(0.5, 0.5);
    CGFloat angleRadians = (self.angleDegrees * M_PI) / 180.0;
    start = [self rotatePoint:start byAngle:angleRadians origin:origin];
    end = [self rotatePoint:end byAngle:angleRadians origin:origin];

    gradientLayer.startPoint = start;
    gradientLayer.endPoint = end;
}

// Useful rotation method derived from: http://stackoverflow.com/a/3162657/9849
- (CGPoint) rotatePoint:(CGPoint)point byAngle:(CGFloat)angleRadians origin:(CGPoint)origin
{
    CGFloat sine = sin(angleRadians);
    CGFloat cosine = cos(angleRadians);

    CGFloat x = point.x - origin.x;
    CGFloat y = point.y - origin.y;

    CGFloat rotatedX = (x * cosine) - (y * sine);
    CGFloat rotatedY = (x * sine) - (y * cosine);

    rotatedX += origin.x;
    rotatedY += origin.y;

    return CGPointMake(rotatedX, rotatedY);
}

- (void)setGradientColor1:(UIColor *)gradientColor1
{
    _gradientColor1 = gradientColor1;
    [self updateGradient];
}

- (void)setGradientColor2:(UIColor *)gradientColor2
{
    _gradientColor2 = gradientColor2;
    [self updateGradient];
}

- (void)setAngleDegrees:(CGFloat)angleDegrees
{
    _angleDegrees = angleDegrees;
    [self updateGradient];
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end
