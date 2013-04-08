//
//  ProfileViewController.m
//  HoccerTalk
//
//  Created by David Siegel on 26.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ProfileViewController.h"
#import "MFSideMenu.h"
#import "UIViewController+HoccerTalkSideMenuButtons.h"
#import "HTUserDefaults.h"
#import "iOSVersionChecks.h"
#import "AssetStore.h"
#import "ProfileAvatarCell.h"
#import "ProfileAvatarView.h"
#import "RadialGradientView.h"
#import "ProfileTextCell.h"
#import "CustomNavigationBar.h"

static const CGFloat kProfileEditAnimationDuration = 0.5;

@interface ProfileItem : NSObject

@property (nonatomic,strong) UIImage  * icon;
@property (nonatomic,strong) NSString * userDefaultsKey;
@property (nonatomic,strong) NSString * currentValue;
@property (nonatomic,strong) NSString * editLabel;
@property (nonatomic,strong) NSString * cellIdentifier;
@property (nonatomic,strong) NSString * placeholder;
@property (nonatomic,assign) UIKeyboardType keyboardType;

@end

@interface AvatarItem : NSObject

@property (nonatomic,strong) UIImage* image;
@property (nonatomic,assign) CGRect   croppingRect;

@end

@implementation ProfileViewController

- (id) initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self != nil) {
        _editing = NO;

        _avatarItem = [[AvatarItem alloc] init];

        _profileItems = [[NSMutableArray alloc] init];

        ProfileItem * nickNameItem = [[ProfileItem alloc] init];
        nickNameItem.icon = [UIImage imageNamed: @"icon_profile-name"];
        nickNameItem.userDefaultsKey = kHTNickName;
        nickNameItem.editLabel = NSLocalizedString(@"Name", @"Profile Edit Label Nick Name");
        nickNameItem.placeholder = NSLocalizedString(@"Your Name", @"Profile Placeholder Nick Name");
        nickNameItem.cellIdentifier = [ProfileTextCell reuseIdentifier];
        nickNameItem.keyboardType = UIKeyboardTypeDefault;
        [_profileItems addObject: nickNameItem];

        ProfileItem * phoneItem = [[ProfileItem alloc] init];
        phoneItem.icon = [UIImage imageNamed: @"icon_profile-phone"];
        phoneItem.userDefaultsKey = @"phoneNumber";
        phoneItem.editLabel = NSLocalizedString(@"Phone", @"Profile Edit Label Phone Number");
        phoneItem.placeholder = NSLocalizedString(@"Your Phone Number", @"Profile Placeholder Phone Number");
        phoneItem.cellIdentifier = [ProfileTextCell reuseIdentifier];
        phoneItem.keyboardType = UIKeyboardTypePhonePad;
        [_profileItems addObject: phoneItem];

        ProfileItem * mailItem = [[ProfileItem alloc] init];
        mailItem.icon = [UIImage imageNamed: @"icon_profile-mail"];
        mailItem.userDefaultsKey = @"mailAddress";
        mailItem.editLabel = NSLocalizedString(@"Mail", @"Profile Edit Label Mail Address");
        mailItem.placeholder = NSLocalizedString(@"Your Mail Address", @"Profile Placeholder Phone Number");
        mailItem.cellIdentifier = [ProfileTextCell reuseIdentifier];
        mailItem.keyboardType = UIKeyboardTypeEmailAddress;
        [_profileItems addObject: mailItem];

    }
    return self;
}

