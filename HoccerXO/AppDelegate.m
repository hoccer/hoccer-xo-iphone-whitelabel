//
//  AppDelegate.m
//  HoccerXO
//
//  Created by David Siegel on 12.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "AppDelegate.h"

#import "HXOConfig.h"

#import "ConversationViewController.h"
#import "Contact.h"
#import "HXOMessage.h"
#import "AssetStore.h"
#import "NavigationMenuViewController.h"
#import "ContactQuickListViewController.h"
#import "NSString+UUID.h"
#import "NSData+HexString.h"
#import "InviteCodeViewController.h"
#import "HXOUserDefaults.h"
#import "Environment.h"
#import "UserProfile.h"

#import "MFSideMenu.h"

@implementation AppDelegate

@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;

@synthesize userAgent;

- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [self seedRand];
    _backgroundTask = UIBackgroundTaskInvalid;
    //[[UserProfile sharedProfile] deleteCredentials];

    return YES;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    NSLog(@"Running with environment %@", [Environment sharedEnvironment].currentEnvironment);

    [[UIApplication sharedApplication] registerForRemoteNotificationTypes:(UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert)];

    self.chatBackend = [[HXOBackend alloc] initWithDelegate: self];

    UIStoryboard *storyboard = nil;
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;
        self.navigationController = [splitViewController.viewControllers lastObject];
        splitViewController.delegate = (id)self.navigationController.topViewController;
        UINavigationController *masterNavigationController = splitViewController.viewControllers[0];
        self.conversationViewController = (ConversationViewController *)masterNavigationController.topViewController;
        storyboard = [UIStoryboard storyboardWithName:@"MainStoryboard_iPad" bundle:[NSBundle mainBundle]];
    } else {
        self.navigationController = (UINavigationController *)self.window.rootViewController;
        self.conversationViewController = (ConversationViewController *)self.navigationController.topViewController;
        storyboard = [UIStoryboard storyboardWithName:@"MainStoryboard_iPhone" bundle:[NSBundle mainBundle]];
    }
    // TODO: be lazy
    self.conversationViewController.managedObjectContext = self.managedObjectContext;

    [self customizeNavigationBar];

    [self setupSideMenusWithStoryboard: storyboard andConversationViewController: self.conversationViewController];

    if ([[HXOUserDefaults standardUserDefaults] boolForKey: kHXOFirstRunDone]) {
        [self setupDone: NO];
    }

    if (launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey] != nil) {
        // TODO: jump to conversation
        NSLog(@"Launched by remote notification.");
    }

    return YES;
}

- (void) seedRand {
    unsigned seed;
    SecRandomCopyBytes(kSecRandomDefault, sizeof seed, (uint8_t*)&seed);
    srand(seed);
}

- (void) customizeNavigationBar {
    // TODO: handle other bar metrics?
    // this is visible in the message/mail compose view controllers
    [[UINavigationBar appearance] setBackgroundImage: [UIImage imageNamed: @"navbar_bg_plain"] forBarMetrics: UIBarMetricsDefault];

    UIImage * navigationButtonBackground = [[UIImage imageNamed: @"navbar-btn-default"] stretchableImageWithLeftCapWidth: 4 topCapHeight: 0];
    [[UIBarButtonItem appearance] setBackgroundImage: navigationButtonBackground forState: UIControlStateNormal barMetrics: UIBarMetricsDefault];
    UIImage * navigationBackButtonBackground = [[UIImage imageNamed: @"navbar-btn-back"] stretchableImageWithLeftCapWidth: 17 topCapHeight: 0];
    [[UIBarButtonItem appearance] setBackButtonBackgroundImage: navigationBackButtonBackground forState: UIControlStateNormal barMetrics: UIBarMetricsDefault];
}

