//
//  MessageCell.h
//  HoccerTalk
//
//  Created by David Siegel on 14.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

@class AutoheightLabel;
@class InsetImageView;
@class BubbleView;
@class TalkMessage;

@interface MessageCell : UITableViewCell

@property (strong, nonatomic) IBOutlet AutoheightLabel *message;
@property (strong, nonatomic) IBOutlet InsetImageView *avatar;
@property (strong, nonatomic) IBOutlet BubbleView *bubble;

- (CGFloat) heightForMessage: (TalkMessage*) message;

@end
