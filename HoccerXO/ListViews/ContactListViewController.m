//
//  ContactListViewController.m
//  HoccerXO
//
//  Created by David Siegel on 12.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ContactListViewController.h"

#import "Contact.h"
#import "Group.h"
#import "ContactCell.h"
#import "AppDelegate.h"
#import "HXOBackend.h"
#import "DatasheetViewController.h"
#import "HXOUI.h"
#import "Group.h"
#import "GroupMembership.h"
#import "HXOUI.h"
#import "LabelWithLED.h"
#import "avatar_contact.h"
#import "avatar_group.h"
#import "avatar_location.h"
#import "AvatarView.h"
#import "HXOUserDefaults.h"
#import "InvitationCodeViewController.h"
#import "ContactCellProtocol.h"
#import "GroupInStatuNascendi.h"
#import "WebViewController.h"
#import "tab_contacts.h"

#define HIDE_SEPARATORS
#define FETCHED_RESULTS_DEBUG NO
#define FETCHED_RESULTS_DEBUG_PERF NO
#define VIEW_UPDATING_DEBUG NO

static const CGFloat kMagicSearchBarHeight = 44;

@interface ContactListViewController ()

@property (nonatomic, strong)   NSFetchedResultsController  * searchFetchedResultsController;
@property (nonatomic, readonly) NSFetchedResultsController  * fetchedResultsController;
@property (nonatomic, strong)   NSManagedObjectContext      * managedObjectContext;

@property                       id                            keyboardHidingObserver;
@property (strong, nonatomic)   id                            connectionInfoObserver;
@property (nonatomic, readonly) HXOBackend                  * chatBackend;

@property (nonatomic, readonly) UITableViewCell             * cellPrototype;
@property (nonatomic, readonly) UIView                      * placeholderView;
@property (nonatomic, readonly) UIImageView                 * placeholderImageView;
@property (nonatomic, readonly) HXOHyperLabel               * placeholderLabel;
@property (nonatomic, readonly) BOOL                          inGroupMode;

@property (nonatomic, readonly) UINavigationController      * webViewController;

@end

@implementation ContactListViewController

@synthesize fetchedResultsController = _fetchedResultsController;
@synthesize placeholderView = _placeholderView;
@synthesize placeholderImageView = _placeholderImageView;
@synthesize placeholderLabel = _placeholderLabel;
@synthesize webViewController = _webViewController;

- (void)awakeFromNib {
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        self.clearsSelectionOnViewWillAppear = NO;
        self.preferredContentSize = CGSizeMake(320.0, 600.0);
    }
    [super awakeFromNib];

    self.tabBarItem.image = [[[tab_contacts alloc] init] image];
    self.tabBarItem.title = NSLocalizedString(@"contact_list_nav_title", nil);
}


- (void)viewDidLoad {
    [super viewDidLoad];

    [self registerCellClass: [self cellClass]];
    
    if (self.hasAddButton) {
        UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemAdd target: self action: @selector(addButtonPressed:)];
        self.navigationItem.rightBarButtonItem = addButton;
    }

    [self setupTitle];

    if ( ! self.searchBar) {
        self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0,0,self.view.bounds.size.width, kMagicSearchBarHeight)];
        self.tableView.tableHeaderView = self.searchBar;
    }
    self.searchBar.delegate = self;
    self.searchBar.placeholder = NSLocalizedString(@"search_placeholder", @"Contact List Search Placeholder");
    self.tableView.contentOffset = CGPointMake(0, self.searchBar.bounds.size.height);

    self.keyboardHidingObserver = [AppDelegate registerKeyboardHidingOnSheetPresentationFor:self];

    self.tableView.rowHeight = [self calculateRowHeight];
    // Apple bug: Order matters. Setting the inset before the color leaves the "no cell separators" in the wrong color.
    self.tableView.separatorColor = [[HXOUI theme] tableSeparatorColor];
    self.tableView.separatorInset = self.cellPrototype.separatorInset;
#ifdef HIDE_SEPARATORS
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
#endif

    self.connectionInfoObserver = [HXOBackend registerConnectionInfoObserverFor:self];

    [[NSNotificationCenter defaultCenter] addObserver:self selector: @selector(preferredContentSizeChanged:) name:UIContentSizeCategoryDidChangeNotification object:nil];

    [self.tableView addSubview: self.placeholderView];
}

