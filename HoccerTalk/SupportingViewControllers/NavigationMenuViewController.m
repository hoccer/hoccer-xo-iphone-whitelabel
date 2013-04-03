//
//  NavigationMenuViewController.m
//  HoccerTalk
//
//  Created by David Siegel on 26.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "NavigationMenuViewController.h"
#import "MFSideMenu.h"
#import "../iOSVersionChecks.h"

@interface NavigationMenuViewController ()
{
    NSArray * _menuItems;
    NSMutableDictionary * _viewControllers;
}
@end

@implementation NavigationMenuViewController

- (id) initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder: aDecoder];
    if (self != nil) {
        _viewControllers = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void) viewDidLoad {
    _menuItems = @[ @{ @"title": NSLocalizedString(@"Chats", @"Navigation Menu Item"),
                       @"icon": @"navigation_button_chats",
                       @"storyboardId": @"conversationViewController"
                    },
                    @{ @"title": NSLocalizedString(@"Profile", @"Navigation Menu Item"),
                       @"icon": @"navigation_button_profile",
                       @"storyboardId": @"profileViewController"
                    },
                    @{ @"title": NSLocalizedString(@"Settings", @"Navigation Menu Item"),
                       @"icon": @"navigation_button_settings",
                       @"storyboardId": @"settingsViewController"
                    },
                    @{ @"title": NSLocalizedString(@"Tutorial", @"Navigation Menu Item"),
                       @"icon": @"navigation_button_tutorial",
                       @"storyboardId": @"tutorialViewController"
                    },
                    @{ @"title": NSLocalizedString(@"About", @"Navigation Menu Item"),
                       @"icon": @"navigation_button_about",
                       @"storyboardId": @"aboutViewController"
                    }
                   ];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];
    if([self.tableView indexPathForSelectedRow] == nil) {
        NSIndexPath *indexPath=[NSIndexPath indexPathForRow:0 inSection:0];
        [self.tableView selectRowAtIndexPath:indexPath animated:YES  scrollPosition:UITableViewScrollPositionBottom];
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_menuItems count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"6.0") ?
        [tableView dequeueReusableCellWithIdentifier: @"navigationMenuCell" forIndexPath:indexPath] :
        [tableView dequeueReusableCellWithIdentifier: @"navigationMenuCell"];
    if (cell.backgroundView == nil) {
        cell.backgroundView = [[UIImageView alloc] initWithImage: [[UIImage imageNamed: @"contact_cell_bg"] resizableImageWithCapInsets: UIEdgeInsetsMake(0, 0, 0, 0)]];
        cell.backgroundView.frame = cell.frame;
        cell.selectedBackgroundView = [[UIImageView alloc] initWithImage: [[UIImage imageNamed: @"contact_cell_bg_selected"] resizableImageWithCapInsets: UIEdgeInsetsMake(0, 0, 0, 0)]];
        cell.selectedBackgroundView.frame = cell.frame;
    }
    cell.textLabel.text = _menuItems[indexPath.row][@"title"];
    cell.imageView.image = [UIImage imageNamed: _menuItems[indexPath.row][@"icon"]];

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString * storyboardId =  _menuItems[indexPath.row][@"storyboardId"];
    UIViewController * viewController = [self getViewControllerByStoryboardId: storyboardId];
    if ( ! [_menuItems[indexPath.row][@"title"] isEqualToString: @"Chats"]) {
        viewController.title = _menuItems[indexPath.row][@"title"];
    }
    NSArray *controllers = [NSArray arrayWithObject: viewController];
    [self.sideMenu.navigationController setViewControllers: controllers animated: NO];
    [self.sideMenu setMenuState:MFSideMenuStateClosed];
}

- (void) cacheViewController: (UIViewController*) viewController withStoryboardId: (NSString*) storyboardId{
    _viewControllers[storyboardId] = viewController;
}

- (UIViewController*) getViewControllerByStoryboardId: (NSString*) storyboardID {
    if (_viewControllers[storyboardID] != nil) {
        return _viewControllers[storyboardID];
    }
    UIViewController * vc = _viewControllers[storyboardID] = [self.storyboard instantiateViewControllerWithIdentifier: storyboardID];
    return vc;
}

@end
