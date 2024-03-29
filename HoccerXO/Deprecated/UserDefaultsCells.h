//
//  ProfileAvatarCell.h
//  HoccerXO
//
//  Created by David Siegel on 07.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "HXOTableViewCell.h"
#import "ProfileDataSource.h"

@protocol UserDefaultsCellTextInputDelegate <NSObject>

@property (nonatomic,assign) BOOL isEditable;

@optional

- (BOOL) validateTextField: (UITextField*) textField;
- (void) textFieldDidEndEditing: (UITextField*) textField;

@end


@interface ProfileItem : NSObject <UserDefaultsCellTextInputDelegate,ProfileItemInfo>

@property (nonatomic,strong) NSString *      valueKey; // used to access the model
@property (nonatomic,strong) NSString *      currentValue;
@property (nonatomic,strong) NSString *      editLabel;
@property (nonatomic,strong) id              cellClass;
@property (nonatomic,strong) NSString *      placeholder;
@property (nonatomic,assign) UIKeyboardType  keyboardType;
@property (nonatomic,assign) BOOL            required;
@property (nonatomic,assign) BOOL            valid;
@property (nonatomic,assign) UITextAlignment textAlignment;
@property (nonatomic, assign) BOOL           secure;
@property (nonatomic, weak)  id              target;
@property (nonatomic,unsafe_unretained) SEL  action;
@property (nonatomic,assign) BOOL            alwaysShowDisclosure;
@property (nonatomic,strong) NSString *      name;
@property (nonatomic,assign) NSUInteger      maxLength;
@property (nonatomic,strong) NSString *      valueFormat;
@property (nonatomic,assign) BOOL            isEditable;

- (id) initWithName: (NSString*) name;

@end

@interface AvatarItem : NSObject <ProfileItemInfo>

@property (nonatomic,strong) UIImage*  currentValue;
@property (nonatomic,strong) NSString* valueKey;
@property (nonatomic,strong) NSString* contactKey;
@property (nonatomic,strong) id        cellClass;
@property (nonatomic,weak) id        target;
@property (nonatomic, unsafe_unretained) SEL      action;
//@property (nonatomic,strong) NSIndexPath *   indexPath;
@property (nonatomic,strong) NSString *   defaultImageName;
@property (nonatomic,strong) NSString *      name;

- (id) initWithName: (NSString*) name;

@end

@class AvatarView;

@interface UserDefaultsCell : HXOTableViewCell

@property (nonatomic,strong) NSString* valueFormat;
@property (nonatomic,strong) NSString* currentValue;
@property (nonatomic,strong) IBOutlet UILabel * label;

- (void) configure: (id) item;

@end

@interface UserDefaultsCellAvatarPicker : UserDefaultsCell

//@property (nonatomic,strong) IBOutlet ProfileAvatarView * avatar;
@property (nonatomic,strong) IBOutlet UIImage * avatarImage;

@end

@interface UserDefaultsCellTextInput : UserDefaultsCell  <UITextFieldDelegate>

@property (nonatomic,strong) IBOutlet UITextField * textField;
@property (nonatomic,strong) IBOutlet UIImageView * textInputBackground;
@property (nonatomic,strong) NSString* editLabel;
@property (nonatomic,strong) id<UserDefaultsCellTextInputDelegate> delegate;
@property (nonatomic,assign) NSUInteger maxLength;

@end

@interface UserDefaultsCellInfoText : UserDefaultsCell

@property (nonatomic,strong) IBOutlet UILabel * textLabel;

//- (CGFloat) heightForText: (NSString*) text;

@end

@interface UserDefaultsCellDisclosure : UserDefaultsCell

@property (nonatomic,strong) NSString* editLabel;

@end