- (id) cellClass {
    return [ContactCell class];
}

- (void) setupTitle {
    if (self.hasGroupContactToggle) {
        self.groupContactsToggle = [[UISegmentedControl alloc] initWithItems: @[NSLocalizedString(@"contact_list_nav_title", nil), NSLocalizedString(@"group_list_nav_title", nil)]];
        self.groupContactsToggle.selectedSegmentIndex = 0;
        [self.groupContactsToggle addTarget:self action:@selector(segmentChanged:) forControlEvents: UIControlEventValueChanged];
        self.navigationItem.titleView = self.groupContactsToggle;
    }
    self.navigationItem.title = NSLocalizedString(@"contact_list_nav_title", nil);
}

- (CGFloat) calculateRowHeight {
    // XXX Note: The +1 magically fixes the layout. Without it the multiline
    // label in the conversation view is one pixel short and only fits one line
    // of text. I'm not sure if i'm compensating the separator (thus an apple
    // bug) or if it it is my fault.
    return ceilf([self.cellPrototype systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height) + 1;
}

- (void) preferredContentSizeChanged: (NSNotification*) notification {
    [(id<ContactCell>)self.cellPrototype preferredContentSizeChanged: notification];
    self.tableView.rowHeight = [self calculateRowHeight];
    self.tableView.separatorInset = self.cellPrototype.separatorInset;
    [self.tableView reloadData];
}

- (void) segmentChanged: (id) sender {
    if (FETCHED_RESULTS_DEBUG) NSLog(@"ContactViewController:segmentChanged, sender= %@", sender);
    self.currentFetchedResultsController.delegate = nil;
    [self clearFetchedResultsControllers];
    [self.tableView reloadData];
    [self configurePlaceholder];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver: self.keyboardHidingObserver];
}

- (void) viewWillAppear:(BOOL)animated {
    if (VIEW_UPDATING_DEBUG) NSLog(@"ContactListViewController:viewWillAppear");
    self.currentFetchedResultsController.delegate = self;
    [self.currentFetchedResultsController performFetch:nil];
    [self.tableView reloadData];
    [super viewWillAppear: animated];
    [HXOBackend broadcastConnectionInfo];

    [self configurePlaceholder];
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear: animated];
    if (VIEW_UPDATING_DEBUG) NSLog(@"ContactListViewController:viewDidAppear");
}

- (void) viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear: animated];
    if (VIEW_UPDATING_DEBUG) NSLog(@"ContactListViewController:viewDidDisappear");
    //[self clearFetchedResultsControllers];
    self.currentFetchedResultsController.delegate = nil;
    if ([self isMovingFromParentViewController]) {
        if (VIEW_UPDATING_DEBUG) NSLog(@"isMovingFromParentViewController");
    }
    if ([self isBeingDismissed]) {
        if (VIEW_UPDATING_DEBUG) NSLog(@"isBeingDismissed");
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self.view endEditing:NO]; // hide keyboard on scrolling
}

- (void) addButtonPressed: (id) sender {
    if (self.inGroupMode) {
        [self performSegueWithIdentifier: @"showGroup" sender: sender];
    } else {
        [self invitePeople];
    }
}

- (BOOL) inGroupMode {
    return self.groupContactsToggle && self.groupContactsToggle.selectedSegmentIndex == 1;
}

- (UITableViewCell*) cellPrototype {
     return [self prototypeCellOfClass: [self cellClass]];
}

- (NSFetchedResultsController *)currentFetchedResultsController {
    return self.searchBar.text.length ? self.searchFetchedResultsController : self.fetchedResultsController;
}