- (void) viewDidLoad {
    [super viewDidLoad];
    ((CustomNavigationBar*)self.navigationController.navigationBar).flexibleRightButton = YES;
    self.navigationItem.leftBarButtonItem =  self.hoccerTalkMenuButton;
    self.navigationItem.rightBarButtonItem = self.editButtonItem;

    UIView * backgroundView = [[RadialGradientView alloc] initWithFrame: self.tableView.bounds];
    //backgroundView.backgroundColor = [UIColor colorWithWhite: 0.95 alpha: 1];
    self.tableView.backgroundView = backgroundView;

    _avatarCell = [self.tableView dequeueReusableCellWithIdentifier: @"avatarCell"];
    _textCell = [self.tableView dequeueReusableCellWithIdentifier: [ProfileTextCell reuseIdentifier]];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];
    [self setNavigationBarBackgroundPlain];

    [self populateItems];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return 1;
    } else {
        return [_profileItems count];
    }
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        return _avatarCell.bounds.size.height;
    } else {
        return _textCell.bounds.size.height;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell * cell = nil;
    if (indexPath.section == 0) {
        cell = [tableView dequeueReusableCellWithIdentifier: @"avatarCell" forIndexPath:indexPath];
        cell.backgroundView= [[UIView alloc] initWithFrame:cell.bounds];
        ((ProfileAvatarCell*)cell).avatar.image = [UIImage imageWithData: [[HTUserDefaults standardUserDefaults] objectForKey: kHTAvatarImage]];
    } else {
        ProfileItem * item = (ProfileItem*)_profileItems[indexPath.row];
        cell = [tableView dequeueReusableCellWithIdentifier: item.cellIdentifier forIndexPath:indexPath];
        if ([item.cellIdentifier isEqualToString: [ProfileTextCell reuseIdentifier]]) {
            [self configureTextCell: (ProfileTextCell*)cell withItem: item atIndexPath: indexPath];
        } else {
            NSLog(@"ProfileViewController cellForRowAtIndexPath: unhandled cell type %@", item.cellIdentifier);
        }
    }
    return cell;
}

- (void) configureTextCell: (ProfileTextCell*) cell withItem: (ProfileItem*) item atIndexPath: (NSIndexPath*) indexPath {
    NSString * value = item.currentValue;
    cell.imageView.image = item.icon;
    cell.textField.text = value;
    cell.textField.enabled = _editing;
    cell.textField.hidden = _editing;
    cell.textField.alpha = _editing ? 1.0 : 0.0;
    cell.textField.placeholder = item.placeholder;
    cell.textField.tag = indexPath.row;
    cell.textInputBackground.alpha = _editing ? 1.0 : 0.0;

    if (_editing) {
        cell.textLabel.text = item.editLabel;
        cell.textLabel.alpha = 1.0;
    } else {
        if (value != nil && [value length] > 0) {
            cell.textLabel.text = value;
            cell.textLabel.alpha = 1.0;
        } else {
            cell.textLabel.text = item.placeholder;
            cell.textLabel.alpha = 0.5;
        }
    }
    
    cell.textField.keyboardType = item.keyboardType;
    if (cell.textInputBackground.image == nil) {
        cell.textInputBackground.image = [AssetStore stretchableImageNamed: @"profile_text_input_bg" withLeftCapWidth:3 topCapHeight:3];
        cell.textInputBackground.frame = CGRectInset(cell.textField.frame, -8, 2);
        cell.textField.delegate = self;
        cell.textField.backgroundColor = [UIColor clearColor];
        cell.textLabel.textColor = [UIColor colorWithWhite: 0.25 alpha: 1.0];
        cell.textLabel.backgroundColor = [UIColor clearColor];
    }
}

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 0;
}

- (void) textFieldDidEndEditing:(UITextField *)textField {
    ((ProfileItem*)_profileItems[textField.tag]).currentValue = textField.text;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return NO;
}

- (void) setEditing:(BOOL)editing animated:(BOOL)animated {
    // do not call super class
    NSLog(@"editing");
    ((CustomNavigationBar*)self.navigationController.navigationBar).flexibleLeftButton = YES;
    ((CustomNavigationBar*)self.navigationController.navigationBar).flexibleRightButton = YES;
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(onCancel:)];
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(onDone:)];
    [self.navigationItem setLeftBarButtonItem: cancelButton animated:YES];
    [self.navigationItem setRightBarButtonItem: doneButton animated:YES];

    [self animateTableCells];
}

