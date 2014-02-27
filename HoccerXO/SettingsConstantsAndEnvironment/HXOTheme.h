//
//  HXOTheme.h
//  HoccerXO
//
//  Created by David Siegel on 25.02.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MessageSection.h"

@interface HXOTheme : NSObject

+ (id) theme;

@property (nonatomic,readonly) UIColor * navigationBarBackgroundColor;
@property (nonatomic,readonly) UIColor * navigationBarTintColor;

- (UIColor*) messageBackgroundColorForScheme: (HXOBubbleColorScheme) scheme;
- (UIColor*) messageTextColorForScheme:       (HXOBubbleColorScheme) scheme;
- (UIColor*) messageSubtitleColorForScheme:   (HXOBubbleColorScheme) scheme;
- (UIColor*) messageLinkColorForScheme:       (HXOBubbleColorScheme) scheme;

- (void) setupAppearanceProxies;

@end
