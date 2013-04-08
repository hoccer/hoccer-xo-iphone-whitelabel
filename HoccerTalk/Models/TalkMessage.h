//
//  Message.h
//  HoccerTalk
//
//  Created by David Siegel on 12.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <CoreData/CoreData.h>

@class Contact;
@class Attachment;
@class Delivery;

#import "HoccerTalkModel.h"

@interface TalkMessage : HoccerTalkModel

@property (nonatomic, strong) NSString* body;
@property (nonatomic, strong) NSDate*   timeStamp;
@property (nonatomic, strong) NSNumber* isOutgoing;
@property (nonatomic, strong) NSString* timeSection;
@property (nonatomic, strong) NSNumber* isRead;
@property (nonatomic, strong) NSString* messageId;
@property (nonatomic, strong) NSString* messageTag;

@property (nonatomic, strong) Contact*  contact;
@property (nonatomic, strong) Attachment * attachment;
@property (nonatomic, strong) NSMutableSet * deliveries;

@end