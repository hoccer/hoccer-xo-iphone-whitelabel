//
//  HXOTheme.m
//  HoccerXO
//
//  Created by David Siegel on 25.02.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "HXOTheme.h"
#import "UIColor+HSBUtilities.h"
#import "UIColor+HexUtilities.h"

static HXOTheme * _currentTheme;

@implementation HXOTheme

#pragma mark - Applicationwide Colors

- (UIColor*) navigationBarBackgroundColor {
    return [UIColor colorWithRed: 37.0 / 255 green: 184.0 / 255 blue: 171.0 / 255 alpha: 1.0];
}

- (UIColor*) navigationBarTintColor {
    return [UIColor whiteColor];
}

#pragma mark - Message Color Schemes

- (UIColor*) messageBackgroundColorForScheme: (HXOBubbleColorScheme) scheme {
    switch (scheme) {
        case HXOBubbleColorSchemeIncoming:   return [UIColor colorWithRed: 0.902 green: 0.906 blue: 0.922 alpha: 1];
        case HXOBubbleColorSchemeSuccess:    return [UIColor colorWithRed: 0.224 green: 0.753 blue: 0.702 alpha: 1];
        case HXOBubbleColorSchemeInProgress: return [UIColor colorWithRed: 0.725 green: 0.851 blue: 0.839 alpha: 1];
        case HXOBubbleColorSchemeFailed:     return [UIColor colorWithRed: 0.741 green: 0.224 blue: 0.208 alpha: 1];
    }
}

- (UIColor*) messageTextColorForScheme: (HXOBubbleColorScheme) scheme {
    switch (scheme) {
        case HXOBubbleColorSchemeIncoming:
            return [UIColor blackColor];
        case HXOBubbleColorSchemeSuccess:
        case HXOBubbleColorSchemeInProgress:
        case HXOBubbleColorSchemeFailed:
            return [UIColor whiteColor];
    }
}

- (UIColor*) messageFooterTextColorForScheme: (HXOBubbleColorScheme) scheme {
    return [[self messageBackgroundColorForScheme: scheme] darken];
}

- (UIColor*) messageLinkColorForScheme: (HXOBubbleColorScheme) scheme {
    return [UIColor blueColor];
}

- (UIColor*) messageAttachmentTitleColorForScheme: (HXOBubbleColorScheme) scheme {
    return [self messageTextColorForScheme: scheme];
}

- (UIColor*) messageAttachmentSubtitleColorForScheme: (HXOBubbleColorScheme) scheme {
    switch (scheme) {
        case HXOBubbleColorSchemeIncoming:
            return [UIColor lightGrayColor];
        case HXOBubbleColorSchemeSuccess:
        case HXOBubbleColorSchemeInProgress:
        case HXOBubbleColorSchemeFailed:
            return [UIColor whiteColor];
    }
}

- (UIColor*) messageAttachmentIconTintColorForScheme: (HXOBubbleColorScheme) scheme {
    switch (scheme) {
        case HXOBubbleColorSchemeIncoming:
            return [UIColor colorWithRed: 0 green: 122.0 / 255 blue: 1 alpha: 1];
        case HXOBubbleColorSchemeSuccess:
        case HXOBubbleColorSchemeInProgress:
        case HXOBubbleColorSchemeFailed:
            return [UIColor whiteColor];
    }
}


#pragma mark - agnat land

+ (void) initialize {
    _currentTheme = [[HXOTheme alloc] init];
}

+ (id) theme {
    return _currentTheme;
}

- (void) setupAppearanceProxies {
    [[UINavigationBar appearance] setBarTintColor: self.navigationBarBackgroundColor];
    [[UINavigationBar appearance] setBarStyle:     UIBarStyleBlackTranslucent];
    [[UINavigationBar appearance] setTintColor:    self.navigationBarTintColor];
}

@end