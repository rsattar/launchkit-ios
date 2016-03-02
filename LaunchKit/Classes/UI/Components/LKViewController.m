//
//  LKViewController.m
//  LaunchKitRemoteUITest
//
//  Created by Rizwan Sattar on 6/15/15.
//  Copyright (c) 2015 Cluster Labs, Inc. All rights reserved.
//

#import "LKViewController.h"

#import "LKPopCustomSegue.h"
#import "UIView+LKAdditions.h"

@interface LKViewController ()

// Form Submission Support: This IBOutletCollection can be
@property (strong, nonatomic) IBOutletCollection(UIView) NSArray *formElements;
@property (strong, nonatomic) IBInspectable NSString *formUrl;
@property (strong, nonatomic) NSURLSession *formSubmissionSession;
@end

@implementation LKViewController

- (void)commonInit
{
    _statusBarStyleValue = -1;
    _cardPresentationShadowAlpha = 0.4;
    _cardPresentationShadowRadius = 4.0;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
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

- (void)viewDidLoad {
    [super viewDidLoad];
    if (self.cardView == nil) {
        self.cardView = self.view;
    }
    // In case our properties were set before the view was loaded, set them here
    if (self.cardView.lk_cornerRadius != self.viewCornerRadius) {
        self.cardView.lk_cornerRadius = self.viewCornerRadius;
    }
    if (_cardPresentationCastsShadow && self.view.layer.shadowOpacity != _cardPresentationShadowAlpha) {
        self.cardPresentationShadowRadius = _cardPresentationShadowRadius;
        self.cardPresentationShadowAlpha = _cardPresentationShadowAlpha;
        self.view.layer.shadowColor = [UIColor blackColor].CGColor;
        self.view.layer.shadowOffset = CGSizeZero;
    }
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

// This method (or a signature with IBAction and UIStoryboardSegue param)
// needs to exist so that exit segues can be hooked up to them
// See: http://spin.atomicobject.com/2014/10/25/ios-unwind-segues/
- (IBAction)prepareForUnwind:(UIStoryboardSegue *)segue
{
    
}


- (IBAction)finishFlowWithSuccess:(UIStoryboardSegue *)segue
{
    // Determine the actual view controller to finish with
    [self finishFlowWithResult:LKViewControllerFlowResultCompleted userInfo:nil];
}


- (IBAction)finishFlowWithCancellation:(UIStoryboardSegue *)segue
{
    // Determine the actual view controller to finish with
    [self finishFlowWithResult:LKViewControllerFlowResultCancelled userInfo:nil];
}


- (IBAction)finishFlowWithFailure:(UIStoryboardSegue *)segue
{
    // Determine the actual view controller to finish with
    [self finishFlowWithResult:LKViewControllerFlowResultFailed userInfo:nil];
}


- (UIStoryboardSegue *) segueForUnwindingToViewController:(UIViewController *)toViewController fromViewController:(UIViewController *)fromViewController identifier:(NSString *)identifier
{
    NSString *customUnwindSegueName = nil;
    if ([fromViewController isKindOfClass:[LKViewController class]]) {
        customUnwindSegueName = ((LKViewController *)fromViewController).unwindSegueClassName;
    }

    if ([customUnwindSegueName isEqualToString:@"LKPopCustomSegue"]) {
        return [[LKPopCustomSegue alloc] initWithIdentifier:identifier source:fromViewController destination:toViewController];
    } else {
        return [super segueForUnwindingToViewController:toViewController fromViewController:fromViewController identifier:identifier];
    }
}


#pragma mark - Flow Delegation

/// This will finish the flow with the earliest LKViewController in the stack, that
/// has a non-nil flowDelegate
- (void) finishFlowWithResult:(LKViewControllerFlowResult)result userInfo:(nullable NSDictionary *)userInfo
{
    UIViewController *viewController = self;
    while (viewController != nil) {
        LKViewController *lkvc = nil;
        if ([viewController isKindOfClass:[LKViewController class]]) {
            lkvc = (LKViewController *)viewController;
        }
        if (lkvc.flowDelegate != nil) {
            [lkvc.flowDelegate launchKitController:lkvc didFinishWithResult:result userInfo:userInfo];
            break;
        } else {
            viewController = viewController.parentViewController;
        }
    }
    [self markFinishedFlowResult:result];
}

- (void) markFinishedFlowResult:(LKViewControllerFlowResult)result
{
    _finishedFlowResult = result;
}

#pragma mark - Form Submission

- (IBAction) submitForm:(id)sender
{
    if (self.formUrl.length > 0) {
        NSURL *submissionUrl = [NSURL URLWithString:self.formUrl];
        if (submissionUrl == nil) {
            // Error: Form Url invalid
        }

        NSDictionary *form = [self dictionaryFromFormElements:self.formElements];
        [self postDictionary:form toUrl:submissionUrl completion:^(NSError *error) {
            NSLog(@"Form submitted, error? %@", error);
        }];

    } else {
        // Error: Form Url not specified
    }
}


- (NSDictionary *) dictionaryFromFormElements:(NSArray *)formElements
{
    NSMutableDictionary *form = [NSMutableDictionary dictionaryWithCapacity:formElements.count];

    for (UIView *formElement in self.formElements) {
        // For now, use .restorationIdentifier from IB as a placeholder for our formId.
        // I don't think restorationIdentifier will ever be used in remote UI, because it won't
        // be state preserved.
        NSString *formId = formElement.restorationIdentifier;;
        if (!formId) {
            // Error: form element doesn't have an id, so cannot be included
            // in form submission
            continue;
        }
        if ([formElement isKindOfClass:[UISwitch class]]) {
            UISwitch *switchElement = (UISwitch *)formElement;
            //NSLog(@"Switch: %@", switchElement.isOn ? @"ON" : @"OFF");
            form[formId] = @(switchElement.isOn);
        } else if ([formElement isKindOfClass:[UITextField class]]) {
            UITextField *textField = (UITextField *)formElement;
            //NSLog(@"Textfield: %@", textField.text);
            form[formId] = textField.text;
        } else if ([formElement isKindOfClass:[UITextView class]]) {
            UITextView *textView = (UITextView *)formElement;
            //NSLog(@"Textview: %@", textView.text);
            form[formId] = textView.text;
        }
    }

    NSLog(@"Dictionary from form:\n%@", form);

    return form;
}


- (void) postDictionary:(NSDictionary *)dictionary toUrl:(NSURL *)url completion:(void (^)(NSError *error))completionHandler
{
    NSError *jsonError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:&jsonError];

    if (!self.formSubmissionSession) {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        self.formSubmissionSession = [NSURLSession sessionWithConfiguration:config];
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    request.HTTPBody = jsonData;
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    NSURLSessionDataTask *task = [self.formSubmissionSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {

        NSString *responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSLog(@"Response: %@", responseString);
        if (completionHandler) {
            completionHandler(error);
        }
    }];
    [task resume];
}

#pragma mark - viewCornerRadius

- (void)setViewCornerRadius:(CGFloat)viewCornerRadius
{
    _viewCornerRadius = viewCornerRadius;
    if (self.isViewLoaded) {
        self.cardView.lk_cornerRadius = _viewCornerRadius;
    }
}



#pragma mark - Shadow


- (void)setCardPresentationCastsShadow:(BOOL)cardPresentationCastsShadow
{
    _cardPresentationCastsShadow = cardPresentationCastsShadow;
    if (self.isViewLoaded) {
        if (_cardPresentationCastsShadow) {
            self.cardPresentationShadowRadius = _cardPresentationShadowRadius;
            self.cardPresentationShadowAlpha = _cardPresentationShadowAlpha;
            self.view.layer.shadowColor = [UIColor blackColor].CGColor;
            self.view.layer.shadowOffset = CGSizeZero;
        } else {
            // Set them out in the view, but not in our stored properties.
            // That way we can still make changes to the radius and alpha,
            // and the next time we turn on castsShadow it'll be the
            // correct value
            self.view.layer.shadowRadius = 0.0;
            self.view.layer.shadowOpacity = 0.0;
            self.view.layer.shadowColor = NULL;
        }
    }
}


- (void)setCardPresentationShadowAlpha:(CGFloat)cardPresentationShadowAlpha
{
    _cardPresentationShadowAlpha = cardPresentationShadowAlpha;
    if (self.isViewLoaded) {
        if (_cardPresentationCastsShadow) {
            self.view.layer.shadowOpacity = _cardPresentationShadowAlpha;
        }
    }
}


- (void)setCardPresentationShadowRadius:(CGFloat)cardPresentationShadowRadius
{
    _cardPresentationShadowRadius = cardPresentationShadowRadius;
    if (self.isViewLoaded) {
        if (_cardPresentationCastsShadow) {
            self.view.layer.shadowRadius = _cardPresentationShadowRadius;
        }
    }
}


#pragma mark - Status bar


- (void)setStatusBarShouldHide:(BOOL)statusBarShouldHide
{
    _statusBarShouldHide = statusBarShouldHide;
    [self setNeedsStatusBarAppearanceUpdate];
}

- (BOOL)prefersStatusBarHidden
{
    return _statusBarShouldHide;
}

- (void)setStatusBarStyleValue:(NSInteger)statusBarStyleValue
{
    _statusBarStyleValue = statusBarStyleValue;
    [self setNeedsStatusBarAppearanceUpdate];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    if (_statusBarStyleValue >= 0) {
        return _statusBarStyleValue;
    }
    return [super preferredStatusBarStyle];
}


@end

NSString * NSStringFromViewControllerFlowResult(LKViewControllerFlowResult result)
{
    switch (result) {
        case LKViewControllerFlowResultNotSet:
            return @"not-set";
        case LKViewControllerFlowResultCompleted:
            return @"completed";
        case LKViewControllerFlowResultCancelled:
            return @"cancelled";
        case LKViewControllerFlowResultFailed:
            return @"failed";
        default:
            NSLog(@"Couldn't understand flow result %ld; returning 'unknown'", (long)result);
            return @"unknown";
    }
}
