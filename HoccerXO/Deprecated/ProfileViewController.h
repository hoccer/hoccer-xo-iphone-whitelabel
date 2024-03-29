//
//  ProfileViewController.h
//  HoccerXO
//
//  Created by David Siegel on 26.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "AttachmentPickerController.h"

#import "HXOTableViewController.h"
#import "ProfileDataSource.h"

@class UserDefaultsCellAvatarPicker;
@class UserDefaultsCellTextInput;
@class AvatarItem;
@class Contact;
@class ProfileItem;
@class AppDelegate;
@class ProfileDataSource;

typedef enum ProfileViewModes {
    ProfileViewModeFirstRun,
    ProfileViewModeMyProfile,
    ProfileViewModeContactProfile,

    ProfileViewModeNewGroup,
    ProfileViewModeEditGroup,
    ProfileViewModeShowGroup
} ProfileViewMode;

@interface ProfileViewController : HXOTableViewController <AttachmentPickerControllerDelegate, UIAlertViewDelegate, UIActionSheetDelegate, ProfileDataSourceDelegate>
{
    AvatarItem *          _avatarItem;
    ProfileSection *      _coreSection;
    
    ProfileItem *         _nickNameItem;
//#ifdef DEBUG
    ProfileSection *      _debugItemsSection;
    ProfileItem *         _clientIdItem;
    ProfileItem *         _groupMembershipsItem;
//#endif
    ProfileSection *      _profileItemsSection;

    ProfileItem *         _chatWithContactItem;
    ProfileItem *         _blockContactItem;
    ProfileSection *      _utilitySection;

    ProfileItem *         _fingerprintItem;
    ProfileItem *         _fingerprintInfoItem;
    ProfileItem *         _exportPublicKeyItem;
    ProfileItem *         _importPublicKeyItem;
    ProfileItem *         _verifyPublicKeyItem;
    ProfileSection *      _fingerprintSection;

    ProfileItem *         _renewKeyPairItem;
    ProfileItem *         _renewKeyPairInfoItem;
    ProfileItem *         _exportPrivateKeyItem;
    ProfileItem *         _importPrivateKeyItem;
    ProfileSection *      _keypairSection;

    ProfileItem *         _deleteContactItem;
    ProfileSection *      _destructiveSection;

    ProfileItem *         _exportCredentialsItem;
    ProfileItem *         _importCredentialsItem;
    ProfileItem *         _deleteCredentialsFileItem;
    ProfileItem *         _deleteCredentialsItem;
    ProfileSection *      _credentialsSection;
    
    NSArray *             _profileItems;
    NSMutableArray *      _allProfileItems;
    ProfileViewMode       _mode;
    BOOL                  _canceled;
    BOOL                  _renewKeypairRequested;
    NSMutableDictionary * _itemsByKeyPath;
    ProfileDataSource *   _profileDataSource;
}


@property (nonatomic,strong) Contact* contact;
@property (strong, readonly) AppDelegate * appDelegate;

- (void) setupNavigationButtons;
- (void) setupContactKVO;
- (IBAction)onCancel:(id)sender;
- (void) populateItems;
- (void) populateValues;

+ (void) exportCredentials;
+ (void) importCredentials;


@end
