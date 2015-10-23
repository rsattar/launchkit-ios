//
//  LKImageView.m
//  LaunchKit
//
//  Created by Rizwan Sattar on 8/28/15.
//
//

#import "LKImageView.h"

@implementation LKImageView

//- (instancetype)initWithImage:(UIImage *)image;
//- (instancetype)initWithImage:(UIImage *)image highlightedImage:(UIImage *)highlightedImage NS_AVAILABLE_IOS(3_0);

- (void) setLk_templateAlways:(BOOL)lk_templateAlways
{
    if (_lk_templateAlways != lk_templateAlways) {
        _lk_templateAlways = lk_templateAlways;
        // Image
        self.image = [self updatedRenderingModeImageFromImage:self.image];
        // Highlighted Image
        self.highlightedImage = [self updatedRenderingModeImageFromImage:self.highlightedImage];
    }
}

- (UIImage *) updatedRenderingModeImageFromImage:(UIImage *)image
{
    if (image != nil) {
        if (_lk_templateAlways && image.renderingMode != UIImageRenderingModeAlwaysTemplate) {
            return [self.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        } else if(!_lk_templateAlways && image.renderingMode == UIImageRenderingModeAlwaysTemplate) {
            // NOTE: The image previously may have been UIImagerenderingModeAlwaysImage :(
            // TODO(Riz): Maybe store the previous renderingMode of the image somewhere, and restore it to that
            return [self.image imageWithRenderingMode:UIImageRenderingModeAutomatic];
        }
    }
    return image;
}

- (void) setImage:(UIImage *)image
{
    [super setImage:[self updatedRenderingModeImageFromImage:image]];
}

- (void) setHighlightedImage:(UIImage *)highlightedImage
{
    [super setHighlightedImage:[self updatedRenderingModeImageFromImage:highlightedImage]];
}

@end
