//
//  UIViewController+HXOSideMenuButtons.m
//  HoccerXO
//
//  Created by David Siegel on 28.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "UIViewController+HXOSideMenu.h"
#import "MFSideMenu.h"
#import "AssetStore.h"

@implementation UIViewController (HXOSideMenu)

- (UIBarButtonItem*) hxoMenuButton {
    UIImage * icon = [UIImage imageNamed: @"navbar-icon-menu"];
    UIBarButtonItem *button = [[UIBarButtonItem alloc] initWithImage: icon landscapeImagePhone: icon style:UIBarButtonItemStylePlain target:self action:@selector(menuButtonPressed:)];
    return button;
}

- (UIBarButtonItem*) hxoContactsButton {
    UIImage * icon = [UIImage imageNamed: @"navbar-icon-contacts"];
    UIBarButtonItem *button = [[UIBarButtonItem alloc] initWithImage: icon landscapeImagePhone: icon style:UIBarButtonItemStylePlain target: self action:@selector(contactsButtonPressed:)];
    return button;
}

- (void) setNavigationBarBackgroundWithLines {
    UINavigationBar *bar = [self.navigationController navigationBar];
    [bar setBackgroundImage: [AssetStore stretchableImageNamed: @"navbar_bg_with_lines" withLeftCapWidth: 65 topCapHeight: 0] forBarMetrics: UIBarMetricsDefault];
}

- (void) setNavigationBarBackgroundPlain {
    [self.navigationController.navigationBar setBackgroundImage: [AssetStore stretchableImageNamed: @"navbar_bg_plain" withLeftCapWidth: 5 topCapHeight: 0] forBarMetrics: UIBarMetricsDefault];
}

- (IBAction) menuButtonPressed:(id)sender {
    [self.menuContainerViewController toggleLeftSideMenuCompletion:^{}];
}

- (IBAction) contactsButtonPressed:(id)sender {
    [self.menuContainerViewController toggleRightSideMenuCompletion:^{}];
}

- (MFSideMenuContainerViewController*) menuContainerViewController {
    return (MFSideMenuContainerViewController*)self.navigationController.parentViewController;
}

@end