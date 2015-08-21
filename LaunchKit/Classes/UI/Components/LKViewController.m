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

@property (assign, nonatomic) BOOL viewLoaded;
@end

@implementation LKViewController

- (void)commonInit
{
    _statusBarStyleValue = -1;
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
    // Do any additional setup after loading the view.
    if (self.view.lk_cornerRadius != self.viewCornerRadius) {
        self.view.lk_cornerRadius = self.viewCornerRadius;
    }
    self.viewLoaded = YES;
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
    [self.flowDelegate launchKitController:self didFinishWithResult:LKViewControllerFlowResultCompleted userInfo:nil];
}


- (IBAction)finishFlowWithCancellation:(UIStoryboardSegue *)segue
{
    [self finishFlowWithResult:LKViewControllerFlowResultCancelled userInfo:nil];
}


- (IBAction)finishFlowWithFailure:(UIStoryboardSegue *)segue
{
    [self.flowDelegate launchKitController:self didFinishWithResult:LKViewControllerFlowResultFailed userInfo:nil];
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
    if (self.viewLoaded) {
        self.view.lk_cornerRadius = _viewCornerRadius;
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
