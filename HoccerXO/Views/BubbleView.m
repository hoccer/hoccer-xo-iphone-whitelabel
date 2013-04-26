//
//  BubbleView.m
//  HoccerXO
//
//  Created by David Siegel on 04.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "BubbleView.h"

#import <QuartzCore/QuartzCore.h>

#import "AutoheightLabel.h"
#import "AssetStore.h"
#import "HXOMessage.h"
#import "AttachmentViewFactory.h"
#import "AttachmentView.h"

static const double kLeftBubbleCapLeft  = 11.0;
static const double kRightBubbleCapLeft = 4.0;
static const double kBubbleCapTop   = 32.0;
static const double kAttachmentPadding = 10;

@interface BubbleView ()

@property (strong, nonatomic) UIImageView * background;

@end

@implementation BubbleView

@synthesize attachmentView = _attachmentView;

- (id) initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder: aDecoder];
    if (self != nil) {  
        self.bubbleColor = self.backgroundColor;
        self.backgroundColor = [UIColor clearColor];

    }
    return self;
}

- (void) awakeFromNib {
    [super awakeFromNib];
    self.padding = UIEdgeInsetsMake(self.message.frame.origin.y,
                                    0.0,
                                    self.message.frame.origin.y,
                                    0.0);

    NSString * file = _pointingRight ? @"bubble-right" : @"bubble-left";
    UIImage * bubble = [AssetStore stretchableImageNamed: file withLeftCapWidth: _pointingRight ? kRightBubbleCapLeft : kLeftBubbleCapLeft topCapHeight:kBubbleCapTop];
    self.background = [[UIImageView alloc] initWithImage: bubble];
	//self.background.frame = self.frame;
    self.background.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self insertSubview: self.background atIndex: 0];

    CGRect of = self.message.frame;
    CGFloat d = kLeftBubbleCapLeft - kRightBubbleCapLeft;
    self.message.frame = CGRectMake(_pointingRight ? of.origin.x : of.origin.x + d, of.origin.y, of.size.width - d, of.size.height);
}

- (void) setAttachmentView: (AttachmentView*) view {
    if (_attachmentView != nil) {
        [_attachmentView removeFromSuperview];
    }
    _attachmentView = view;
    if (_attachmentView != nil) {
        // XXX
        _attachmentView.contentMode = UIViewContentModeScaleAspectFit;
        CGFloat aspect = ((UIImageView*)_attachmentView).frame.size.height / ((UIImageView*)_attachmentView).frame.size.width;
        _attachmentView.frame = CGRectMake(self.message.frame.origin.x, self.message.frame.origin.y + self.message.frame.size.height + kAttachmentPadding,
                                           self.message.frame.size.width, self.message.frame.size.width * aspect);
        [self addSubview: view];
        view.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    }
    [self setNeedsLayout];
}

- (CGSize) sizeThatFits:(CGSize)size {
    // TODO: get rit of awkward + 5
    CGFloat height = self.message.frame.size.height + self.padding.top + self.padding.bottom + 5;
    if (self.attachmentView != nil) {
        height += kAttachmentPadding + self.attachmentView.frame.size.height;
    }
    return CGSizeMake(self.frame.size.width, height);
}

- (void) layoutSubviews {
    [super layoutSubviews];
    [self sizeToFit];
    self.background.frame = CGRectMake(0.0, 0.0, self.frame.size.width, self.frame.size.height);
}

- (CGFloat) heightForMessage: (HXOMessage*) message {
    CGFloat height = self.padding.top + [self.message calculateSize: message.body].height + self.padding.bottom;
    if (message.attachment != nil) {
        height += kAttachmentPadding + [AttachmentViewFactory heightOfAttachmentView: message.attachment withViewOfWidth: self.message.frame.size.width];
    }
    return height;
}

- (void) setState:(BubbleState)state {
    _state = state;
    NSString * stateString = nil;
    switch (state) {
        case BubbleStateInTransit:
            stateString = @"-in_transit";
            break;
        case BubbleStateDelivered:
            stateString = @"";
            break;
        case BubbleStateFailed:
            stateString = @"-failed";
            break;
    }
    NSString * assetName = [NSString stringWithFormat: @"bubble-%@%@", _pointingRight ? @"right" : @"left", stateString];
    self.background.image =[AssetStore stretchableImageNamed: assetName withLeftCapWidth: _pointingRight ? kRightBubbleCapLeft : kLeftBubbleCapLeft topCapHeight:kBubbleCapTop];
}
@end