- (void) clearFetchedResultsControllers {
    _fetchedResultsController.delegate = nil;
    _fetchedResultsController = nil;
    _searchFetchedResultsController.delegate = nil;
    _searchFetchedResultsController = nil;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [self.currentFetchedResultsController.sections count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    id <NSFetchedResultsSectionInfo> sectionInfo = self.currentFetchedResultsController.sections[section];
    return [sectionInfo numberOfObjects];
}

- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    id cell = [tableView dequeueReusableCellWithIdentifier: [[self cellClass] reuseIdentifier] forIndexPath:indexPath];
    [self configureCell: cell atIndexPath: indexPath];
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    id <NSFetchedResultsSectionInfo> sectionInfo = self.currentFetchedResultsController.sections[section];
    return [sectionInfo name];
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    Contact * contact = [self.currentFetchedResultsController objectAtIndexPath:indexPath];
    [self performSegueWithIdentifier: [contact.type isEqualToString: [Group entityName]] ? @"showGroup" : @"showContact" sender: indexPath];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if (FETCHED_RESULTS_DEBUG_PERF) NSLog(@"ContactListController:prepareForSegue %@ sender %@", segue, sender);
    NSString * sid = [segue identifier];
    if ([sid isEqualToString: @"showGroup"] && [sender isEqual: self.navigationItem.rightBarButtonItem]) {
        DatasheetViewController * vc = [segue destinationViewController];
        vc.inspectedObject = [[GroupInStatuNascendi alloc] init];
    } else if ([sid isEqualToString:@"showContact"] || [sid isEqualToString: @"showGroup"]) {
        Contact * contact = [self.currentFetchedResultsController objectAtIndexPath: sender];
        DatasheetViewController * vc = [segue destinationViewController];
        vc.inspectedObject = contact;
    }
}

#pragma mark - Search Bar

- (void) searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [self clearFetchedResultsControllers];
    [self.tableView reloadData];
}

#pragma mark - Fetched results controller

- (NSManagedObjectContext *)managedObjectContext {
    if ( ! _managedObjectContext) {
        _managedObjectContext = ((AppDelegate *)[[UIApplication sharedApplication] delegate]).managedObjectContext;
    }
    return _managedObjectContext;
}

- (NSFetchedResultsController *)newFetchedResultsControllerWithSearch:(NSString *)searchString {
    if (FETCHED_RESULTS_DEBUG) NSLog(@"ContactListController:newFetchedResultsControllerWithSearch %@", searchString);
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName: [self entityName] inManagedObjectContext: self.managedObjectContext];
    [fetchRequest setEntity:entity];
    [fetchRequest setSortDescriptors: self.sortDescriptors];

    NSMutableArray *predicateArray = [NSMutableArray array];
    [self addPredicates: predicateArray];
    if(searchString.length) {
        [self addSearchPredicates: predicateArray searchString: searchString];
    }
    NSPredicate * filterPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:predicateArray];
    [fetchRequest setPredicate:filterPredicate];

    [fetchRequest setFetchBatchSize:20];

    NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest: fetchRequest
                                                                                                managedObjectContext: self.managedObjectContext
                                                                                                  sectionNameKeyPath: nil
                                                                                                           cacheName: nil];
    aFetchedResultsController.delegate = self;

    NSError *error = nil;
    if (![aFetchedResultsController performFetch:&error]) {
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }

    return aFetchedResultsController;
}

- (NSArray*) sortDescriptors {
    return @[[[NSSortDescriptor alloc] initWithKey:@"nickName" ascending: YES]];
}

- (void) addPredicates: (NSMutableArray*) predicates {
    if (FETCHED_RESULTS_DEBUG) NSLog(@"ContactListController:addPredicates %@", predicates);
    if ([self.entityName isEqualToString: @"Contact"]) {
        [predicates addObject: [NSPredicate predicateWithFormat:@"type == %@ AND (relationshipState == 'friend' OR relationshipState == 'blocked' OR relationshipState == 'kept' OR relationshipState == 'groupfriend')", [self entityName]]];
    } /* else {
       [predicates addObject: [NSPredicate predicateWithFormat:@"type == %@", [self entityName]]];
    } */
}

- (void) addSearchPredicates: (NSMutableArray*) predicates searchString: (NSString*) searchString {
    if (FETCHED_RESULTS_DEBUG) NSLog(@"ContactListController:addPredicates %@", predicates);
    [predicates addObject: [NSPredicate predicateWithFormat:@"nickName CONTAINS[cd] %@", searchString]];
}

- (id) entityName {
    return self.inGroupMode ? [Group entityName] : [Contact entityName];
}

