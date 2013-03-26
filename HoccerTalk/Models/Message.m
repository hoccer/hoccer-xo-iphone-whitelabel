//
//  Message.m
//  HoccerTalk
//
//  Created by David Siegel on 12.02.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "Message.h"

@implementation Message

@dynamic isOutgoing;
@dynamic body;
@dynamic timeStamp;
@dynamic timeSection;
@dynamic isRead;
@dynamic messageId;
@dynamic messageTag;

@dynamic contact;
@dynamic attachment;
@dynamic deliveries;

- (NSDictionary*) rpcKeys {
    return @{ @"body": @"body",
              @"messageId": @"messageId"
            };
}

@end