- (void) setupSideMenusWithStoryboard: (UIStoryboard*) storyboard andConversationViewController: (ConversationViewController*) controller {
    ContactQuickListViewController * contactListViewController = [storyboard instantiateViewControllerWithIdentifier:@"contactListViewController"];
    NavigationMenuViewController * navigationMenuViewController = [storyboard instantiateViewControllerWithIdentifier:@"navigationMenuViewController"];
    self.navigationController.sideMenu = [MFSideMenu menuWithNavigationController:self.navigationController
                                                           leftSideMenuController:navigationMenuViewController
                                                          rightSideMenuController:contactListViewController];
    self.navigationController.sideMenu.menuWidth = 256;
    self.navigationController.sideMenu.shadowOpacity = 1.0;
    self.navigationController.sideMenu.menuStateEventBlock = ^(MFSideMenuStateEvent event) {
        switch (event) {
            case MFSideMenuStateEventMenuWillOpen:
                break;
            case MFSideMenuStateEventMenuDidOpen:
                break;
            case MFSideMenuStateEventMenuWillClose:
                [contactListViewController.view endEditing: YES];
                break;
            case MFSideMenuStateEventMenuDidClose:
                break;
        }
    };

    [navigationMenuViewController cacheViewController: controller withStoryboardId: @"conversationViewController"];
    navigationMenuViewController.sideMenu = self.navigationController.sideMenu;

    contactListViewController.sideMenu = self.navigationController.sideMenu;
    contactListViewController.conversationViewController = controller;

    self.navigationController.delegate = navigationMenuViewController;
}

- (void) setupDone: (BOOL) performRegistration {
    NSLog(@"setupDone");
    [self.chatBackend start: performRegistration];
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    [self saveContext];
    [self updateUnreadMessageCountAndStop];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    [self.chatBackend start: NO];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Saves changes in the application's managed object context before the application terminates.
    [self saveContext];
}

#pragma mark - Core Data stack

- (void)saveContext
{
    NSError *error = nil;
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    if (managedObjectContext != nil) {
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    }
}

- (void)saveDatabase
{
    NSString * savePolicy = [[HXOUserDefaults standardUserDefaults] objectForKey: kHXOSaveDatabasePolicy];
    if ([savePolicy isEqualToString:kHXOSaveDatabasePolicyPerMessage]) {
        // NSLog(@"Saving database");
        NSDate * start = [[NSDate alloc] init];
        [self saveContext];
        double elapsed = -[start timeIntervalSinceNow];
        NSLog(@"Saving database took %f secs", elapsed);
    }
}

// Returns the managed object context for the application.
// If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        _managedObjectContext = [[NSManagedObjectContext alloc] init];
        [_managedObjectContext setPersistentStoreCoordinator:coordinator];
        [_managedObjectContext setUndoManager: nil];
    }
    return _managedObjectContext;
}

// Returns the managed object model for the application.
// If the model doesn't already exist, it is created from the application's model.
- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"HoccerXO" withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}

// Returns the persistent store coordinator for the application.
// If the coordinator doesn't already exist, it is created and the application's store added to it.
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"HoccerXO.sqlite"];
    
    NSError *error = nil;

    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {
        /*
         Replace this implementation with code to handle the error appropriately.
         
         abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
         
         Typical reasons for an error here include:
         * The persistent store is not accessible;
         * The schema for the persistent store is incompatible with current managed object model.
         Check the error message to determine what the actual problem was.
         
         
         If the persistent store is not accessible, there is typically something wrong with the file path. Often, a file URL is pointing into the application's resources directory instead of a writeable directory.
         
         If you encounter schema incompatibility errors during development, you can reduce their frequency by:
         * Simply deleting the existing store:
         [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil]
         
         * Performing automatic lightweight migration by passing the following dictionary as the options parameter:
         @{NSMigratePersistentStoresAutomaticallyOption:@YES, NSInferMappingModelAutomaticallyOption:@YES}
         
         Lightweight migration will only work for a limited set of schema changes; consult "Core Data Model Versioning and Data Migration Programming Guide" for details.
         
         */
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    
    return _persistentStoreCoordinator;
}

#pragma mark - Application's Documents directory

