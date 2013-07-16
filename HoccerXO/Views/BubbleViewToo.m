//
//  BubbleViewToo.m
//  HoccerXO
//
//  Created by David Siegel on 10.07.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "BubbleViewToo.h"

#import <QuartzCore/QuartzCore.h>
#import <CoreText/CoreText.h>

#import "InsetImageView.h"
#import "HXOLinkyLabel.h"

static const CGFloat kHXOBubblePadding = 8;
static const CGFloat kHXOBubbleMinimumHeight = 48;
static const CGFloat kHXOBubblePointOffset = 8;

@implementation BubbleViewToo

- (id) init {
    self = [super init];
    if (self != nil) {
        [self commonInit];
    }
    return self;
}

- (id) initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle: style reuseIdentifier: reuseIdentifier];
    if (self != nil) {
        [self commonInit];
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (id) initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder: aDecoder];
    if (self != nil) {
        [self commonInit];
    }
    return self;
}

- (void) commonInit {
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.contentMode = UIViewContentModeRedraw;
    self.backgroundColor = [UIColor clearColor];

    _avatar = [[InsetImageView alloc] initWithFrame: CGRectMake(kHXOBubblePadding, kHXOBubblePadding, kHXOBubbleMinimumHeight, kHXOBubbleMinimumHeight)];
    [self addSubview: _avatar];

    self.colorScheme = HXOBubbleColorSchemeWhite;
    self.messageDirection = HXOMessageDirectionOutgoing;

    self.layer.shouldRasterize = YES;
    self.layer.shadowOffset = CGSizeMake(0.1, 2.1);
    [self configureDropShadow];

}

- (void) setColorScheme:(HXOBubbleColorScheme)colorScheme {
    _colorScheme = colorScheme;
    [self configureDropShadow];
}

- (void) setMessageDirection:(HXOMessageDirection)messageDirection {
    _messageDirection = messageDirection;
    CGRect frame = _avatar.frame;
    if (messageDirection == HXOMessageDirectionIncoming) {
        frame.origin.x = kHXOBubblePadding;
        _avatar.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
    } else {
        frame.origin.x = self.bounds.size.width - frame.size.width - kHXOBubblePadding;
        _avatar.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
    }
    _avatar.frame = frame;
}

- (void) layoutSubviews {
    [super layoutSubviews];
    self.layer.shadowPath = [self createBubblePath].CGPath;
}

- (void) configureDropShadow {
    BOOL hasShadow = self.colorScheme != HXOBubbleColorSchemeEtched;
    self.layer.shadowColor = hasShadow ? [UIColor blackColor].CGColor : NULL;
    self.layer.shadowOpacity = hasShadow ? 0.15 : 0;
    self.layer.shadowRadius = hasShadow ? 2 : 0;
}

- (void)drawRect:(CGRect)rect {
    //// General Declarations
    CGContextRef context = UIGraphicsGetCurrentContext();

    BOOL isEtched = self.colorScheme == HXOBubbleColorSchemeEtched;

    //// Color Declarations
    UIColor* bubbleFillColor = [self fillColor];
    UIColor* bubbleStrokeColor = [self strokeColor];
    CGFloat innerShadowAlpha = isEtched ? 0.15 : 0.07;
    UIColor* bubbleInnerShadowColor = [UIColor colorWithRed: 0 green: 0 blue: 0 alpha: innerShadowAlpha];

    //// Shadow Declarations
    UIColor* bubbleInnerShadow = bubbleInnerShadowColor;
    CGSize bubbleInnerShadowOffset = isEtched ? CGSizeMake(0.1, 2.1) : CGSizeMake(0.1, -2.1);
    CGFloat bubbleInnerShadowBlurRadius = isEtched ? 5 : 3;


    //// Bubble Drawing
    UIBezierPath* bubblePath = [self createBubblePath];
    
    CGContextSaveGState(context);
    [bubbleFillColor setFill];
    [bubblePath fill];

    ////// Bubble Inner Shadow
    CGRect bubbleBorderRect = CGRectInset([bubblePath bounds], -bubbleInnerShadowBlurRadius, -bubbleInnerShadowBlurRadius);
    bubbleBorderRect = CGRectOffset(bubbleBorderRect, -bubbleInnerShadowOffset.width, -bubbleInnerShadowOffset.height);
    bubbleBorderRect = CGRectInset(CGRectUnion(bubbleBorderRect, [bubblePath bounds]), -1, -1);

    UIBezierPath* bubbleNegativePath = [UIBezierPath bezierPathWithRect: bubbleBorderRect];
    [bubbleNegativePath appendPath: bubblePath];
    bubbleNegativePath.usesEvenOddFillRule = YES;

    CGContextSaveGState(context);
    {
        CGFloat xOffset = bubbleInnerShadowOffset.width + round(bubbleBorderRect.size.width);
        CGFloat yOffset = bubbleInnerShadowOffset.height;
        CGContextSetShadowWithColor(context,
                                    CGSizeMake(xOffset + copysign(0.1, xOffset), yOffset + copysign(0.1, yOffset)),
                                    bubbleInnerShadowBlurRadius,
                                    bubbleInnerShadow.CGColor);

        [bubblePath addClip];
        CGAffineTransform transform = CGAffineTransformMakeTranslation(-round(bubbleBorderRect.size.width), 0);
        [bubbleNegativePath applyTransform: transform];
        [[UIColor grayColor] setFill];
        [bubbleNegativePath fill];
    }
    CGContextRestoreGState(context);


    CGContextRestoreGState(context);

    if (self.colorScheme != HXOBubbleColorSchemeEtched && self.colorScheme != HXOBubbleColorSchemeWhite) {
        [self drawInnerGlow: context path: bubblePath];
    }

    [bubbleStrokeColor setStroke];
    bubblePath.lineWidth = 1;
    [bubblePath stroke];
}

