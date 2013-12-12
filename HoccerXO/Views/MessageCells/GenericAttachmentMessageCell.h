//
//  GenericAttachmentMessageCell.h
//  HoccerXO
//
//  Created by David Siegel on 12.12.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "MessageCell.h"

@class GenericAttachmentSection;

@interface GenericAttachmentMessageCell : MessageCell

@property (nonatomic,readonly) GenericAttachmentSection * genericAttachmentSection;

@end
