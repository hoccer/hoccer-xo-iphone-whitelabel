//
//  ProfileSheetController.h
//  HoccerXO
//
//  Created by David Siegel on 01.04.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "ContactSheetBase.h"

@interface ProfileSheetController : ContactSheetBase

@property (nonatomic, readonly) DatasheetItem * exportCredentialsItem;
@property (nonatomic, readonly) DatasheetItem * importCredentialsItem;
@property (nonatomic, readonly) DatasheetItem * deleteCredentialsFileItem;

@end
