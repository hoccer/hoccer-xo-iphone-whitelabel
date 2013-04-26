//
//  MasterViewController.m
//  HoccerXO
//
//  Created by David Siegel on 12.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ConversationViewController.h"

#import <QuartzCore/QuartzCore.h>

#import "ChatViewController.h"
#import "Contact.h"
#import "ConversationCell.h"
#import "InsetImageView.h"
#import "AssetStore.h"
#import "HXOMessage.h"
#import "MFSideMenu.h"
#import "AppDelegate.h"
#import "UIViewController+HXOSideMenuButtons.h"
#import "HXOUserDefaults.h"
#import "RadialGradientView.h"
#import "CustomNavigationBar.h"
#import "ProfileViewController.h"
#import "InviteFooterView.h"
#import "InvitationController.h"

@interface ConversationViewController ()

@property (nonatomic,strong) ConversationCell* conversationCell;
@property (nonatomic,readonly) InviteFooterView * inviteFooter;

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;
@end

@implementation ConversationViewController

- (void)awakeFromNib {
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        self.clearsSelectionOnViewWillAppear = NO;
        self.contentSizeForViewInPopover = CGSizeMake(320.0, 600.0);
    }
    self.conversationCell = [self.tableView dequeueReusableCellWithIdentifier: [ConversationCell reuseIdentifier]];

    [super awakeFromNib];
}

- (void)viewDidLoad {
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    self.navigationItem.leftBarButtonItem = [self hxoMenuButton];
    self.navigationItem.rightBarButtonItem = [self hxoContactsButton];

    if ([[HXOUserDefaults standardUserDefaults] boolForKey: kHXODefaultScreenShooting]) {
        self.navigationItem.leftBarButtonItem.enabled = NO;
        self.navigationItem.rightBarButtonItem.enabled = NO;
    }

    UIImage * icon = [UIImage imageNamed: @"navbar-icon-home"];
    UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithImage: icon style:UIBarButtonItemStylePlain target:nil action:nil];
    self.navigationItem.backBarButtonItem = backButton;

    self.navigationItem.titleView = [[UIImageView alloc] initWithImage: [UIImage imageNamed: @"navbar_logo"]];

    // TODO: ask @zutrinken
    self.tableView.backgroundView = [[RadialGradientView alloc] initWithFrame: self.tableView.frame];
}

- (ChatViewController*) chatViewController {
    if (_chatViewController == nil) {
        _chatViewController = [self.storyboard instantiateViewControllerWithIdentifier: @"chatViewController"];
    }
    return _chatViewController;
}

- (void) viewWillAppear:(BOOL)animated  {
    [super viewWillAppear: animated];
    [self setNavigationBarBackgroundWithLines];
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear: animated];

    // TODO: find a way to move this to the app delegate
    if ( ! [[HXOUserDefaults standardUserDefaults] boolForKey: kHXOFirstRunDone]) {
        UINavigationController * profileView = [self.storyboard instantiateViewControllerWithIdentifier: @"modalProfileViewController"];
        [self.navigationController presentViewController: profileView animated: YES completion: nil];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table View

- (BOOL) isEmpty {
    if (self.fetchedResultsController.sections.count == 0) {
        return YES;
    } else {
        id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][0];
        return [sectionInfo numberOfObjects] == 0;
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (self.emptyTablePlaceholder != nil) {
        return 1;
    }
    return [[self.fetchedResultsController sections] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.emptyTablePlaceholder != nil) {
        return 1;
    }
    id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
    return [sectionInfo numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.emptyTablePlaceholder) {
        self.emptyTablePlaceholder.placeholder.text = NSLocalizedString(@"conversation_empty_placeholder", nil);
        self.emptyTablePlaceholder.icon.image = [UIImage imageNamed: @"xo.png"];
        return self.emptyTablePlaceholder;
    } else {
        UITableViewCell * cell = [tableView dequeueReusableCellWithIdentifier: [ConversationCell reuseIdentifier] forIndexPath: indexPath];
        [self configureCell:cell atIndexPath:indexPath];
        return cell;
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    return self.inviteFooter;
}

@synthesize inviteFooter = _inviteFooter;
- (UIView*) inviteFooter {
    if (_inviteFooter == nil) {
        _inviteFooter = [[NSBundle mainBundle] loadNibNamed:@"InviteFooterView" owner:self options:nil][0];
        [_inviteFooter.button addTarget: self action: @selector(inviteFriendsPressed:) forControlEvents: UIControlEventTouchUpInside];
        // NSLog(@"invite footer frame %@", NSStringFromCGRect(_inviteFooter.frame));
    }
    return _inviteFooter;
}

- (void) inviteFriendsPressed: (id) sender {
    [[InvitationController sharedInvitationController] presentWithViewController: self];
}

- (CGFloat) tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return self.inviteFooter.frame.size.height;
}

- (CGFloat) tableView: (UITableView*) tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (self.emptyTablePlaceholder) {
        return self.emptyTablePlaceholder.bounds.size.height;
    }
    return self.conversationCell.bounds.size.height;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return NO;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
        [context deleteObject:[self.fetchedResultsController objectAtIndexPath:indexPath]];
        
        NSError *error = nil;
        if (![context save:&error]) {
             // Replace this implementation with code to handle the error appropriately.
             // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    }   
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // The table view should not be re-orderable.
    return NO;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        Contact * contact = (Contact*)[[self fetchedResultsController] objectAtIndexPath:indexPath];
        self.chatViewController.partner = contact;
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"showChat"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        Contact * contact = [[self fetchedResultsController] objectAtIndexPath:indexPath];
        _chatViewController = [segue destinationViewController];
        [_chatViewController setPartner: contact];
    }
}

