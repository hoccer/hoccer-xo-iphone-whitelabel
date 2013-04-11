//
//  UserDefaultsControllerViewController.m
//  HoccerTalk
//
//  Created by David Siegel on 10.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "UserDefaultsViewController.h"
#import "RadialGradientView.h"

@interface UserDefaultsViewController ()

@end

@implementation UserDefaultsViewController

- (id) initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder: aDecoder];
    if (self != nil) {
        [self commonInit];
    }
    return self;
}

- (void) commonInit {
    _prototypes = [[NSMutableDictionary alloc] init];
    _items = [self populateItems];
}

- (void) viewDidLoad {
    self.tableView.backgroundView = [[RadialGradientView alloc] initWithFrame: self.tableView.frame];
}

- (UITableViewCell*) prototypeCellOfClass:(id)cellClass {
    if (_prototypes[cellClass] == nil) {
        [self registerNibForCellClass: cellClass];
        _prototypes[cellClass] = [self.tableView dequeueReusableCellWithIdentifier: [cellClass reuseIdentifier]];
    }
    return _prototypes[cellClass];
}

- (UITableViewCell*) dequeueReusableCellOfClass:(id)cellClass forIndexPath:(NSIndexPath *)indexPath {
    if (_prototypes[cellClass] == nil) {
        [self registerNibForCellClass: cellClass];
        _prototypes[cellClass] = [self.tableView dequeueReusableCellWithIdentifier: [cellClass reuseIdentifier]];
    }
    return [self.tableView dequeueReusableCellWithIdentifier: [cellClass reuseIdentifier] forIndexPath: indexPath];
}

- (void) registerNibForCellClass: (id) cellClass {
    UIUserInterfaceIdiom userInterfaceIdiom = [[UIDevice currentDevice] userInterfaceIdiom];
    NSString * userInterfaceIdiomString = userInterfaceIdiom == UIUserInterfaceIdiomPad ? @"iPad" : @"iPhone";
    NSString * nibName = [NSString stringWithFormat: @"%@_%@", [cellClass reuseIdentifier], userInterfaceIdiomString];
    UINib * nib = [UINib nibWithNibName: nibName bundle: [NSBundle mainBundle]];
    [self.tableView registerNib: nib forCellReuseIdentifier: [cellClass reuseIdentifier]];
}

- (NSArray*) populateItems {
    return nil;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return _items.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_items[section] count];
}

@end