- (NSFetchedResultsController *)fetchedResultsController {
    if (_fetchedResultsController != nil) {
        return _fetchedResultsController;
    }
    _fetchedResultsController = [self newFetchedResultsControllerWithSearch: nil];
    return _fetchedResultsController;
}

- (NSFetchedResultsController *)searchFetchedResultsController {
    if (_searchFetchedResultsController != nil) {
        return _searchFetchedResultsController;
    }
    _searchFetchedResultsController = [self newFetchedResultsControllerWithSearch: self.searchBar.text];
    return _searchFetchedResultsController;
}

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    //NSLog(@"controllerWillChangeContent: %@",[NSThread callStackSymbols]);
    //if (FETCHED_RESULTS_DEBUG) NSLog(@"controllerWillChangeContent: %@ fetchRequest %@",controller, [controller fetchRequest]);
    if (FETCHED_RESULTS_DEBUG_PERF) NSLog(@"%@:controllerWillChangeContent", [self class]);
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
    if (FETCHED_RESULTS_DEBUG || FETCHED_RESULTS_DEBUG_PERF) {
        NSDictionary * changeTypeName = @{@(NSFetchedResultsChangeInsert):@"NSFetchedResultsChangeInsert",
                                          @(NSFetchedResultsChangeDelete):@"NSFetchedResultsChangeDelete",
                                          @(NSFetchedResultsChangeUpdate):@"NSFetchedResultsChangeUpdate",
                                          @(NSFetchedResultsChangeMove):@"NSFetchedResultsChangeMove"};
        
        
        //if (FETCHED_RESULTS_DEBUG) NSLog(@"ContactListViewController:NSFetchedResultsController: %@ fetchRequest %@ didChangeObject:class %@ ptr=%x path:%@ type:%@ newpath=%@",controller, [controller fetchRequest], [anObject class],(unsigned int)(__bridge void*)anObject,indexPath,changeTypeName[@(type)],newIndexPath);
        
        if (FETCHED_RESULTS_DEBUG) NSLog(@"ContactListViewController:NSFetchedResultsController: %@ didChangeObject:class %@ ptr=%x path:%@ type:%@ newpath=%@",controller, [anObject class],(unsigned int)(__bridge void*)anObject,indexPath,changeTypeName[@(type)],newIndexPath);
        //NSLog(@"ContactListViewController:NSFetchedResultsController:didChangeObject:%@ path:%@ type:%@ newpath=%@",anObject,indexPath,changeTypeName[@(type)],newIndexPath);
        NSLog(@"ContactListViewController:NSFetchedResultsController: %@",[NSThread callStackSymbols]);
    }
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;

        case NSFetchedResultsChangeDelete:
            [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;

        case NSFetchedResultsChangeUpdate:
            /* workaround - see:
             * http://stackoverflow.com/questions/14354315/simultaneous-move-and-update-of-uitableviewcell-and-nsfetchedresultscontroller
             * and
             * http://developer.apple.com/library/ios/#releasenotes/iPhone/NSFetchedResultsChangeMoveReportedAsNSFetchedResultsChangeUpdate/
             */
            //[self configureCell: [self.tableView cellForRowAtIndexPath:indexPath]
            //                   atIndexPath: newIndexPath ? newIndexPath : indexPath];
            {
                UITableViewCell * cell = [self.tableView cellForRowAtIndexPath:indexPath];
                // cell is nil if not visible
                if (cell != nil) {
                    [self configureCell: cell atIndexPath: newIndexPath ? newIndexPath : indexPath];
                }
            }
            break;

        case NSFetchedResultsChangeMove:
            [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [self.tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }

    [self configurePlaceholder];
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    //NSLog(@"controllerDidChangeContent: %@",[NSThread callStackSymbols]);
    //if (FETCHED_RESULTS_DEBUG) NSLog(@"controllerDidChangeContent %@ fetchRequest %@",controller, [controller fetchRequest]);
    if (FETCHED_RESULTS_DEBUG_PERF) NSLog(@"%@:controllerDidChangeContent", [self class]);
    NSDate * start = [NSDate new];
    [self.tableView endUpdates];
    NSDate * stop = [NSDate new];
    if (FETCHED_RESULTS_DEBUG_PERF) NSLog(@"%@:controllerDidChangeContent: updates took %1.3f", [self class], [stop timeIntervalSinceDate:start]);
}

- (void)configureCell: (ContactCell*) cell atIndexPath:(NSIndexPath *)indexPath {
    if (FETCHED_RESULTS_DEBUG_PERF) NSLog(@"ContactListViewController:configureCell %@ path %@, self class = %@",  [cell class],indexPath, [self class]);
    if (FETCHED_RESULTS_DEBUG_PERF) NSLog(@"%@",  [NSThread callStackSymbols]);
    Contact * contact = (Contact*)[self.currentFetchedResultsController objectAtIndexPath:indexPath];

    cell.delegate = nil;

    cell.titleLabel.text = contact.nickNameWithStatus;
    
    UIImage * avatar = contact.avatarImage;
    cell.avatar.image = avatar;
    cell.avatar.defaultIcon = [contact.type isEqualToString: [Group entityName]] ? [((Group*)contact).groupType isEqualToString: @"nearby"] ? [[avatar_location alloc] init] : [[avatar_group alloc] init] : [[avatar_contact alloc] init];
    cell.avatar.isBlocked = [contact isBlocked];
    cell.avatar.isPresent  = contact.isPresent && !contact.isKept;

    cell.subtitleLabel.text = [self statusStringForContact: contact];
}

- (NSString*) statusStringForContact: (Contact*) contact {
    if ([contact isKindOfClass: [Group class]]) {
        Group * group = (Group*)contact;
        NSInteger joinedMemberCount = [group.otherJoinedMembers count];
        NSInteger invitedMemberCount = [group.otherInvitedMembers count];

        NSString * joinedStatus = @"";

        if (group.isKept) {
            joinedStatus = NSLocalizedString(@"group_state_kept", nil);
            
        } else if (group.myGroupMembership.isInvited){
            joinedStatus = NSLocalizedString(@"group_membership_state_invited", nil);
            
        } else {
            if (group.iAmAdmin) {
                joinedStatus = NSLocalizedString(@"group_membership_role_admin", nil);
            }
            if (joinedMemberCount > 0) {
                if (joinedStatus.length>0) {
                    joinedStatus = [NSString stringWithFormat:@"%@, ", joinedStatus];
                }
                if (joinedMemberCount > 1) {
                    joinedStatus = [NSString stringWithFormat:NSLocalizedString(@"group_member_count_n_joined",nil), joinedStatus,joinedMemberCount];
                } else {
                    joinedStatus = [NSString stringWithFormat:NSLocalizedString(@"group_member_count_one_joined",nil), joinedStatus];
                }
            } else {
                if (joinedStatus.length>0) {
                    joinedStatus = [NSString stringWithFormat:@"%@, ", joinedStatus];
                }
                joinedStatus = [NSString stringWithFormat:NSLocalizedString(@"group_member_count_none_joined",nil), joinedStatus,joinedMemberCount];

            }
            if (invitedMemberCount > 0) {
                if (joinedStatus.length>0) {
                    joinedStatus = [NSString stringWithFormat:@"%@, ", joinedStatus];
                }
                joinedStatus = [NSString stringWithFormat:NSLocalizedString(@"group_member_invited_count",nil), joinedStatus,invitedMemberCount];
            }
#ifdef DEBUG
            if (group.sharedKeyId != nil) {
                joinedStatus = [[joinedStatus stringByAppendingString:@" "] stringByAppendingString:group.sharedKeyIdString];
            }
#endif
        }
        return joinedStatus;
    } else {
        NSString * relationshipKey = [NSString stringWithFormat: @"contact_relationship_%@", contact.relationshipState];
        return NSLocalizedString(relationshipKey, nil);
    }
}

#pragma mark - Invitations

- (void) invitePeople {
    NSMutableArray * actions = [NSMutableArray array];
    HXOActionSheetCompletionBlock completion = ^(NSUInteger buttonIndex, UIActionSheet *actionSheet) {
        if (buttonIndex != actionSheet.cancelButtonIndex) {
            ((void(^)())actions[buttonIndex])(); // uhm, ok ... just call the damn thing, alright?
        }
    };

    UIActionSheet * sheet = [HXOUI actionSheetWithTitle: NSLocalizedString(@"invite_option_sheet_title", @"Actionsheet Title")
                                        completionBlock: completion
                                      cancelButtonTitle: nil
                                 destructiveButtonTitle: nil
                                      otherButtonTitles: nil];


    if ([MFMessageComposeViewController canSendText]) {
        [sheet addButtonWithTitle: NSLocalizedString(@"invite_option_sms_btn_title",@"Invite Actionsheet Button Title")];
        [actions addObject: ^() { [self inviteBySMS]; }];
    }
    if ([MFMailComposeViewController canSendMail]) {
        [sheet addButtonWithTitle: NSLocalizedString(@"invite_option_mail_btn_title",@"Invite Actionsheet Button Title")];
        [actions addObject: ^() { [self inviteByMail]; }];
    }
    [sheet addButtonWithTitle: NSLocalizedString(@"invite_option_code_btn_title",@"Invite Actionsheet Button Title")];
    [actions addObject: ^() { [self inviteByCode]; }];

    sheet.cancelButtonIndex = [sheet addButtonWithTitle: NSLocalizedString(@"cancel", nil)];

    [sheet showInView: self.view];
}

- (void) inviteByMail {
    [self.chatBackend generatePairingTokenWithHandler: ^(NSString* token) {
        if (token == nil) {
            return;
        }
        MFMailComposeViewController *picker= ((AppDelegate*)[UIApplication sharedApplication].delegate).mailPicker = [[MFMailComposeViewController alloc] init];
        picker.mailComposeDelegate = self;

        [picker setSubject: NSLocalizedString(@"invite_mail_subject", @"Mail Invitation Subject")];

        NSString * body = NSLocalizedString(@"invite_mail_body", @"Mail Invitation Body");
        NSString * inviteLink = [self inviteURL: token];
        NSString * appStoreLink = [self appStoreURL];
        //NSString * androidLink = [self androidURL];
        body = [NSString stringWithFormat: body, appStoreLink, /*androidLink,*/ inviteLink/*, token*/];
        [picker setMessageBody:body isHTML:NO];

        [self presentViewController: picker animated: YES completion: nil];
    }];
}

- (void) inviteBySMS {
    [self.chatBackend generatePairingTokenWithHandler: ^(NSString* token) {
        if (token == nil) {
            return;
        }
        MFMessageComposeViewController *picker= ((AppDelegate*)[UIApplication sharedApplication].delegate).smsPicker = [[MFMessageComposeViewController alloc] init];
        picker.messageComposeDelegate = self;

        NSString * smsText = NSLocalizedString(@"invite_sms_text", @"SMS Invitation Body");
        picker.body = [NSString stringWithFormat: smsText, [self inviteURL: token], [[HXOUserDefaults standardUserDefaults] valueForKey: kHXONickName]];

        [self presentViewController: picker animated: YES completion: nil];

    }];
}

- (void) inviteByCode {
    [self performSegueWithIdentifier: @"showInviteCodeViewController" sender: self];
}

- (NSString*) inviteURL: (NSString*) token {
    return [NSString stringWithFormat: @"%@://%@", kHXOURLScheme, token];
}

- (NSString*) appStoreURL {
    return @"itms-apps://itunes.com/apps/hoccerxo";
}

- (NSString*) androidURL {
    return @"http://google.com";
}

- (void)mailComposeController:(MFMailComposeViewController*)controller
          didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {

	switch (result) {
		case MFMailComposeResultCancelled:
			break;
		case MFMailComposeResultSaved:
			break;
		case MFMailComposeResultSent:
			break;
		case MFMailComposeResultFailed:
            NSLog(@"mailComposeControllerr:didFinishWithResult MFMailComposeResultFailed");
			break;
		default:
			break;
	}
    [self dismissViewControllerAnimated: NO completion: nil];
}

- (void)messageComposeViewController:(MFMessageComposeViewController *)controller
                 didFinishWithResult:(MessageComposeResult)result {

	switch (result) {
		case MessageComposeResultCancelled:
			break;
		case MessageComposeResultSent:
			break;
		case MessageComposeResultFailed:
            NSLog(@"messageComposeViewController:didFinishWithResult MessageComposeResultFailed");
			break;
		default:
			break;
	}
    [self dismissViewControllerAnimated: NO completion: nil];
}

#pragma mark - Empty Table Placeholder

- (UIView*) placeholderView {
    if ( ! _placeholderView) {
        CGFloat h = self.view.bounds.size.height - (self.view.bounds.origin.y + 50);
        _placeholderView = [[UIView alloc] initWithFrame: CGRectMake(0, 0, self.view.bounds.size.width, h)];
        _placeholderView.autoresizingMask = UIViewAutoresizingFlexibleWidth;

        [_placeholderView addSubview: self.placeholderImageView];
        [_placeholderView addSubview: self.placeholderLabel];

        NSDictionary * views = @{@"image": self.placeholderImageView, @"label": self.placeholderLabel};
        NSString * format = [NSString stringWithFormat: @"H:|-[image]-|"];
        [_placeholderView addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format options: 0 metrics: nil views: views]];

        format = [NSString stringWithFormat: @"H:|-[label]-|"];
        [_placeholderView addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format options: 0 metrics: nil views: views]];

        format = [NSString stringWithFormat: @"V:|-(%f)-[image]-(%f)-[label]-(>=%f)-|", 8 * kHXOGridSpacing, 4 * kHXOGridSpacing, kHXOGridSpacing];
        [_placeholderView addConstraints: [NSLayoutConstraint constraintsWithVisualFormat: format options: 0 metrics: nil views: views]];
    }
    return _placeholderView;
}

