//
//  UserTableViewController.m
//  LaunchKitSample
//
//  Created by Rizwan Sattar on 10/28/15.
//  Copyright © 2015 Cluster Labs, Inc. All rights reserved.
//

#import "UserTableViewController.h"

#import <LaunchKit/LaunchKit.h>

@interface UserTableViewController ()

@property (strong, nonatomic) NSArray *rowIds;

@property (strong, nonatomic) NSNumberFormatter *prettyFormatter;

@end

@implementation UserTableViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    self.rowIds = @[@"name",
                    @"email",
                    @"firstVisit",
                    @"labels",
                    @"stats",
                    @"uniqueId"];

    self.prettyFormatter = [[NSNumberFormatter alloc] init];
    self.prettyFormatter.numberStyle = NSNumberFormatterDecimalStyle;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.rowIds.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"userCellIdentifier" forIndexPath:indexPath];

    // Configure the cell...
    LKAppUser *user = [LaunchKit sharedInstance].currentUser;

    NSString *key = self.rowIds[indexPath.row];
    cell.textLabel.text = @"";
    cell.detailTextLabel.text = @"";
    if ([key isEqualToString:@"name"]) {
        [self configureCell:cell
                  withLabel:@"Name"
                   andValue:user.name];
    } else if ([key isEqualToString:@"email"]) {
        [self configureCell:cell
                  withLabel:@"Email"
                   andValue:user.email];
    } else if ([key isEqualToString:@"firstVisit"]) {
        [self configureCell:cell
                  withLabel:@"First Visit"
                   andValue:[NSString stringWithFormat:@"%@", user.firstVisit]];
    } else if ([key isEqualToString:@"labels"]) {
        NSString *labelsString = [user.labels.allObjects componentsJoinedByString:@", "];
        [self configureCell:cell
                  withLabel:@"Labels"
                   andValue:labelsString];
    } else if ([key isEqualToString:@"stats"]) {
        NSString *visitsString = [self.prettyFormatter stringFromNumber:@(user.stats.visits)];
        NSString *daysString = [self.prettyFormatter stringFromNumber:@(user.stats.days)];
        NSString *statsString = [NSString stringWithFormat:@"%@ visits, %@ days", visitsString, daysString];
        [self configureCell:cell
                  withLabel:@"Stats"
                   andValue:statsString];
    } else if ([key isEqualToString:@"uniqueId"]) {
        [self configureCell:cell
                  withLabel:@"Unique ID"
                   andValue:user.uniqueId];
    }

    return cell;
}

- (void) configureCell:(nonnull UITableViewCell *)cell withLabel:(nonnull NSString *)key andValue:(nullable NSString *)value
{
    cell.textLabel.text = key;
    if (value != nil) {
        cell.detailTextLabel.text = value;
    } else {
        cell.detailTextLabel.text = @"";
    }
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
