//
//  DatasheetViewController.m
//  HoccerXO
//
//  Created by David Siegel on 21.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "DatasheetViewController.h"

#import "DatasheetTextInputCell.h"
#import "DatasheetKeyValueCell.h"
#import "DatasheetActionCell.h"
#import "DatasheetFooterTextView.h"

extern const CGFloat kHXOGridSpacing;

@interface DatasheetViewController ()

@end

@interface InspectionObject : NSObject

@property (nonatomic,strong) NSString * nickname;

@end

@implementation InspectionObject
@end

@implementation DatasheetViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    [self registerCellClass: [DatasheetTextInputCell class]];
    [self registerCellClass: [DatasheetKeyValueCell class]];
    [self registerCellClass: [DatasheetActionCell class]];

    [self registerHeaderFooterViewClass: [DatasheetFooterTextView class]];

    self.dataSheetController.delegate = self;

    InspectionObject * o = [[InspectionObject alloc] init];
    o.nickname = @"Icke";
    self.dataSheetController.inspectedObject = o;

    self.tableView.contentInset = UIEdgeInsetsMake(-1, 0, 0, 0);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void) configureCell: (DatasheetCell*) cell withItem: (DatasheetItem*) item forRowAtIndexPath: (NSIndexPath*) indexPath {
    cell.titleLabel.text = item.title;
    cell.delegate = self;
    if ([cell respondsToSelector: @selector(valueView)]) {
        id valueView = [(id)cell valueView];
        [valueView setText: item.currentValue];
        if ([valueView respondsToSelector:@selector(setPlaceholder:)]) {
            [valueView setPlaceholder: item.placeholder];
        }
        if ([valueView respondsToSelector:@selector(setEnabled:)]) {
            [valueView setEnabled: item.isEnabled];
        }
    }
}

#pragma mark - Table View Delegate & Data Source

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return self.dataSheetController.currentItems.count;
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[self.dataSheetController.currentItems[section] items] count];
}

- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DatasheetItem * item = [self.dataSheetController itemForIndexPath: indexPath];
    DatasheetCell * cell = [self.tableView dequeueReusableCellWithIdentifier: item.cellIdentifier];
    [self configureCell: cell withItem: item forRowAtIndexPath: indexPath];
    return cell;
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    DatasheetItem * item = [self.dataSheetController itemForIndexPath: indexPath];
    DatasheetCell * prototype = (DatasheetCell*)[self prototypeCellForIdentifier: item.cellIdentifier];
    [self configureCell: prototype withItem: item forRowAtIndexPath: indexPath];
    return [prototype.contentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height;
}

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return 1;
    }
    return 4 * kHXOGridSpacing;
}

- (void) tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([cell respondsToSelector: @selector(setDelegate:)]) {
        [(id)cell setDelegate: nil];
    }
}

#pragma mark - Navigation Buttons

- (void) updateNavigationButtons {
    UIBarButtonItem * rightButton = nil;
    UIBarButtonItem * leftButton = nil;
    if (self.dataSheetController.isEditable) {
        if (self.dataSheetController.isEditing) {
            rightButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemDone target: self action:@selector(rightButtonPressed:)];

            leftButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemCancel target: self action: @selector(leftButtonPressed:)];
        } else {
            rightButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem: UIBarButtonSystemItemEdit target: self action:@selector(rightButtonPressed:)];
        }
    }
    self.navigationItem.rightBarButtonItem = rightButton;
    self.navigationItem.leftBarButtonItem = leftButton;
}

- (void) rightButtonPressed: (id) sender {
    [self.dataSheetController editModeChanged: sender];
    [self updateNavigationButtons];
}

- (void) leftButtonPressed: (id) sender {
    [self.dataSheetController cancelEditing: sender];
    //[self.dataSheetController editModeChanged: sender];
    [self updateNavigationButtons];
}

#pragma mark - Datasheet Controller Delegate

- (void) controllerDidChangeObject:(DatasheetController *)controller {
    [self updateNavigationButtons];
}

- (void) controllerWillChangeContent: (DatasheetController*) controller {
    [self.tableView beginUpdates];
}

- (void) controller: (DatasheetController*) controller didChangeObject: (NSIndexPath*) indexPath forChangeType: (DatasheetChangeType) type newIndexPath: (NSIndexPath*) newIndexPath {
    switch(type) {
        case DatasheetChangeInsert:
            [self.tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;

        case DatasheetChangeDelete:
            [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;

        case DatasheetChangeUpdate:
            [self configureCell: (DatasheetCell*)[self.tableView cellForRowAtIndexPath:indexPath] withItem: [controller itemForIndexPath: indexPath] forRowAtIndexPath: indexPath];
            break;
        default:
            break;
    }
}

- (void) controller: (DatasheetController*) controller didChangeSection: (NSIndexPath*) indexPath forChangeType: (DatasheetChangeType) type {
    switch(type) {
        case DatasheetChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex: indexPath.section] withRowAnimation:UITableViewRowAnimationFade];
            break;

        case DatasheetChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex: indexPath.section] withRowAnimation:UITableViewRowAnimationFade];
            break;
        default:
            break;
    }

}

- (void) controllerDidChangeContent: (DatasheetController*) controller {
    [self.tableView endUpdates];
}

#pragma mark - Datasheet Cell Delegate

- (void) valueDidChange:(DatasheetCell *)cell valueView:(id)valueView {
    NSIndexPath * indexPath = [self.tableView indexPathForCell: cell];
    DatasheetItem * item = [self.dataSheetController itemForIndexPath: indexPath];
    item.currentValue = [valueView text];
}


@end
