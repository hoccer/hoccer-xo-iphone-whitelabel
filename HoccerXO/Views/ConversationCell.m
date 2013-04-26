//
//  ContactCell.m
//  HoccerXO
//
//  Created by David Siegel on 07.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "ConversationCell.h"

#import <QuartzCore/QuartzCore.h>

#import "AssetStore.h"

@interface ConversationCell ()

@end

@implementation ConversationCell

- (void) awakeFromNib {
    [super awakeFromNib];
    [self engraveLabel: self.latestMessageLabel];
    [self engraveLabel: self.latestMessageTimeLabel];
}

@end