- (void) drawInnerGlow: (CGContextRef) context path: (UIBezierPath*) path {
    UIColor * innerGlowColor = [UIColor colorWithWhite: 1.0 alpha: 0.3];

    CGContextSaveGState(context);

    path.lineWidth = 3;
    path.lineJoinStyle = kCGLineJoinRound;

    [path addClip];

    [innerGlowColor setStroke];
    [path stroke];

    CGContextRestoreGState(context);
}

- (UIBezierPath*) createBubblePath {
    UIBezierPath* bubblePath;
    CGRect frame = CGRectInset(self.bounds, kHXOBubblePadding, kHXOBubblePadding);
    CGFloat dx = kHXOBubbleMinimumHeight + kHXOBubblePadding;
    frame.size.width -= dx;
    if (self.messageDirection == HXOMessageDirectionOutgoing) {
        bubblePath = [self rightPointingBubblePathInRect: frame];
    } else {
        frame.origin.x += dx;
        bubblePath = [self leftPointingBubblePathInRect: frame];
    }
    return bubblePath;
}

- (UIBezierPath*) rightPointingBubblePathInRect: (CGRect) frame {
    UIBezierPath* bubblePath = [UIBezierPath bezierPath];
    [bubblePath moveToPoint: CGPointMake(CGRectGetMaxX(frame) - 7, CGRectGetMinY(frame) + 27.07)];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMaxX(frame) - 7, CGRectGetMaxY(frame) - 1.5)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 9, CGRectGetMaxY(frame)) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 7, CGRectGetMaxY(frame) - 0.4) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 7.9, CGRectGetMaxY(frame))];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMinX(frame) + 2, CGRectGetMaxY(frame))];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame), CGRectGetMaxY(frame) - 1.5) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 0.9, CGRectGetMaxY(frame)) controlPoint2: CGPointMake(CGRectGetMinX(frame), CGRectGetMaxY(frame) - 0.4)];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMinX(frame), CGRectGetMinY(frame) + 2)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 2, CGRectGetMinY(frame)) controlPoint1: CGPointMake(CGRectGetMinX(frame), CGRectGetMinY(frame) + 0.9) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 0.9, CGRectGetMinY(frame))];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMaxX(frame) - 9, CGRectGetMinY(frame))];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 7, CGRectGetMinY(frame) + 2) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 7.9, CGRectGetMinY(frame)) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 7, CGRectGetMinY(frame) + 0.9)];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMaxX(frame) - 7, CGRectGetMinY(frame) + 18.43)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 3.5, CGRectGetMinY(frame) + 20.01) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 7, CGRectGetMinY(frame) + 19.53) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 5.04, CGRectGetMinY(frame) + 20)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame), CGRectGetMinY(frame) + 18.43) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 2.04, CGRectGetMinY(frame) + 20.01) controlPoint2: CGPointMake(CGRectGetMaxX(frame), CGRectGetMinY(frame) + 19.53)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 7, CGRectGetMinY(frame) + 27.07) controlPoint1: CGPointMake(CGRectGetMaxX(frame), CGRectGetMinY(frame) + 22.71) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 2.99, CGRectGetMinY(frame) + 26.16)];
    [bubblePath closePath];

    return bubblePath;
}

