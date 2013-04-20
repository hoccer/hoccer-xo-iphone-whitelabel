//
//  UserDefaultsKeys.m
//  HoccerTalk
//
//  Created by David Siegel on 06.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "HTUserDefaults.h"

NSString * const kHTEnvironment           = @"environment";
NSString * const kHTFirstRunDone          = @"firstRunDone";
NSString * const kHTAPNDeviceToken        = @"apnDeviceToken";
NSString * const kHTClientId              = @"clientId";
NSString * const kHTPassword              = @"password";
NSString * const kHTSrpSalt               = @"srpSalt";
NSString * const kHTAvatar                = @"avatar";
NSString * const kHTAvatarURL             = @"avatarURL";
NSString * const kHTNickName              = @"nickName";
NSString * const kHTUserStatus            = @"userStatus";
NSString * const kHTDefaultScreenShooting = @"defaultScreenShooting";
NSString * const kHTAutoDownloadLimit     = @"autoDownloadLimit";
NSString * const kHTAutoUploadLimit       = @"autoUploadLimit";

NSString * const kHTSaveDatabasePolicy    = @"saveDatabasePolicy";
NSString * const kHTSaveDatabasePolicyPerMessage  = @"perMessage";

NSString * const kHTDefaultsDefaultsFile = @"HTUserDefaultsDefaults";

@implementation HTUserDefaults

+ (void) initialize {
    NSString * path = [[NSBundle mainBundle] pathForResource: kHTDefaultsDefaultsFile ofType: @"plist"];
    NSDictionary * defaultsDefaults = [NSDictionary dictionaryWithContentsOfFile: path];
    [[NSUserDefaults standardUserDefaults] registerDefaults: defaultsDefaults];
}

+ (id) standardUserDefaults {
    return [NSUserDefaults standardUserDefaults];
}

@end
