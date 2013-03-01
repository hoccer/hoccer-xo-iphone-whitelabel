//
//  DetailViewController.m
//  Hoccenger
//
//  Created by David Siegel on 12.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ChatViewController.h"
#import "UIButton+GlossyRounded.h"
#import "Message.h"
#import "AppDelegate.h"

@interface ChatViewController ()
@property (strong, nonatomic) UIPopoverController *masterPopoverController;
- (void)configureView;
@end

@implementation ChatViewController

@synthesize managedObjectContext = _managedObjectContext;
@synthesize chatBackend = _chatBackend;

#pragma mark - Managing the detail item

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWasShown:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillBeHidden:) name:UIKeyboardWillHideNotification object:nil];

    chatTableController = (ChatTableViewController*)[self.childViewControllers objectAtIndex: 0];

    [chatTableController setPartner: _partner];

    
    [self configureView];

}

- (void)viewDidLayoutSubviews {
    [self.sendButton makeRoundAndGlossy];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setPartner:(Contact*) newPartner {
    if (_partner != newPartner) {
        _partner = newPartner;

        [chatTableController setPartner: newPartner];
        // Update the view.
        [self configureView];
    }

    if (self.masterPopoverController != nil) {
        [self.masterPopoverController dismissPopoverAnimated:YES];
    }
}

- (void)configureView
{
    // Update the user interface for the detail item.

    if (self.partner) {
        self.title = self.partner.nickName;
    }
}

- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }

    _managedObjectContext = ((AppDelegate*)[[UIApplication sharedApplication] delegate]).managedObjectContext;
    return _managedObjectContext;
}

- (ChatBackend*) chatBackend {
    if (_chatBackend != nil) {
        return _chatBackend;
    }

    _chatBackend = ((AppDelegate*)[[UIApplication sharedApplication] delegate]).chatBackend;
    return _chatBackend;

}

#pragma mark - Split view

- (void)splitViewController:(UISplitViewController *)splitController willHideViewController:(UIViewController *)viewController withBarButtonItem:(UIBarButtonItem *)barButtonItem forPopoverController:(UIPopoverController *)popoverController
{
    barButtonItem.title = NSLocalizedString(@"Contacts", @"Contacts");
    [self.navigationItem setLeftBarButtonItem:barButtonItem animated:YES];
    self.masterPopoverController = popoverController;
}

- (void)splitViewController:(UISplitViewController *)splitController willShowViewController:(UIViewController *)viewController invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem
{
    // Called when the view is shown again in the split view, invalidating the button and popover controller.
    [self.navigationItem setLeftBarButtonItem:nil animated:YES];
    self.masterPopoverController = nil;
}

#pragma mark - Keyboard events

// TODO: correctly handle orientation changes 

- (void)keyboardWasShown:(NSNotification*)aNotification {
    //NSLog(@"keyboardWasShown");
    NSDictionary* info = [aNotification userInfo];
    CGSize keyboardSize = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    double duration = [[info objectForKey: UIKeyboardAnimationDurationUserInfoKey] doubleValue];

    [UIView animateWithDuration: duration animations:^{
        CGRect frame = self.view.frame;
        frame.size.height -= keyboardSize.height;
        self.view.frame = frame;
    } completion: ^(BOOL finished){ [chatTableController scrollToBottom: NO]; }];
}

- (void)keyboardWillBeHidden:(NSNotification*)aNotification {
    //NSLog(@"keyboardWillBeHidden");
    NSDictionary* info = [aNotification userInfo];
    CGSize keyboardSize = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    double duration = [[info objectForKey: UIKeyboardAnimationDurationUserInfoKey] doubleValue];

    [UIView animateWithDuration: duration animations:^{
        CGRect frame = self.view.frame;
        frame.size.height += keyboardSize.height;
        self.view.frame = frame;
    }];
}

#pragma mark - Actions

- (IBAction)sendPressed:(id)sender
{
    [self.textField resignFirstResponder];
    if (self.textField.text.length > 0) {
        [self.chatBackend sendMessage: self.textField.text toContact: self.partner];
        self.textField.text = @"";
    }
}


@end