//
//  ProfileSheetController.m
//  HoccerXO
//
//  Created by David Siegel on 01.04.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "ProfileSheetController.h"
#import "UserProfile.h"
#import "AppDelegate.h"
#import "HXOUI.h"

@interface ProfileSheetController ()

@property (nonatomic, readonly) UserProfile      * userProfile;

@property (nonatomic, readonly) DatasheetSection * credentialsSection;
//@property (nonatomic, readonly) DatasheetItem    * exportCredentialsItem;
//@property (nonatomic, readonly) DatasheetItem    * importCredentialsItem;
//@property (nonatomic, readonly) DatasheetItem    * deleteCredentialsFileItem;

@end

@implementation ProfileSheetController

@synthesize credentialsSection = _credentialsSection;
@synthesize exportCredentialsItem = _exportCredentialsItem;
@synthesize importCredentialsItem = _importCredentialsItem;
@synthesize deleteCredentialsFileItem = _deleteCredentialsFileItem;

- (void) commonInit {
    [super commonInit];

    self.title = @"profile_nav_title";

    self.nicknameItem.enabledMask = DatasheetModeEdit;

    //self.keyItem.visibilityMask = DatasheetModeView;
    self.keyItem.cellIdentifier = @"DatasheetActionCell";

    self.destructiveButton.title = @"credentials_delete_btn_title";
    self.destructiveButton.visibilityMask = DatasheetModeEdit;
    self.destructiveButton.target = self;
    self.destructiveButton.action = @selector(deleteCredentialsPressed:);

    self.isEditable = YES;

}

- (void) awakeFromNib {


    self.inspectedObject = [UserProfile sharedProfile];
}

- (UserProfile*) userProfile {
    return [self.inspectedObject isKindOfClass: [UserProfile class]] ? self.inspectedObject : nil;
}

- (void) didUpdateInspectedObject {
    [super didUpdateInspectedObject];

    [self.userProfile saveProfile];
}

- (DatasheetSection*) commonSection {
    DatasheetSection * section = [super commonSection];
    section.items = @[self.nicknameItem, self.keyItem];
    return section;
}

- (DatasheetSection*) credentialsSection {
    if ( ! _credentialsSection) {
        _credentialsSection = [DatasheetSection datasheetSectionWithIdentifier: @"credentials_section"];
        _credentialsSection.headerViewIdentifier = @"DatasheetFooterTextView";
        _credentialsSection.items = @[self.exportCredentialsItem,
                                      self.importCredentialsItem,
                                      self.deleteCredentialsFileItem];
    }
    return _credentialsSection;
}

- (void) addUtilitySections:(NSMutableArray *)sections {
    [super addUtilitySections: sections];
    [sections addObject: self.credentialsSection];
}

- (BOOL) isItemVisible:(DatasheetItem *)item {
    if ([item isEqual: self.importCredentialsItem]) {
        return self.userProfile.foundCredentialsFile && [super isItemVisible: item];
    } else if ([item isEqual: self.deleteCredentialsFileItem]) {
        return self.userProfile.foundCredentialsFile && [super isItemVisible: item];
    }
    return [super isItemVisible: item];
}

#pragma mark - Export Credentials

- (DatasheetItem*) exportCredentialsItem {
    if ( ! _exportCredentialsItem) {
        _exportCredentialsItem = [self itemWithIdentifier: @"credentials_export_btn_title" cellIdentifier: @"DatasheetActionCell"];
        _exportCredentialsItem.visibilityMask = DatasheetModeEdit;
        _exportCredentialsItem.target = self;
        _exportCredentialsItem.action = @selector(exportCredentialsPressed:);
    }
    return _exportCredentialsItem;
}

- (void) exportCredentialsPressed: (id) sender {
    void(^completion)(NSString*) = ^(NSString * passphrase) {
        if (passphrase) {
            [[UserProfile sharedProfile] exportCredentialsWithPassphrase: passphrase];
            [HXOUI showErrorAlertWithMessageAsync: nil withTitle: @"credentials_exported_alert"];
            [self updateCurrentItems];
        }
    };

    [HXOUI enterStringAlert:nil withTitle: NSLocalizedString(@"credentials_file_choose_passphrase_alert",nil)
                  withPlaceHolder:NSLocalizedString(@"credentials_file_passphrase_placeholder",nil)
                     onCompletion: completion];
}

#pragma mark - Import Credentials

- (DatasheetItem*) importCredentialsItem {
    if ( ! _importCredentialsItem) {
        _importCredentialsItem = [self itemWithIdentifier: @"credentials_import_btn_title" cellIdentifier: @"DatasheetActionCell"];
        _importCredentialsItem.visibilityMask = DatasheetModeEdit;
        _importCredentialsItem.dependencyPaths = @[@"foundCredentialsFile"];
        _importCredentialsItem.target = self;
        _importCredentialsItem.action = @selector(importCredentialsPressed:);

    }
    return _importCredentialsItem;
}

