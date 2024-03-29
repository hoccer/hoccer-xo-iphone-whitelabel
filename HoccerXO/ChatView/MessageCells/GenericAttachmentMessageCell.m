//
//  GenericAttachmentMessageCell.m
//  HoccerXO
//
//  Created by David Siegel on 12.12.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "GenericAttachmentMessageCell.h"
#import "GenericAttachmentSection.h"

@implementation GenericAttachmentMessageCell

- (void) commonInit {
    [super commonInit];
    _attachmentSection = [[GenericAttachmentSection alloc] initWithFrame:CGRectMake(0, 0, self.bubbleWidth, 0)];
    [self addSection: self.attachmentSection];
}

@end