- (void) animateTableCells {
    CGFloat alpha = _editing ? 0.0 : 1.0;
    [UIView animateWithDuration: kProfileEditAnimationDuration animations:^{
        for (UITableViewCell * cell in self.tableView.visibleCells) {
            if ([cell isKindOfClass: [ProfileTextCell class]]) {
                ProfileTextCell * profileCell = (ProfileTextCell*)cell;
                profileCell.textField.alpha = alpha;
                profileCell.textField.enabled = ! _editing;
                profileCell.textInputBackground.alpha = alpha;
            }
        }
    } completion:^(BOOL finished) {
        _editing = ! _editing;
    }];
    [UIView animateWithDuration: 0.5 * kProfileEditAnimationDuration animations:^{
        for (UITableViewCell * cell in self.tableView.visibleCells) {
            if ([cell isKindOfClass: [ProfileTextCell class]]) {
                ProfileTextCell * profileCell = (ProfileTextCell*)cell;
                profileCell.textLabel.alpha = 0.0;
            }
        }
    } completion:^(BOOL finished) {
        int index = 0;
        NSArray * indexPaths = self.tableView.indexPathsForVisibleRows;
        for (UITableViewCell * cell in self.tableView.visibleCells) {
            ProfileItem * item = _profileItems[((NSIndexPath*)indexPaths[index++]).row];
            if ([cell isKindOfClass: [ProfileTextCell class]]) {
                ProfileTextCell * profileCell = (ProfileTextCell*)cell;
                if (_editing) {
                    if (profileCell.textField.text == nil || [profileCell.textField.text isEqualToString: @""]) {
                        profileCell.textLabel.text = profileCell.textField.placeholder;
                    } else {
                         profileCell.textLabel.text = profileCell.textField.text;
                    }
                } else {
                    profileCell.textLabel.text = item.editLabel;
                }
            }
        }
        [UIView animateWithDuration: 0.5 * kProfileEditAnimationDuration animations:^{
            for (UITableViewCell * cell in self.tableView.visibleCells) {
                if ([cell isKindOfClass: [ProfileTextCell class]]) {
                    ProfileTextCell * profileCell = (ProfileTextCell*)cell;
                    profileCell.textLabel.alpha = [profileCell.textLabel.text isEqualToString: profileCell.textField.placeholder] ? 0.5 : 1.0;
                }
            }
        }];
    }];

}

- (IBAction)onCancel:(id)sender {
    [self reloadProfile];
    [self restoreNonEditButtons];
    [self animateTableCells];
}

- (IBAction)onDone:(id)sender {
    [self saveProfile];
    [self restoreNonEditButtons];
    [self animateTableCells];
}

- (void) populateItems {
    for (ProfileItem* item in _profileItems) {
        item.currentValue = [[HTUserDefaults standardUserDefaults] valueForKey: item.userDefaultsKey];
    }
}

- (void) saveProfile {
    for (ProfileItem* item in _profileItems) {
        [[HTUserDefaults standardUserDefaults] setValue: item.currentValue forKey: item.userDefaultsKey];
    }
    [[HTUserDefaults standardUserDefaults] synchronize];
}

- (void) reloadProfile {
    [self populateItems];

}

- (void) restoreNonEditButtons {
    ((CustomNavigationBar*)self.navigationController.navigationBar).flexibleRightButton = YES;
    [self.navigationItem setLeftBarButtonItem: self.hoccerTalkMenuButton animated:YES];
    [self.navigationItem setRightBarButtonItem: self.editButtonItem animated:YES];
    [NSTimer scheduledTimerWithTimeInterval: 1.0 target:self selector: @selector(makeLeftButtonFixedWidth) userInfo:nil repeats:NO];
}

- (void) makeLeftButtonFixedWidth {
    ((CustomNavigationBar*)self.navigationController.navigationBar).flexibleLeftButton = NO;
}

- (void)viewDidUnload {
    [super viewDidUnload];
}
@end

@implementation ProfileItem
@end

@implementation AvatarItem
@end