- (void) importCredentialsPressed: (UIViewController*) sender {
    HXOStringEntryCompletion passphraseCompletion = ^(NSString *passphrase) {
        if (passphrase != nil) {
            int result = [[UserProfile sharedProfile] importCredentialsWithPassphrase:passphrase];
            switch (result) {
                case 1:
                    [((AppDelegate *)[[UIApplication sharedApplication] delegate]) showFatalErrorAlertWithMessage: @"New login credentials have been imported. Restart Hoccer XO to use them" withTitle:@"New Login Credentials Imported"];
                    break;
                case -1:
                    [HXOUI showErrorAlertWithMessageAsync:@"credentials_file_decryption_failed_message" withTitle:@"credentials_file_import_failed_title"];
                    break;
                case 0:
                    [HXOUI showErrorAlertWithMessageAsync:@"credentials_file_equals_current_message" withTitle:@"credentials_file_equals_current_title"];
                    break;
                default:
                    NSLog(@"importCredentialsPressed: unhandled result %d", result);
                    break;
            }
        }
    };

    HXOActionSheetCompletionBlock completion = ^(NSUInteger buttonIndex, UIActionSheet *actionSheet) {
        if (buttonIndex == actionSheet.destructiveButtonIndex) {
            [HXOUI enterStringAlert:nil withTitle:NSLocalizedString(@"credentials_file_enter_passphrase_alert",nil) withPlaceHolder:NSLocalizedString(@"credentials_file_passphrase_placeholder",nil)
                       onCompletion: passphraseCompletion];
        }
    };

    UIActionSheet * sheet = [HXOUI actionSheetWithTitle: NSLocalizedString(@"credentials_import_safety_question", nil)
                                        completionBlock: completion
                                      cancelButtonTitle: NSLocalizedString(@"cancel", nil)
                                 destructiveButtonTitle: NSLocalizedString(@"credentials_key_import_confirm_btn_title", nil)
                                      otherButtonTitles: nil];
    [sheet showInView: self.delegate.view];
}

#pragma mark - Delete Credentials

- (void) deleteCredentialsPressed: (UIViewController*) sender {
    HXOActionSheetCompletionBlock completion = ^(NSUInteger buttonIndex, UIActionSheet * actionSheet) {
        if (buttonIndex == actionSheet.destructiveButtonIndex) {
            [[UserProfile sharedProfile] deleteCredentials];
            [((AppDelegate *)[[UIApplication sharedApplication] delegate]) showFatalErrorAlertWithMessage: @"Your login credentials have been deleted. Hoccer XO will terminate now." withTitle:@"Login Credentials Deleted"];

        }
    };

    UIActionSheet * sheet = [HXOUI actionSheetWithTitle: NSLocalizedString(@"credentials_delete_safety_question", nil)
                                        completionBlock: completion
                                      cancelButtonTitle: NSLocalizedString(@"cancel", nil)
                                 destructiveButtonTitle: NSLocalizedString(@"delete", nil)
                                      otherButtonTitles: nil];
    [sheet showInView: self.delegate.view];
}

#pragma mark - Delete Credentials File

- (DatasheetItem*) deleteCredentialsFileItem {
    if ( ! _deleteCredentialsFileItem) {
        _deleteCredentialsFileItem = [self itemWithIdentifier: @"credentials_file_delete_btn_title" cellIdentifier: @"DatasheetActionCell"];
        _deleteCredentialsFileItem.visibilityMask = DatasheetModeEdit;
        _deleteCredentialsFileItem.target = self;
        _deleteCredentialsFileItem.action = @selector(deleteCredentialsFilePressed:);
    }
    return _deleteCredentialsFileItem;
}

- (void) deleteCredentialsFilePressed: (UIViewController*) sender {
    HXOActionSheetCompletionBlock completion = ^(NSUInteger buttonIndex, UIActionSheet * actionSheet) {
        if (buttonIndex == actionSheet.destructiveButtonIndex) {
            if ([[UserProfile sharedProfile] deleteCredentialsFile]) {
                [HXOUI showErrorAlertWithMessageAsync: nil withTitle:@"credentials_file_deleted_alert"];
            }
            // TODO: show error message if it has not been deleted
            [self updateCurrentItems];
        }
    };

    UIActionSheet * sheet = [HXOUI actionSheetWithTitle: NSLocalizedString(@"credentials_file_delete_safety_question", nil)
                                        completionBlock: completion
                                      cancelButtonTitle: NSLocalizedString(@"cancel", nil)
                                 destructiveButtonTitle: NSLocalizedString(@"delete", nil)
                                      otherButtonTitles: nil];
    [sheet showInView: self.delegate.view];
}

@end