- (UIImageView*) placeholderImageView {
    if ( ! _placeholderImageView) {
        _placeholderImageView = [[UIImageView alloc] initWithFrame: CGRectZero];
        _placeholderImageView.translatesAutoresizingMaskIntoConstraints = NO;
        _placeholderImageView.contentMode = UIViewContentModeCenter;
    }
    return _placeholderImageView;
}

- (HXOHyperLabel*) placeholderLabel {
    if ( ! _placeholderLabel) {
        _placeholderLabel = [[HXOHyperLabel alloc] initWithFrame: CGRectZero];
        _placeholderLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _placeholderLabel.textColor = [HXOUI theme].tablePlaceholderTextColor;
        _placeholderLabel.font = [UIFont preferredFontForTextStyle: UIFontTextStyleCaption1];
        _placeholderLabel.textAlignment = NSTextAlignmentCenter;
        _placeholderLabel.delegate = self;
    }
    return _placeholderLabel;
}

- (void) configurePlaceholder {
    self.placeholderLabel.attributedText = [self placeholderText];
    self.placeholderImageView.image = [self placeholderImage];

    BOOL isEmpty = [self tableViewIsEmpty];
    self.placeholderView.alpha = isEmpty ? 1 : 0;
    self.tableView.tableHeaderView = isEmpty ? nil : self.searchBar;
}

