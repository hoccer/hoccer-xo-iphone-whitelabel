//
//  SRP6.h
//  ObjCSRP
//
//  Created by David Siegel on 16.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

// http://srp.stanford.edu/design.html
// http://tools.ietf.org/html/rfc5054#ref-SRP

#import <Foundation/Foundation.h>

#import "SRP6Parameters.h"
#import "Digest.h"


FOUNDATION_EXPORT NSString * const SRP6ProtocolErrorDomain;

typedef enum SRP6ProtocolErrors {
    SRP6_SAFEGUARD_VIOLATION = 23,
    SRP6_KEY_VERIFICATION_ERROR
} SRP6ProtocolError;

@interface SRP6 : NSObject
{
    id<SRPDigest> _digest;
    BigInteger *  _N;
    BigInteger *  _g;
    NSData     *  _salt;
    NSString   *  _username;
    BigInteger *  _A;
    BigInteger *  _B;
    NSData     *  _K;
}

@property (nonatomic,readonly) NSData * sessionKey;

//=== API ======================================================================

- (id) initWithDigest: (id<SRPDigest>) digest N: (BigInteger*) N g: (BigInteger*) g;

+ (NSData*) saltForDigest: (id<SRPDigest>) digest;

+ (SRP6Parameters*) CONSTANTS_1024;
+ (SRP6Parameters*) CONSTANTS_2048;
+ (SRP6Parameters*) CONSTANTS_4096;
+ (SRP6Parameters*) CONSTANTS_8192;


//=== Private ==================================================================

- (BigInteger*) selectPrivateValue;
- (BigInteger*) xWithSalt: (NSData*) salt username: (NSString*) username password: (NSString*) password;
- (BigInteger*) k;
- (BigInteger*) uWithA: (BigInteger*) A andB: (BigInteger*) B;
- (NSData*) calculateHashNg;
- (NSData*) hashNumber: (BigInteger*) number;
- (NSData*) hashData: (NSData*) data;
- (NSData*) calculateM1;
- (NSData*) calculateM2: (NSData*) M1;
- (BigInteger*) validatePublicValue: (BigInteger*) publicValue error: (NSError**) error;

@end


@interface SRP6Exception : NSException

@end
