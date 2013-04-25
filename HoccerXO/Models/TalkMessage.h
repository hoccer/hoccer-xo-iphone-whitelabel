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

#import "HXOModel.h"

@interface TalkMessage : HXOModel

@property (nonatomic, strong) NSString* body;
@property (nonatomic, strong) NSDate*   timeSent; // client time when message was sent, passed unchanged to receivers
@property (nonatomic, strong) NSDate*   timeReceived; // client time when message was received
@property (nonatomic, strong) NSDate*   timeAccepted; // server time stamp when message was accepted by the Server, passed on via Delivery
@property (nonatomic, strong) NSNumber* isOutgoing;
@property (nonatomic, strong) NSString* timeSection;
@property (nonatomic, strong) NSNumber* isRead;
@property (nonatomic, strong) NSString* messageId;
@property (nonatomic, strong) NSString* messageTag;

@property (nonatomic, strong) Contact*  contact;
@property (nonatomic, strong) Attachment * attachment;
@property (nonatomic, strong) NSMutableSet * deliveries;

@property (nonatomic, strong) NSData * cryptoKey;

@property (nonatomic) NSString* bodyCipherText;

@property (nonatomic) NSNumber *   timeSentMillis;
@property (nonatomic) NSNumber *   timeAcceptedMillis;


- (void) setupOutgoingEncryption;
- (NSString *)encryptString: (NSString *)string;
- (NSString *)decryptString: (NSString *)string;
- (NSData *)encrypt:(NSData *)data;
- (NSData *)decrypt:(NSData *)data;

@end