// Returns the URL to the application's Documents directory.
- (NSURL *)applicationDocumentsDirectory {
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

#pragma mark - Application's user Agent string for http request

- (NSString *) userAgent {
	if (userAgent == nil) {
        userAgent = [NSString stringWithFormat: @"%@ %@ / %@ / %@ %@",
                     [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"],
                     [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"],
                     [UIDevice currentDevice].model,
                     [UIDevice currentDevice].systemName,
                     [UIDevice currentDevice].systemVersion];
	}
	return userAgent;
}

#pragma mark - Message Count Handling

- (NSUInteger) unreadMessageCount {
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    fetchRequest.entity = [NSEntityDescription entityForName: [HXOMessage entityName] inManagedObjectContext: self.managedObjectContext];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"isRead == NO"];

    NSError *error = nil;
    NSUInteger numberOfRecords = [self.managedObjectContext countForFetchRequest:fetchRequest error:&error];

    if (numberOfRecords == NSNotFound) {
        NSLog(@"ERROR: unreadMessageCount: failed to count unread messages: %@", error);
        abort();
    }
    return numberOfRecords;
}

- (void) updateUnreadMessageCountAndStop {
    NSUInteger unreadMessages = [self unreadMessageCount];
    [UIApplication sharedApplication].applicationIconBadgeNumber = unreadMessages;
    _backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [self.chatBackend stop];
        [[UIApplication sharedApplication] endBackgroundTask:_backgroundTask];
        _backgroundTask = UIBackgroundTaskInvalid;
    }];

    // Start the long-running task and return immediately.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.chatBackend hintApnsUnreadMessage: unreadMessages handler: ^(BOOL success){
            NSLog(@"updated unread message count: %@", success ? @"success" : @"failed");
            [self.chatBackend stop];
        }];
    });
}

#pragma mark - Apple Push Notifications

- (void)application:(UIApplication *)app didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    if (deviceToken != nil) {
        // NSLog(@"got APNS deviceToken: %@ ", [deviceToken hexadecimalString]);
        // TODO: do we need this?
        //self.registered = YES;
        NSString * tokenString = [deviceToken hexadecimalString];
        [[HXOUserDefaults standardUserDefaults] setValue: tokenString forKey: kHXOAPNDeviceToken];
        [self.chatBackend gotAPNSDeviceToken: tokenString];
    } else {
        NSLog(@"ERROR: APN device token is nil");
    }
}

- (void)application:(UIApplication *)app didFailToRegisterForRemoteNotificationsWithError:(NSError *)err {
    NSLog(@"Error in APN registration. Error: %@", err);
}

/* nothing to do here ... ?
- (void) application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
}
*/

#pragma mark - URL Handling

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
    if ([[url scheme] isEqualToString:@"hctalk"]) {
        // TODO: input verification
        [self.chatBackend acceptInvitation: url.host];
    }
    return NO;
}

- (void) didPairWithStatus: (BOOL) success { // pregnant...
    [self showPairingAlert: success];
}

- (void) showPairingAlert: (BOOL) success {
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

    // Work around for an issue with the side menu. When opening an alert while the side menu is open or in
    // transition a matrix becomes singular and the side menus dissappear in numeric nirvana. We're going to
    // make the side menu a plain menu anyway. No buttons or other user interaction. So, a workaround is ok for now.
    [NSTimer scheduledTimerWithTimeInterval: 1.0 target: alert selector: @selector(show) userInfo: nil repeats: NO];
}


#pragma mark - Hoccer Talk Delegate


- (NSString*) apnDeviceToken {
    return [[HXOUserDefaults standardUserDefaults] stringForKey: kHXOAPNDeviceToken];
}

- (void) backendDidStop {
    if (_backgroundTask != UIBackgroundTaskInvalid) {
        NSLog(@"backendDidStop: done with background task ... good night");
        [[UIApplication sharedApplication] endBackgroundTask: _backgroundTask];
        _backgroundTask = UIBackgroundTaskInvalid;
    }
}

@end
