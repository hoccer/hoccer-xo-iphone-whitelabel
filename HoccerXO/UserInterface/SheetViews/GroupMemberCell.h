//
//  GroupMemberCell.h
//  HoccerXO
//
//  Created by David Siegel on 08.04.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "DatasheetCell.h"

@class AvatarView;

@interface GroupMemberCell : DatasheetCell

@property (nonatomic, readonly) AvatarView * avatar;
@property (nonatomic, readonly) UILabel    * statusLabel;

@end
