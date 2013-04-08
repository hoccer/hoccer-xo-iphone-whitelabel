//
//  InviteCodeViewController.m
//  HoccerTalk
//
//  Created by David Siegel on 05.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "InviteCodeViewController.h"
#import "AppDelegate.h"
#import "HoccerTalkBackend.h"

@implementation InviteCodeViewController

@dynamic navigationItem;

@synthesize chatBackend = _chatBackend;

- (void) viewDidLoad {
    [super viewDidLoad];
    NSLog(@"navigation item: %@", self.navigationItem);
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                target:self
                                                                                action:@selector(canceld:)];
    self.navigationItem.leftBarButtonItem = cancelButton;
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                  target:self
                                                                                  action:@selector(onDone:)];
    self.navigationItem.rightBarButtonItem = doneButton;
    self.codeTextField.delegate = self;
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];
    self.label.text = NSLocalizedString(@"or", @"Invite Token View Controller");
    [self.clipboardButton setTitle: NSLocalizedString(@"Paste", @"Invite Code Copy/Paste Button") forState: UIControlStateNormal];
    NSLog(@"pasteboard: '%@'", [UIPasteboard generalPasteboard].string);
    if ([[UIPasteboard generalPasteboard].string isEqualToString: @""]) {
        self.clipboardButton.enabled = NO;
        self.clipboardButton.alpha = 0.5;
    } else {
        self.clipboardButton.enabled = YES;
        self.clipboardButton.alpha = 1.0;
    }
    _newTokenButtonPressed = NO;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return NO;
    [self onDone: nil];
}

- (IBAction) newCodePressed:(id)sender {
    _newTokenButtonPressed = YES;
    ((UIButton*)sender).enabled = NO;
    ((UIButton*)sender).alpha = 0.5;
    [self.chatBackend generateToken: @"pairing" validFor: 60 * 60 * 24 * 7 /* TODO: kInvitationTokenValidity*/ tokenHandler: ^(NSString* token) {
        if (token == nil) {
            return;
        }
        self.label.text = NSLocalizedString(@"Send this token to a friend:", @"Invite Token View Controller");

        self.codeTextField.text = token;

        self.clipboardButton.enabled = YES;
        self.clipboardButton.alpha = 1.0;
        [self.clipboardButton setTitle: NSLocalizedString(@"Copy", @"Invite Code Copy/Paste Button") forState: UIControlStateNormal];
    }];
}

- (IBAction) copyPasteButtonPressed:(id)sender {
    if (_newTokenButtonPressed) {
        [UIPasteboard generalPasteboard].string = self.codeTextField.text;
    } else {
        self.codeTextField.text = [UIPasteboard generalPasteboard].string;
    }
}

- (void) onDone:(id) sender {
    NSLog(@"onDone");
    if ( ! _newTokenButtonPressed) {
        [self.chatBackend pairByToken: self.codeTextField.text pairingHandler:^(BOOL success) {
            [InviteCodeViewController showPairingAlert: success];
        }];
    }
    [self dismissModalViewControllerAnimated: YES];
}

- (void) canceld:(id) sender {
    NSLog(@"canceld");
    [self dismissModalViewControllerAnimated: YES];
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField{
    return ! _newTokenButtonPressed;
}

- (void)viewDidUnload {
    [self setCodeTextField:nil];
    [self setLabel:nil];
    [self setClipboardButton:nil];
    [self setNavigationItem:nil];
    [super viewDidUnload];
}

- (HoccerTalkBackend*) chatBackend {
    if (_chatBackend == nil) {
        _chatBackend = ((AppDelegate *)[[UIApplication sharedApplication] delegate]).chatBackend;
    }
    return _chatBackend;
}

+ (void) showPairingAlert: (BOOL) success {
    NSString * title;
    NSString * message;
    if (success) {
        title = NSLocalizedString(@"Invite successful", @"Invite Alert Title");
        message = NSLocalizedString(@"The server accepted your code", @"Invite Alert Message");
    } else {
        title = NSLocalizedString(@"Invite failed", @"Invite Alert Title");
        message = NSLocalizedString(@"The server rejected your invite code", @"Invite Alert Message");
    }
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle: title
                                                    message: message
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
}

@end