- (UIBezierPath*) leftPointingBubblePathInRect: (CGRect) frame {
    UIBezierPath* bubblePath = [UIBezierPath bezierPath];
    [bubblePath moveToPoint: CGPointMake(CGRectGetMinX(frame) + 7, CGRectGetMinY(frame) + 27.07)];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMinX(frame) + 7, CGRectGetMaxY(frame) - 1.5)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 9, CGRectGetMaxY(frame)) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 7, CGRectGetMaxY(frame) - 0.4) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 7.9, CGRectGetMaxY(frame))];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMaxX(frame) - 2, CGRectGetMaxY(frame))];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame), CGRectGetMaxY(frame) - 1.5) controlPoint1: CGPointMake(CGRectGetMaxX(frame) - 0.9, CGRectGetMaxY(frame)) controlPoint2: CGPointMake(CGRectGetMaxX(frame), CGRectGetMaxY(frame) - 0.4)];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMaxX(frame), CGRectGetMinY(frame) + 2)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMaxX(frame) - 2, CGRectGetMinY(frame)) controlPoint1: CGPointMake(CGRectGetMaxX(frame), CGRectGetMinY(frame) + 0.9) controlPoint2: CGPointMake(CGRectGetMaxX(frame) - 0.9, CGRectGetMinY(frame))];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMinX(frame) + 9, CGRectGetMinY(frame))];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 7, CGRectGetMinY(frame) + 2) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 7.9, CGRectGetMinY(frame)) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 7, CGRectGetMinY(frame) + 0.9)];
    [bubblePath addLineToPoint: CGPointMake(CGRectGetMinX(frame) + 7, CGRectGetMinY(frame) + 18.43)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 3.5, CGRectGetMinY(frame) + 20.01) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 7, CGRectGetMinY(frame) + 19.53) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 5.04, CGRectGetMinY(frame) + 20)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame), CGRectGetMinY(frame) + 18.43) controlPoint1: CGPointMake(CGRectGetMinX(frame) + 2.04, CGRectGetMinY(frame) + 20.01) controlPoint2: CGPointMake(CGRectGetMinX(frame), CGRectGetMinY(frame) + 19.53)];
    [bubblePath addCurveToPoint: CGPointMake(CGRectGetMinX(frame) + 7, CGRectGetMinY(frame) + 27.07) controlPoint1: CGPointMake(CGRectGetMinX(frame), CGRectGetMinY(frame) + 22.71) controlPoint2: CGPointMake(CGRectGetMinX(frame) + 2.99, CGRectGetMinY(frame) + 26.16)];
    [bubblePath closePath];

    return bubblePath;
}

- (UIColor*) fillColor {
    switch (self.colorScheme) {
        case HXOBubbleColorSchemeWhite:
            return [UIColor whiteColor];
        case HXOBubbleColorSchemeBlue:
            return [UIColor colorWithRed: 0.855 green: 0.925 blue: 0.996 alpha: 1];
        case HXOBubbleColorSchemeEtched:
            return [UIColor colorWithWhite: 0.95 alpha: 1.0];
        case HXOBubbleColorSchemeRed:
            return [UIColor colorWithRed: 0.996 green: 0.796 blue: 0.804 alpha: 1];
        case HXOBubbleColorSchemeBlack:
            //return [UIColor colorWithRed: 0.19 green: 0.195 blue: 0.2 alpha: 1];
            return [UIColor colorWithPatternImage: [UIImage imageNamed:@"attachment_pattern"]];
    }
}

- (UIColor*) strokeColor {
    switch (self.colorScheme) {
        case HXOBubbleColorSchemeWhite:
            return [UIColor colorWithWhite: 0.75 alpha: 1.0];
        case HXOBubbleColorSchemeBlue:
            return [UIColor colorWithRed: 0.49 green: 0.663 blue: 0.792 alpha: 1];
        case HXOBubbleColorSchemeEtched:
            return [UIColor whiteColor];
        case HXOBubbleColorSchemeRed:
            return [UIColor colorWithRed: 0.792 green: 0.314 blue: 0.329 alpha: 1];
        case HXOBubbleColorSchemeBlack:
            return [UIColor colorWithRed: 0.19 green: 0.195 blue: 0.2 alpha: 1];
    }
}