#pragma mark - Fetched results controller

- (NSFetchedResultsController *)fetchedResultsController
{
    if (_fetchedResultsController != nil) {
        return _fetchedResultsController;
    }
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName: [Contact entityName] inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];
    
    // Set the batch size to a suitable number.
    [fetchRequest setFetchBatchSize:20];
    
    // Edit the sort key as appropriate.
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"latestMessageTime" ascending: NO];
    NSArray *sortDescriptors = @[sortDescriptor];

    [fetchRequest setSortDescriptors:sortDescriptors];

    NSPredicate *filterPredicate = [NSPredicate predicateWithFormat: @"relationshipState == 'friend'"];
    [fetchRequest setPredicate: filterPredicate];

    // Edit the section name key path and cache name if appropriate.
    // nil for section name key path means "no sections".
    NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:@"Contacts"];
    aFetchedResultsController.delegate = self;
    self.fetchedResultsController = aFetchedResultsController;
    
	NSError *error = nil;
	if (![self.fetchedResultsController performFetch:&error]) {
	     // Replace this implementation with code to handle the error appropriately.
	     // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
	    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
	    abort();
	}
    
    return _fetchedResultsController;
}    

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
   switch(type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    UITableView *tableView = self.tableView;
    
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            [self configureCell:[tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
            break;
            
        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }

    [self updateEmptyTablePlaceholderAnimated: YES];
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView endUpdates];
}

/*
// Implementing the above methods to update the table view in response to individual changes may have performance implications if a large number of changes are made simultaneously. If this proves to be an issue, you can instead just implement controllerDidChangeContent: which notifies the delegate that all section and object changes have been processed. 
 
 - (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    // In the simplest, most efficient, case, reload the table view.
    [self.tableView reloadData];
}
 */

- (void)configureCell:(UITableViewCell *)aCell atIndexPath:(NSIndexPath *)indexPath {
    ConversationCell * cell = (ConversationCell*)aCell;
    Contact * contact = (Contact*)[self.fetchedResultsController objectAtIndexPath:indexPath];
    // cell.nickName.text = contact.nickName;
    cell.nickName.text = contact.nickNameWithStatus;
    cell.avatar.image = contact.avatarImage != nil ? contact.avatarImage : [UIImage imageNamed: @"avatar_default_contact"];
    cell.latestMessageLabel.frame = self.conversationCell.latestMessageLabel.frame;
    NSDate * latestMessageTime = nil;
    if ([contact.latestMessage count] == 0){
        cell.latestMessageLabel.text = NSLocalizedString(@"no_messages_exchanged", nil);
        cell.latestMessageLabel.font = [UIFont italicSystemFontOfSize: cell.latestMessageLabel.font.pointSize];
    } else {
        cell.latestMessageLabel.text = [contact.latestMessage[0] body];
        cell.latestMessageLabel.font = [UIFont systemFontOfSize: cell.latestMessageLabel.font.pointSize];
        latestMessageTime = [contact.latestMessage[0] timeSent];
    }
    [cell.latestMessageLabel sizeToFit];

    if (latestMessageTime) {
        NSCalendar *calendar = [NSCalendar currentCalendar];
        NSDateComponents *components = [calendar components:(NSEraCalendarUnit|NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit) fromDate:[NSDate date]];
        NSDate *today = [calendar dateFromComponents:components];

        components = [calendar components:(NSEraCalendarUnit|NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit) fromDate: latestMessageTime];
        NSDate *latestMessageDate = [calendar dateFromComponents:components];
        NSDateFormatter * formatter = [[NSDateFormatter alloc] init];
        if([today isEqualToDate: latestMessageDate]) {
            [formatter setDateStyle:NSDateFormatterNoStyle];
            [formatter setTimeStyle:NSDateFormatterShortStyle];
        } else {
            [formatter setDateStyle:NSDateFormatterMediumStyle];
            [formatter setTimeStyle:NSDateFormatterNoStyle];
        }
        cell.latestMessageTimeLabel.text = [formatter stringFromDate: latestMessageTime];
    } else {
        cell.latestMessageTimeLabel.text = @"";
    }
    cell.hasNewMessages = contact.unreadMessages.count > 0;
}

@end