- (BOOL) tableViewIsEmpty {
    for (int i = 0; i < [self numberOfSectionsInTableView: self.tableView]; ++i) {
        if ([self tableView: self.tableView numberOfRowsInSection: i] > 0) {
            return NO;
        }
    }
    return YES;
}

- (NSAttributedString*) placeholderText {
    return HXOLocalizedStringWithLinks(self.inGroupMode ? @"group_list_placeholder" : @"contact_list_placeholder", nil);
}

- (UIImage*) placeholderImage {
    return [UIImage imageNamed: self.inGroupMode ? @"placeholder-groups" : @"placeholder-chats"];
}

- (void) hyperLabel: (HXOHyperLabel*) label didPressLink: (id) link long: (BOOL) longPress {
    ((WebViewController*)self.webViewController.viewControllers[0]).homeUrl = link;
    [self.navigationController presentViewController: self.webViewController animated: YES completion: nil];
}

- (UINavigationController*) webViewController {
    if ( ! _webViewController) {
        _webViewController = [self.storyboard instantiateViewControllerWithIdentifier: @"webViewController"];
    }
    return _webViewController;
}

#pragma mark - Attic

@synthesize chatBackend = _chatBackend;
- (HXOBackend*) chatBackend {
    if ( ! _chatBackend) {
        _chatBackend = ((AppDelegate *)[[UIApplication sharedApplication] delegate]).chatBackend;
    }
    return _chatBackend;
}

@end