@end

@implementation TextMessageCell

- (void) commonInit {
    [super commonInit];

    _label = [[HXOLinkyLabel alloc] init];
    _label.numberOfLines = 0;
    _label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _label.backgroundColor = [UIColor clearColor /* colorWithWhite: 0.9 alpha: 1.0*/];
    _label.font = [UIFont systemFontOfSize: 13.0];
    _label.lineBreakMode = NSLineBreakByWordWrapping;
    _label.shadowColor = [UIColor colorWithWhite: 1.0 alpha: 0.8];
    _label.shadowOffset = CGSizeMake(0, 1);
    [self addSubview: _label];
}

- (void) setText:(NSString *)text {
    _label.text = text;
    [self setNeedsLayout];
}

- (NSString*) text {
    return _label.text;
}

- (void) setColorScheme:(HXOBubbleColorScheme)colorScheme {
    [super setColorScheme: colorScheme];
    _label.textColor = [self textColorForColorScheme: colorScheme];
    _label.defaultTokenStyle = [self linkStyleForColorScheme: colorScheme];
}

- (void) layoutSubviews {
    [super layoutSubviews];
    _label.frame = [self textFrame];
    [_label sizeToFit];
    CGRect textFrame = _label.frame;
    textFrame.origin.y = 0.5 * (self.bounds.size.height - textFrame.size.height);
    NSUInteger numberOfLines = _label.currentNumberOfLines;
    if (numberOfLines == 1) {
        textFrame.origin.y -= 2;
    } else if (numberOfLines == 2) {
        textFrame.origin.y -= 1;
    }
    _label.frame = textFrame;
}

- (CGRect) textFrame {
    CGRect frame = CGRectInset(self.bounds, 2 * kHXOBubblePadding, 2 * kHXOBubblePadding);
    CGFloat dx = kHXOBubblePadding + kHXOBubbleMinimumHeight + kHXOBubblePointOffset;
    frame.size.width -= dx;
    if (self.messageDirection == HXOMessageDirectionIncoming) {
        frame.origin.x += dx;
    }
    return frame;
}

- (UIColor*) textColorForColorScheme: (HXOBubbleColorScheme) colorScheme {
    switch (colorScheme) {
        case HXOBubbleColorSchemeWhite:
            return [UIColor colorWithRed: 51.0/255 green: 51.0/255 blue: 51.0/255 alpha: 1.0];
        case HXOBubbleColorSchemeBlue:
            return [UIColor colorWithRed: 32.0/255 green: 92.0/255 blue: 153.0/255 alpha: 1.0];
        case HXOBubbleColorSchemeEtched:
            return [UIColor colorWithRed: 153.0/255 green: 153.0/255 blue: 153.0/255 alpha: 1.0];
        case HXOBubbleColorSchemeRed:
            return [UIColor colorWithRed: 153.0/255 green: 31.0/255 blue: 31.0/255 alpha: 1.0];
        case HXOBubbleColorSchemeBlack:
            return [UIColor whiteColor];
    }
}

- (NSDictionary*) linkStyleForColorScheme: (HXOBubbleColorScheme) colorScheme {
    UIColor * color;
    switch (colorScheme) {
        case HXOBubbleColorSchemeWhite:
            color = [UIColor colorWithRed: 0.0/255 green: 85.0/255 blue: 255.0/255 alpha: 1.0];
        case HXOBubbleColorSchemeBlue:
            color = [UIColor colorWithRed: 0.0/255 green: 0.0/255 blue: 229.0/255 alpha: 1.0];
        case HXOBubbleColorSchemeEtched:
            color = [UIColor colorWithRed: 61.0/255 green: 77.0/255 blue: 153.0/255 alpha: 1.0];
        case HXOBubbleColorSchemeRed:
            color = [UIColor colorWithRed: 18.0/255 green: 18.0/255 blue: 179.0/255 alpha: 1.0];
        case HXOBubbleColorSchemeBlack:
            color = [UIColor blueColor];
    }
    return @{(id)kCTForegroundColorAttributeName: (id)color.CGColor};
}

@end
