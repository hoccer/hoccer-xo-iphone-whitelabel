//
//  NSData+DictCompression.m
//
//  Created by PM on 17.05.14.
//  Copyright (c) 2014 Pavel Mayer. All rights reserved.
//

#import "NSData+DictCompression.h"
#import "NSString+StringWithData.h"
#import "NSData+HexString.h"
#import "NSData+Base64.h"
#import <Foundation/NSUUID.h>

#define SOME_COMPRESSION_TRACE YES
#define COMPRESSION_TRACE NO
#define MORE_COMPRESSION_TRACE NO
#define COMPRESSION_TIMING YES


typedef NSRange (^CompressBlock)(NSMutableData * data, NSRange range);


@implementation NSData (DictCompression)


enum {
    DICT_LIMIT = 240,
    HEX_LOWERCASE             = 241, //0xf1
    HEX_UPPERCASE             = 242, //0xf2
    HEX_LOWERCASE_QUOTED      = 243, //0xf3
    HEX_UPPERCASE_QUOTED      = 244, //0xf4
    UUID_LOWERCASE            = 245, //0xf5
    UUID_UPPERCASE            = 246, //0xf6
    UUID_LOWERCASE_QUOTED     = 247, //0xf7
    UUID_UPPERRCASE_QUOTED    = 248, //0xf8
    BASE64_SHORT              = 249, //0xf9
    BASE64_LONGER             = 250, //0xfa
    BASE64_SHORT_SLASHESC     = 251, //0xfb
    BASE64_LONGER_SLASHESC    = 252  //0xfc
};


-(NSData*)dataByReplacingOccurrencesOfData:(NSData*)what withData:(NSData*)replacement {
    NSMutableData * result = [NSMutableData dataWithData:self];
    NSRange where = NSMakeRange(0,result.length);
    do {
        where = [result rangeOfData:what options:0 range:where];
        if (where.location != NSNotFound) {
            [result replaceBytesInRange:where withBytes:replacement.bytes length:replacement.length];
            where.location = where.location + replacement.length;
            where.length = result.length - where.location;
        }
    } while (where.location != NSNotFound && where.length > 0);
    return result;
}

static int findByteIndex(unsigned char byte, const unsigned char * bytes, int size) {
    for (int b = 0; b < size;++b) {
        if (byte == bytes[b]) {
            return b;
        }
    }
    return -1;
}

static int findByteIndexFrom(unsigned char byte, const unsigned char * bytes, int size, int start) {
    if (MORE_COMPRESSION_TRACE) NSLog(@"findByteIndexFrom: byte=%d, size=%d, start=%d",byte,size,start);
    for (int b = start; b < size;++b) {
        if (byte == bytes[b]) {
            return b;
        }
    }
    return -1;
}

static int findByteIndexFrom2(unsigned char byte, const unsigned char * bytes, int size, int start) {
    if (MORE_COMPRESSION_TRACE) NSLog(@"findByteIndexFrom2: byte=%d, size=%d, start=%d",byte,size,start);
    for (int b = start; b < size;++b) {
        if (byte == bytes[b]) {
            return b;
        }
    }
    return size;
}

BOOL isAlphaChar(unsigned char c) {
    return ((c >= 'a') && (c <='z')) || ((c >= 'A') && (c <='Z'));
}

- (BOOL)isAlphaRange:(NSRange)range {
    const unsigned char * bytes = [self bytes];
    for (int i = 0; i < range.length;++i) {
        unsigned char c = bytes[range.location+i];
        if (!isAlphaChar(c)) {
            if (MORE_COMPRESSION_TRACE) NSLog(@"alpha: bailout on %c (%d) at pos %d", c, c,range.location+i);
            return NO;
        }
    }
    return YES;
}

BOOL isLowerHexChar(unsigned char c) {
    return ((c >= 'a') && (c <='z')) || ((c >= '0') && (c <='9'));
}

- (BOOL)isLowerHexRange:(NSRange)range {
    const unsigned char * bytes = [self bytes];
    for (int i = 0; i < range.length;++i) {
        unsigned char c = bytes[range.location+i];
        if (!isLowerHexChar(c)) {
            if (MORE_COMPRESSION_TRACE) NSLog(@"isLowerHexRange: bailout on %c (%d) at pos %d", c, c,range.location+i);
            return NO;
        }
    }
    return YES;
}


BOOL isUpperHexChar(unsigned char c) {
    return ((c >= 'A') && (c <='Z')) || ((c >= '0') && (c <='9'));
}

- (BOOL)isUpperHexRange:(NSRange)range {
    const unsigned char * bytes = [self bytes];
    for (int i = 0; i < range.length;++i) {
        unsigned char c = bytes[range.location+i];
        if (!isUpperHexChar(c)) {
            if (MORE_COMPRESSION_TRACE) NSLog(@"isUpperHexRange: bailout on %c (%d) at pos %d", c, c,range.location+i);
            return NO;
        }
    }
    return YES;
}

// 7c198eef-ab74-42db-9ac1-67ce7dfda355
// 012345678901234567890123456789012345
// 000000000011111111112222222222233333

- (BOOL)canBeUUIDRange:(NSRange)range {
    if (range.length != 36) {
        return NO;
    }
    const unsigned char * bytes = [self bytes] + range.location;
    BOOL hasMinuses = (bytes[8] == '-') && (bytes[13] == '-') && (bytes[18] == '-') && (bytes[23] == '-');
    return hasMinuses;
}


- (BOOL)isUpperUUIDRange:(NSRange)range {
    if ([self canBeUUIDRange:range]) {
        const unsigned char * bytes = [self bytes];
        for (int i = 0; i < range.length;++i) {
            unsigned char c = bytes[range.location+i];
            if (!isUpperHexChar(c) && (c != '-')) {
                if (MORE_COMPRESSION_TRACE) NSLog(@"isUpperUUIDRange: bailout on %c (%d) at pos %d i=%d", c, c,range.location+i,i);
                return NO;
            }
        }
        return YES;
    }
    return NO;
}

- (BOOL)isLowerUUIDRange:(NSRange)range {
    if ([self canBeUUIDRange:range]) {
        const unsigned char * bytes = [self bytes];
        for (int i = 0; i < range.length;++i) {
            unsigned char c = bytes[range.location+i];
            if (!isLowerHexChar(c) && c!= '-') {
                if (MORE_COMPRESSION_TRACE) NSLog(@"isLowerUUIDRange: bailout on %c (%d) at pos %d i=%d", c, c,range.location+i,i);
                return NO;
            }
        }
        if (MORE_COMPRESSION_TRACE) NSLog(@"isLowerUUIDRange: is UUID");
        return YES;
    }
    return NO;
}


BOOL isBase64Char(unsigned char c) {
    return ((c >= 'a') && (c <='z')) || ((c >= 'A') && (c <='Z')) || ((c >= '0') && (c <='9')) || c == '/' || c=='+' || c=='=' || c=='\\';
}

- (BOOL)isBase64Range:(NSRange)range {
    int payload = 0;
    const unsigned char * bytes = [self bytes];
    int pads = 0;
    for (int i = 0; i < range.length;++i) {
        unsigned char c = bytes[range.location+i];
        if (!isBase64Char(c)) {
            if (MORE_COMPRESSION_TRACE) NSLog(@"isBase64Range:bailout on %c (%d) at pos %d", c, c,range.location+i);
            return NO;
        }
        if (c == '=') {
            ++pads;
            if (pads>3) {
                if (MORE_COMPRESSION_TRACE) NSLog(@"isBase64Range:bailout pad # %d at pos %d", pads,range.location+i);
                return NO;
            }
        } else {
            if (pads>0) {
                if (MORE_COMPRESSION_TRACE) NSLog(@"isBase64Range:bailout on char after pad # %d at pos %d", pads,range.location+i);
                return NO;
            }
        }
        if (c != '\\') {
            ++payload;
        }
    }
    if (payload % 4 != 0) {
        if (MORE_COMPRESSION_TRACE) NSLog(@"isBase64Range:bailout on payload len not multiple of 4  (%d)",payload);
        return NO;
    }
    return YES;
}

- (NSRange) rangeOfQuotedBase64StringInRange:(NSRange)range {
    NSRange searchRange = range;
    const unsigned char * bytes = [self bytes];
    int nextQuote = -1;
    int rangeEnd = range.location + range.length;
    do {
        nextQuote = findByteIndexFrom('"', bytes, rangeEnd, searchRange.location);
        if (MORE_COMPRESSION_TRACE) NSLog(@"findByteIndexFrom returned nextQuote@%d",nextQuote);
        if (nextQuote >= 0) {
            int closingQuote = findByteIndexFrom('"', bytes, rangeEnd, nextQuote+1);
            if (closingQuote >= 0) {
                NSRange base64Range = NSMakeRange(nextQuote+1, closingQuote - nextQuote - 1);
                if (base64Range.length >=8 && [self isBase64Range:base64Range] &&
                    ![self isAlphaRange:base64Range] &&
                    ![self isUpperHexRange:base64Range] &&
                    ![self isLowerHexRange:base64Range] &&
                    ![self isUpperUUIDRange:base64Range] &&
                    ![self isLowerUUIDRange:base64Range] )
                {
                    return base64Range;
                } else {
                    searchRange = NSMakeRange(closingQuote, rangeEnd - closingQuote);
                }
            } else {
                nextQuote = closingQuote; // end search if no closing quote
            }
        }
    } while (nextQuote >= 0);
    return NSMakeRange(NSNotFound, 0);
}


- (NSRange) rangeOfLowerUUIdStringInRange:(NSRange)range {
    if (MORE_COMPRESSION_TRACE) NSLog(@"rangeOfLowerUUIdStringInRange: searching in range from %d size %d",range.location, range.length);
    NSRange search = NSMakeRange(range.location, 36);
    NSUInteger rangeEnd = range.location + range.length;
    for (;search.location+search.length < rangeEnd; ++search.location) {
        //if (MORE_COMPRESSION_TRACE) NSLog(@"rangeOfLowerUUIdStringInRange: checking range from %d size %d",search.location, search.length);
        if ([self isLowerUUIDRange:search]) {
            if (MORE_COMPRESSION_TRACE) NSLog(@"rangeOfLowerUUIdStringInRange: found UUID %@",[[self subdataWithRange:search] asciiString]);
            return search;
        }
    }
    if (MORE_COMPRESSION_TRACE) NSLog(@"rangeOfLowerUUIdStringInRange: no UUID found in range from %d size %d",range.location, range.length);
    return NSMakeRange(NSNotFound, 0);
}

- (NSRange) rangeOfUpperUUIdStringInRange:(NSRange)range {
    NSRange search = NSMakeRange(range.location, 36);
    for (;search.location+search.length < range.location; ++search.location) {
        if ([self isUpperUUIDRange:search]) {
            return search;
        }
    }
    return NSMakeRange(NSNotFound, 0);
}


// return the first range of bytes in inRange where all bytes are contained in bytesset
- (NSRange) rangeOfBytesFromSet:(NSData*)byteSet range:(NSRange)range minLenght:(NSUInteger)minLength {
    unsigned char min = 255;
    unsigned char max = 0;
    const unsigned char * bytes = (unsigned char*)byteSet.bytes;
    for (int i = 0; i < byteSet.length;++i) {
        unsigned char byte = bytes[i];
        if (byte < min) min = byte;
        if (byte > max) max = byte;
    }
    unsigned char * rangeBytes = (unsigned char*)self.bytes;

    int matchStart = NSNotFound;
    int matchLen = 0;
    for (int i = range.location; i < range.location + range.length; ++i) {
        int found = -1;
        if (rangeBytes[i] >= min || rangeBytes[i] <= max) {
            found = findByteIndex(rangeBytes[i], bytes, byteSet.length);
        }
        if (found >= 0) {
            // found
            ++matchLen;
            if (matchStart == NSNotFound) {
                matchStart = i;
            }
        } else {
            // not found
            if (matchStart != NSNotFound) {
                if (matchLen >= minLength) {
                    return NSMakeRange(matchStart, matchLen);
                } else {
                    matchLen = 0;
                    matchStart = NSNotFound;
                }
            }
        }
    }
    return NSMakeRange(NSNotFound, 0);
}

static const unsigned char hex_bytes_lower[16] = "0123456789abcdef";
static const unsigned char hex_bytes_upper[16] = "0123456789ABCDEF";

NSData * dataFromBytes(const unsigned char * bytes, int len) {
    return [NSData dataWithBytes:bytes length:len];
}

NSMutableData * mutableDataFromBytes(const unsigned char * bytes, int len) {
    return [NSMutableData dataWithBytes:bytes length:len];
}

NSRange minLocation(NSRange a, NSRange b) {
    if (a.location <= b.location) return a;
    return b;
}
    
unsigned char getOpcode(BOOL isUUID, BOOL isUpperCase, BOOL isQuoted) {
    int index = 0;
    if (isUpperCase) index+=1;
    if (isQuoted) index+=2;
    if (isUUID) index += 4;
    return HEX_LOWERCASE+index;
}

BOOL opcodeIsQuoted(unsigned char opcode) {
    if (opcode < HEX_LOWERCASE || opcode > HEX_LOWERCASE+7) {
        NSLog(@"bad opcode:%d", opcode);
        return NO;
    }
    return ((opcode - HEX_LOWERCASE) & 2) != 0;
}

BOOL opcodeIsUppercase(unsigned char opcode) {
    if (opcode < HEX_LOWERCASE || opcode > HEX_LOWERCASE+7) {
        NSLog(@"bad opcode:%d", opcode);
        return NO;
    }
    return ((opcode - HEX_LOWERCASE) & 1) != 0;
}

BOOL opcodeIsUUID(unsigned char opcode) {
    if (opcode < HEX_LOWERCASE || opcode > HEX_LOWERCASE+7) {
        NSLog(@"bad opcode:%d", opcode);
        return NO;
    }
    return ((opcode - HEX_LOWERCASE) & 4) != 0;
}

BOOL opcodeIsHex(unsigned char opcode) {
    return (opcode >= HEX_LOWERCASE && opcode <=HEX_LOWERCASE+7);
}

BOOL opcodeIsBase64(unsigned char opcode) {
    return (opcode >= BASE64_SHORT && opcode <=BASE64_LONGER_SLASHESC);
}

BOOL opcodeIsConst(unsigned char opcode) {
    return opcodeIsDictionary(opcode) || (opcodeIsHex(opcode) && opcodeIsUUID(opcode));
}

BOOL opcodeIsShort(unsigned char opcode) {
    return opcode == BASE64_SHORT || opcode == BASE64_SHORT_SLASHESC ||(opcodeIsHex(opcode) && !opcodeIsUUID(opcode));
}

BOOL opcodeIsLonger(unsigned char opcode) {
    return opcode == BASE64_LONGER || opcode == BASE64_LONGER_SLASHESC;
}

BOOL opcodeIsSlashEscaped(unsigned char opcode) {
    return opcode == BASE64_SHORT_SLASHESC || opcode == BASE64_LONGER_SLASHESC;
}


int operationEncodedSize(unsigned char opcode, const unsigned char * codeblock) {
    if (opcodeIsConst(opcode)) {
        if (opcodeIsDictionary(opcode)) {
            return 2; // 0x0 + index
        } else if (opcodeIsUUID(opcode)) {
            return 2 + 16; // 0x0 + opcode + uuid;
        }
        NSLog(@"error: internal, bad opcode logic");
    }
    // opcode has variable field
    if (opcodeIsShort(opcode)) {
        return 3 + codeblock[2]; // 0x0 + opcode + lenght + content
    }
    if (opcodeIsLonger(opcode)) {
        return 4 + codeblock[2] * 256 + codeblock[3]; // 0x0 + opcode + lenght + content
    }
    NSLog(@"ERROR: can not determine operationEncodedSize");
    return 0; // no opcode
}

BOOL opcodeIsDictionary(unsigned char opcode) {
    if (opcode < DICT_LIMIT) {
        if (opcode > 0) {
            return YES;
        }
        NSLog(@"illegal null opcode");
    }
    return NO;
}

- (NSData*)iterateOverUncompressedWithMinSize:(NSUInteger)minSize withBlock:(CompressBlock)compress {
    NSMutableData * result = [NSMutableData dataWithData:self];
    NSRange searchRange = NSMakeRange(0,result.length);
    int start = 0;
    int stop = findByteIndexFrom2(0, result.bytes, result.length, searchRange.location);
    while (stop >= 0 && start < result.length) {
        int gap = stop - start;
        if (MORE_COMPRESSION_TRACE) NSLog(@"start: %d stop %d gap %d", start, stop, gap);
        if (gap >= minSize) {
            NSRange done = compress(result, NSMakeRange(start, gap));
            start = done.location + done.length;
        } else {
            if (MORE_COMPRESSION_TRACE) NSLog(@"gap %d smaller than min %d", gap, minSize);
            start = stop;
        }
        if (start < result.length) {
            const unsigned char * bytes = result.bytes;
            if (MORE_COMPRESSION_TRACE) NSLog(@"check pos %d for 0", start);
            if (bytes[start] == 0) {
                if (MORE_COMPRESSION_TRACE) NSLog(@"pos %d is zero", start);
                unsigned char opcode = bytes[start+1];
                int skip = operationEncodedSize(opcode, bytes+start);
                if (MORE_COMPRESSION_TRACE) NSLog(@"skip:%d", skip);
                start += skip;
            } else {
                if (MORE_COMPRESSION_TRACE) NSLog(@"pos %d is not zero, searching for next zero as stop", start);
            }
            stop = findByteIndexFrom2(0, result.bytes, result.length, start);
        } else {
            if (MORE_COMPRESSION_TRACE) NSLog(@"pos %d has reached end", start);
        }
    };
    return result;
}

- (NSData*)performDictCompressionWithDict:(NSArray*)dict {
    NSMutableArray * dataDict = [NSMutableArray new];
    NSMutableArray * opcodes = [NSMutableArray new];
    NSData * result = self;
    for (int i = 0; i < dict.count;++i) {
        NSData * entry = dict[i];
        if ([entry isKindOfClass:[NSString class]]) {
            // convert string from dict to data
            [dataDict addObject: [(NSString*)entry dataUsingEncoding:NSUTF8StringEncoding]];
        } else {
            [dataDict addObject: entry];
        }
        entry = dataDict[i];
        if (findByteIndex(0, entry.bytes, 1) >= 0) {
            // 0 in dict not allowed
            return nil;
        }
        unsigned char indexReference[2] = {0, i+1};
        [opcodes addObject:dataFromBytes(indexReference, 2)];
        
        if (MORE_COMPRESSION_TRACE) NSLog(@"\n");
        if (MORE_COMPRESSION_TRACE) NSLog(@"dictSearch looking for: %@", [entry asciiString]);

        result  = [result iterateOverUncompressedWithMinSize:4 withBlock:^NSRange(NSMutableData *data, NSRange range) {
            if (MORE_COMPRESSION_TRACE) NSLog(@"dictSearch range from %d size %d",range.location, range.length);
            if (entry.length <= range.length) {
                if (MORE_COMPRESSION_TRACE) NSLog(@"dictSearch looking for: %@", [entry asciiString]);
                NSRange found = [data rangeOfData:entry options:0 range:range];
                if (found.location != NSNotFound) {
                    NSData * refop = opcodes[i];
                    if (COMPRESSION_TRACE) NSLog(@"dictSearch found %@ at %d", [entry asciiString], found.location);
                    if (COMPRESSION_TRACE) NSLog(@"Dict: replacing %@ with %@",[[data subdataWithRange:found] asciiString], [refop asciiString] );
                    if (MORE_COMPRESSION_TRACE) NSLog(@"before=%@",[data asciiString]);
                    [data replaceBytesInRange:found withBytes:refop.bytes length:refop.length];
                    if (MORE_COMPRESSION_TRACE) NSLog(@"after=%@",[data asciiString]);
                    if (SOME_COMPRESSION_TRACE) NSLog(@"match (reduced %d->%d):%@ (at %d)",found.length,refop.length, [entry asciiString], found.location);
                    return NSMakeRange(found.location, refop.length);
                }
            }
            return range;
        }];
    }
    return result;
}

-(NSData*) performHexCompression {
    NSData * result2 = self;
    NSData * hexCharsLower = dataFromBytes(hex_bytes_lower, 16);
    NSData * hexCharsUpper = dataFromBytes(hex_bytes_upper, 16);
    
    result2  = [result2 iterateOverUncompressedWithMinSize:4 withBlock:^NSRange(NSMutableData *data, NSRange range) {
        if (MORE_COMPRESSION_TRACE) NSLog(@"");
        if (MORE_COMPRESSION_TRACE) NSLog(@"hexSearch range from %d size %d",range.location, range.length);
        
        //NSRange foundUUIDUpper = [data rangeOfUUIdStringInRange:range upperCase:YES];
        //NSRange foundUUIDLower = [data rangeOfUUIdStringInRange:range upperCase:NO];
        NSRange foundUUIDUpper = [data rangeOfUpperUUIdStringInRange:range];
        NSRange foundUUIDLower = [data rangeOfLowerUUIdStringInRange:range];
        NSRange foundUpper = [data rangeOfBytesFromSet:hexCharsUpper range:range minLenght:6];
        NSRange foundLower = [data rangeOfBytesFromSet:hexCharsLower range:range minLenght:6];
        
        if (MORE_COMPRESSION_TRACE) NSLog(@"foundUUIDUpper is range from %d size %d",foundUUIDUpper.location, foundUUIDUpper.length);
        if (MORE_COMPRESSION_TRACE) NSLog(@"foundUUIDLower is range from %d size %d",foundUUIDLower.location, foundUUIDLower.length);
        if (MORE_COMPRESSION_TRACE) NSLog(@"foundUpper is range from %d size %d",foundUpper.location, foundUpper.length);
        if (MORE_COMPRESSION_TRACE) NSLog(@"foundLower is range from %d size %d",foundLower.location, foundLower.length);

        NSRange found = minLocation(foundUUIDLower, minLocation(foundUUIDUpper,minLocation(foundLower,foundUpper)));
        if (MORE_COMPRESSION_TRACE) NSLog(@"using minLocation range from %d size %d",found.location, found.length);
        
        if (found.location != NSNotFound) {
            if (found.length > 506) {
                found.length = 506; // limit chunk size to 253 binary bytes
                if (MORE_COMPRESSION_TRACE) NSLog(@"limiting chunk size to 253 binary");
            }
            if (found.length % 2 == 1) {
                found.length = found.length -1; // make even
                if (MORE_COMPRESSION_TRACE) NSLog(@"makeing even -> %d", found.length);
            }
            
            if (found.length >=6) {
                BOOL isUUID = NO;
                BOOL isUpperCase = NO;
                
                NSString * debugItem = nil;
                if (found.location == foundUUIDLower.location) {
                    isUUID = YES;
                    debugItem = @"lowercase UUID";
                    
                } else if (found.location == foundUUIDUpper.location) {
                    isUpperCase = YES;
                    isUUID = YES;
                    debugItem = @"uppercase UUID";
                    
                } else if (found.location == foundLower.location) {
                    debugItem = @"lowercase hex";
                    
                } else if (found.location == foundUpper.location) {
                    isUpperCase = YES;
                    debugItem = @"uppercase hex";
                }
                if (MORE_COMPRESSION_TRACE && debugItem != nil) {
                    if (MORE_COMPRESSION_TRACE) NSLog(@"dataWithCompressedHexStrings: Found %@ @ %d, len=%d", debugItem, found.location, found.length);
                }
                
                NSString * foundString = [NSString stringWithData:[data subdataWithRange:found] usingEncoding:NSUTF8StringEncoding];
                if (COMPRESSION_TRACE) NSLog(@"Found %@ %@ at pos %d",debugItem, foundString,found.location);
                BOOL quoted = NO;
                if (found.location > range.location && found.location+found.length+1 < data.length) {
                    // check for quotes
                    const unsigned char * bytes = data.bytes;
                    if (bytes[found.location-1] == '"' && bytes[found.location+found.length] == '"') {
                        quoted = YES;
                        if (COMPRESSION_TRACE) NSLog(@"Found Quoutes");
                    }
                }
                NSData * hexData;
                if (isUUID) {
                    NSString * uuidString = [NSString stringWithData:[data subdataWithRange:found] usingEncoding:NSUTF8StringEncoding];
                    NSUUID * uuid = [[NSUUID alloc] initWithUUIDString:uuidString];
                    if (uuid == nil) {
                        NSLog(@"#ERROR: internal, failed to properly parse uuid");
                        return range;
                    }
                    uuid_t uuidBytes;
                    [uuid getUUIDBytes:uuidBytes];
                    hexData = [NSData dataWithBytes:uuidBytes length:16];
                    
                } else {
                    hexData= [NSData dataWithHexadecimalString:foundString];
                    if (hexData.length != found.length/2) {
                        NSLog(@"#ERROR: internal, failed to properly parse hex string");
                        return range;
                    }
                }
                if (quoted) {
                    found = NSMakeRange(found.location-1, found.length+2);
                }
                //hexData = [hexData escaped];
                if (hexData.length > 253) {
                    NSLog(@"#ERROR: internal, hex string too long for compression");
                    return range;
                }
                unsigned char indexReference[3];
                indexReference[0] = 0;
                indexReference[1] = getOpcode(isUUID, isUpperCase, quoted);
                indexReference[2] = hexData.length;
                
                NSMutableData * hexSequence = [NSMutableData dataWithBytes:indexReference length: isUUID ? 2 : 3];
                [hexSequence appendData:hexData];
                
                NSData * replacedData = nil;
                if (COMPRESSION_TRACE || SOME_COMPRESSION_TRACE) {
                    replacedData = [data subdataWithRange:found];
                    if (COMPRESSION_TRACE) NSLog(@"Replacing:%@", [replacedData asciiString]);
                    if (COMPRESSION_TRACE) NSLog(@"with:%@", [hexSequence asciiString]);
                }
                
                [data replaceBytesInRange:found withBytes:hexSequence.bytes length:hexSequence.length];
                
                if (SOME_COMPRESSION_TRACE) NSLog(@"%@ %@ %@ (reduced %d -> %d) %@", isUUID?@"uuid":@"hex", isUpperCase?@"uc":@"lc", quoted?@"quoted":@"", found.length, hexSequence.length, [replacedData asciiStringWithMaxBytes:16]);
                
                NSRange done = NSMakeRange(found.location, hexSequence.length);
                return done;
            } else {
                if (MORE_COMPRESSION_TRACE) NSLog(@"found len too small: %d", found.length);
            }
        }
        return range;
    }];
    return result2;
}

-(NSData*) performBase64Compression {
    NSData * result2 = self;
    
    if (COMPRESSION_TRACE) NSLog(@"performBase64Compression input=:%@", [result2 asciiString]);
    
    result2  = [result2 iterateOverUncompressedWithMinSize:4 withBlock:^NSRange(NSMutableData *data, NSRange range) {
        
        NSRange found = [data rangeOfQuotedBase64StringInRange:range];
        
        if (found.location != NSNotFound) {
            NSData * base64StringData = [data subdataWithRange:found];
            NSString * base64String = [NSString stringWithData:base64StringData usingEncoding:NSUTF8StringEncoding];
            
            BOOL slashEscaped = NO;
            if ([base64String rangeOfString:@"\\/"].location != NSNotFound) {
                slashEscaped = YES;
                base64String = [base64String stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"];
            }
            
            NSData * base64Data = [NSData dataWithBase64EncodedString:base64String];
            if (base64Data == nil) {
                NSLog(@"#warning, bad b64 decoding despite checked before, offender = %@",[base64StringData asciiString]);
                return range;
            }
            
            NSMutableData * replacement = nil;
            if (base64Data.length<256) {
                unsigned char short_base64[3] = {0, slashEscaped ? BASE64_SHORT_SLASHESC : BASE64_SHORT, base64Data.length};
                replacement = mutableDataFromBytes(short_base64,3);
            } else if (base64Data.length < 65536) {
                unsigned char longer_base64[4] = {0, slashEscaped ? BASE64_LONGER_SLASHESC : BASE64_LONGER, base64Data.length/256, base64Data.length % 256};
                replacement = mutableDataFromBytes(longer_base64,4);
            } else {
                NSLog(@"#warning, b64 block > 64k, not compressing");
            }
            if (MORE_COMPRESSION_TRACE) {
                const unsigned char * bytes = replacement.bytes;
                int oplen = operationEncodedSize(bytes[1], bytes);
                NSLog(@"base64: encoded oplen = %d, base64Data.length=%d, msb=%d, lsb=%d", oplen, base64Data.length, bytes[2], bytes[3]);
            }
            NSRange replaceRange = NSMakeRange(found.location-1, found.length+2); // also replace quotes
            if (replacement != nil) {
                [replacement appendData:base64Data];
                
                NSData * replacedData = nil;
                if (COMPRESSION_TRACE || SOME_COMPRESSION_TRACE) {
                    replacedData = [data subdataWithRange:found];
                    if (COMPRESSION_TRACE) NSLog(@"Replacing:%@", [replacedData asciiString]);
                    if (COMPRESSION_TRACE) NSLog(@"with:%@", [replacement asciiString]);
                }
                
                if (COMPRESSION_TRACE) NSLog(@"b64:Replacing:%@", [[data subdataWithRange:found] asciiString]);
                if (COMPRESSION_TRACE) NSLog(@"with:%@", [replacement asciiString]);
                
                if (MORE_COMPRESSION_TRACE) NSLog(@"before replacement:%@", [data asciiString]);
                
                [data replaceBytesInRange:replaceRange withBytes:replacement.bytes length:replacement.length];
                
                if (MORE_COMPRESSION_TRACE) NSLog(@"after  replacement:%@", [data asciiString]);
                
                if (SOME_COMPRESSION_TRACE) NSLog(@"base64 (reduced %d -> %d) %@", replaceRange.length, replacement.length, [replacedData asciiStringWithMaxBytes:16]);
                
                NSRange done = NSMakeRange(found.location, replacement.length);
                return done;
            }
        }
        return range;
    }];
    return result2;
 }

- (NSData*)iterateOverCompressedWithBlock:(CompressBlock)decompress {
    
    NSMutableData * result = [NSMutableData dataWithData:self];
    
    int start = findByteIndexFrom2(0, result.bytes, result.length, 0);
    while (start >= 0 && start != NSNotFound && start+1 < result.length ) {
        const unsigned char * bytes = result.bytes;
        unsigned char opcode = bytes[start+1];
        int compressedSize = operationEncodedSize(opcode, bytes+start);
        int opEnd = start + compressedSize -1;
        if (opEnd < result.length) {
            NSRange inserted = decompress(result, NSMakeRange(start, compressedSize));
            if (inserted.location == NSNotFound) {
                NSLog(@"iterateOverCompressedWithBlock: decompress failed at pos %d size %d",start,compressedSize);
                return nil;
            }
            start = inserted.location + inserted.length;
        } else {
            NSLog(@"iterateOverCompressedWithBlock: block too short at pos %d, required end = %d, actual size = %d",start,opEnd,result.length);
            return nil;
        }
        start = findByteIndexFrom2(0, result.bytes, result.length, start);
    }
    return result;
}

-(NSData*) performdecompressionWithDict:(NSArray*)dict {
    NSMutableArray * dataDict = [NSMutableArray new];
    for (int i = 0; i < dict.count;++i) {
        NSData * entry = dict[i];
        if ([entry isKindOfClass:[NSString class]]) {
            // convert string from dict to data
            [dataDict addObject: [(NSString*)entry dataUsingEncoding:NSUTF8StringEncoding]];
        } else {
            [dataDict addObject: entry];
        }
        entry = dataDict[i];
        if (findByteIndex(0, entry.bytes, 1) >= 0) {
            // 0 in dict not allowed
            return nil;
        }
    }
    NSData * result;
    result = [self iterateOverCompressedWithBlock:^NSRange(NSMutableData *data, NSRange range) {
        const unsigned char * bytes = data.bytes;
        unsigned char opcode = bytes[range.location+1];
        NSData * replacement = nil;
        if (opcodeIsDictionary(opcode)) {
            int index = opcode - 1;
            replacement = dataDict[index];
        } else if (opcodeIsHex(opcode)) {
            replacement = hexReplacement([data subdataWithRange:range]);
        } else if (opcodeIsBase64(opcode)) {
            replacement = base64Replacement([data subdataWithRange:range]);
        } else {
            NSLog(@"#ERROR: illegal opcode:%d",opcode);
            return NSMakeRange(NSNotFound, 0);
        }
        if (replacement == nil) {
            NSLog(@"#ERROR: replacement is nil");
            return NSMakeRange(NSNotFound, 0);
        }
        [data replaceBytesInRange:range withBytes:replacement.bytes length:replacement.length];
        NSRange replaced = NSMakeRange(range.location, replacement.length);
        return replaced;
    }];
    return result;
}

NSData * hexReplacement(NSData * compressedData) {
    
    const unsigned char * bytes = compressedData.bytes;
    unsigned char opcode = bytes[1];
    
    BOOL quoted = opcodeIsQuoted(opcode);
    BOOL isUUID = opcodeIsUUID(opcode);
    BOOL isUpperCase = opcodeIsUppercase(opcode);
    
    int srcDataSize = 0;
    if (isUUID) {
        srcDataSize = 16;
    } else {
        srcDataSize = bytes[2];
    }
    if (COMPRESSION_TRACE && quoted) NSLog(@"QUOTED");
    if (COMPRESSION_TRACE && !isUUID) NSLog(@"HEX");
    if (COMPRESSION_TRACE && isUUID) NSLog(@"UUID");
    if (COMPRESSION_TRACE && isUpperCase) NSLog(@"UPPERCASE");
    if (COMPRESSION_TRACE && !isUpperCase) NSLog(@"LOWERCASE");
    
    NSRange srcDataRange = NSMakeRange(isUUID ? 2 : 3, srcDataSize);
    if (srcDataRange.location+srcDataSize != compressedData.length) {
        NSLog(@"#ERROR: hexReplacement: compressedData size matchmatch, expected %d, is %d", srcDataRange.location+srcDataSize,compressedData.length);
        return nil;
    }
    
    NSData * binaryData = [compressedData subdataWithRange:srcDataRange];

    NSString * hexString;
    if (isUUID) {
        NSUUID * uuid = [[NSUUID alloc] initWithUUIDBytes:binaryData.bytes];
        hexString = [uuid UUIDString];
    } else {
        hexString = [binaryData hexadecimalString];
    }
    if (isUpperCase) {
        hexString = [hexString uppercaseString];
    } else {
        hexString = [hexString lowercaseString];
    }
    if (quoted) {
        hexString = [NSString stringWithFormat:@"\"%@\"", hexString];
    }
    NSData * hexStringData = [hexString dataUsingEncoding:NSUTF8StringEncoding];
    return hexStringData;
}

NSData * base64Replacement(NSData * compressedData) {
    const unsigned char * bytes = compressedData.bytes;
    unsigned char opcode = bytes[1];
    
    BOOL isLonger = opcodeIsLonger(opcode);
    BOOL isSlashEscaped = opcodeIsSlashEscaped(opcode);
    
    int srcDataSize = 0;
    if (isLonger) {
        srcDataSize = bytes[2] * 256 + bytes[3];
    } else {
        srcDataSize = bytes[2];
    }

    NSRange srcDataRange = NSMakeRange(isLonger ? 4 : 3, srcDataSize);
    if (srcDataRange.location+srcDataSize != compressedData.length) {
        NSLog(@"#ERROR: base64Replacement: compressedData size matchmatch, expected %d, is %d", srcDataRange.location+srcDataSize,compressedData.length);
        return nil;
    }

    if (COMPRESSION_TRACE && !isLonger) NSLog(@"BASE64 SHORT");
    if (COMPRESSION_TRACE && isLonger) NSLog(@"BASE 64 LONGER");
    if (COMPRESSION_TRACE && isSlashEscaped) NSLog(@"BASE 64 ISSLASHESCAPED");
    
    NSData * binaryData = [compressedData subdataWithRange:srcDataRange];
    NSString * base64String = [binaryData asBase64EncodedString];
    if (isSlashEscaped) {
        base64String = [base64String stringByReplacingOccurrencesOfString:@"/" withString:@"\\/"];
    }
    base64String = [NSString stringWithFormat:@"\"%@\"", base64String];
    NSData * base64StringData = [base64String dataUsingEncoding:NSUTF8StringEncoding];
    return base64StringData;
}

static const unsigned char null_byte[1] = {0};
static const unsigned char ff_byte[1] = {0xff};
static const unsigned char ffff_bytes[2] = {0xff,0xff};
static const unsigned char feff_bytes[2] = {0xfe,0xff};

- (NSData*)escaped {
    // escape 0xff as 0xfeff
    NSData * escaped = [self dataByReplacingOccurrencesOfData:dataFromBytes(ff_byte, 1) withData:dataFromBytes(feff_bytes, 2)];
    // turn 0x00 into 0xffff
    escaped = [escaped dataByReplacingOccurrencesOfData:dataFromBytes(null_byte, 1) withData:dataFromBytes(ffff_bytes, 2)];
    return escaped;
}

- (NSData*)unescaped {
    // turn 0xffff into 0x00
    NSData * unescaped = [self dataByReplacingOccurrencesOfData:dataFromBytes(ffff_bytes, 2) withData:dataFromBytes(null_byte, 1) ];
    // unescape 0xff from 0xfeff
    unescaped = [unescaped dataByReplacingOccurrencesOfData:dataFromBytes(feff_bytes, 2) withData:dataFromBytes(ff_byte, 1)];
    return unescaped;
}
/*
 dict, hex, b64:
 2014-05-20 01:00:55.247 Hoccer XO Dev[2150:60b] dictElapsed   3.98 ms
 2014-05-20 01:00:55.248 Hoccer XO Dev[2150:60b] hexElapsed    43.85 ms
 2014-05-20 01:00:55.248 Hoccer XO Dev[2150:60b] b64Elapsed    1.51 ms
 2014-05-20 01:00:55.249 Hoccer XO Dev[2150:60b] total compr.  49.35 ms
 2014-05-20 01:00:55.250 Hoccer XO Dev[2150:60b] decompression 1.00 ms
 2014-05-20 01:00:55.250 Hoccer XO Dev[2150:60b] Original payload        len: 5583
 2014-05-20 01:00:55.251 Hoccer XO Dev[2150:60b] dzlibCompressed payload len: 4020, (72.0%) time 0.87 ms
 2014-05-20 01:00:55.251 Hoccer XO Dev[2150:60b] dictCompressed payload  len: 4084, (73.2%) time 53.49 ms

b64, hex, dict:
 2014-05-20 01:05:44.549 Hoccer XO Dev[2168:60b] dictElapsed   2.88 ms
 2014-05-20 01:05:44.550 Hoccer XO Dev[2168:60b] hexElapsed    6.91 ms
 2014-05-20 01:05:44.550 Hoccer XO Dev[2168:60b] b64Elapsed    1.65 ms
 2014-05-20 01:05:44.551 Hoccer XO Dev[2168:60b] total compr.  11.45 ms
 2014-05-20 01:05:44.552 Hoccer XO Dev[2168:60b] decompression 0.78 ms
 2014-05-20 01:05:44.552 Hoccer XO Dev[2168:60b] Original payload        len: 5583
 2014-05-20 01:05:44.553 Hoccer XO Dev[2168:60b] dzlibCompressed payload len: 4018, (72.0%) time 0.99 ms
 2014-05-20 01:05:44.553 Hoccer XO Dev[2168:60b] dictCompressed payload  len: 4204, (75.3%) time 15.34 ms

 */

- (NSData *) compressWithDict:(NSArray*)dict {

    if (dict.count >= DICT_LIMIT) {
        // dict too large
        return nil;
    }
    NSData * compressed = [self escaped];
    
    NSDate * startTime = [NSDate new];
    
    // base64
    int beforeb64Size = compressed.length;
    NSDate * b64StartTime = [NSDate new];
    compressed = [compressed performBase64Compression];
    NSDate * b64StopTime = [NSDate new];
    int afterb64Size = compressed.length;

    // hex
    int beforeHexSize = compressed.length;
    NSDate * hexStartTime = [NSDate new];
    compressed = [compressed performHexCompression];
    NSDate * hexStopTime = [NSDate new];
    int afterHexSize = compressed.length;

    // dict
    int beforeDictSize = compressed.length;
    NSDate * dictStartTime = [NSDate new];
    compressed = [compressed performDictCompressionWithDict:dict];
    NSDate * dictStopTime = [NSDate new];
    int afterDictSize = compressed.length;
  
    NSDate * stopTime = [NSDate new];
    
    NSDate * decompStartTime = [NSDate new];
    NSData * check = [compressed decompressWithDict:dict];
    NSDate * decompStopTime = [NSDate new];
 
    if (COMPRESSION_TIMING) {
        NSTimeInterval dictElapsed = [dictStopTime timeIntervalSinceDate:dictStartTime];
        NSTimeInterval hexElapsed = [hexStopTime timeIntervalSinceDate:hexStartTime];
        NSTimeInterval b64Elapsed = [b64StopTime timeIntervalSinceDate:b64StartTime];
        NSTimeInterval decompElapsed = [decompStopTime timeIntervalSinceDate:decompStartTime];
        NSTimeInterval totalComprElapsed = [stopTime timeIntervalSinceDate:startTime];
        
        NSLog(@"dictElapsed   %0.2f ms", dictElapsed*1000);
        NSLog(@"hexElapsed    %0.2f ms", hexElapsed*1000);
        NSLog(@"b64Elapsed    %0.2f ms", b64Elapsed*1000);
        NSLog(@"total compr.  %0.2f ms", totalComprElapsed*1000);
        NSLog(@"decompression %0.2f ms", decompElapsed*1000);
    }
    
    if (SOME_COMPRESSION_TRACE) NSLog(@"all dict (reduced %d->%d, %.1f %%)",beforeDictSize, afterDictSize, (double)afterDictSize / (double)beforeDictSize * 100.0);
    if (SOME_COMPRESSION_TRACE) NSLog(@"all hex  (reduced %d->%d, %.1f %%)",beforeHexSize, afterHexSize, (double)afterHexSize / (double)beforeHexSize * 100.0);
    if (SOME_COMPRESSION_TRACE) NSLog(@"all b64  (reduced %d->%d, %.1f %%)",beforeb64Size, afterb64Size, (double)afterb64Size / (double)beforeb64Size * 100.0);

    if (![self isEqualToData:check]) {
        NSLog(@"Compression Error");
        for (int i = 0; i < self.length; ++i) {
            if (((unsigned char*)self.bytes)[i] != ((unsigned char*)check.bytes)[i]) {
                NSLog(@"first diff at pos %d, orig=%d, decoded=%d", i, ((unsigned char*)self.bytes)[i], ((unsigned char*)check.bytes)[i]);
                break;
            }
        }
        NSLog(@"Original=%@", [self asciiString]);
        NSLog(@"Decoded= %@", [check asciiString]);
        NSLog(@"stop");
    }
    return compressed;
}

- (NSString*)asciiString {
    NSMutableString * rep = [NSMutableString new];
    for (int i = 0; i < self.length; ++i) {
        unsigned char c = ((unsigned char*)self.bytes)[i];
        if (c >=0x20 && c < 0x7f) {
            [rep appendString:[NSString stringWithFormat:@"%c",c]];
        } else {
            [rep appendString:[NSString stringWithFormat:@"<%d>",c]];
        }
    }
    return rep;
}

- (NSString*)asciiStringWithMaxBytes:(NSUInteger)maxBytes {
    NSMutableString * rep = [NSMutableString new];
    for (int i = 0; i < self.length && i < maxBytes; ++i) {
        unsigned char c = ((unsigned char*)self.bytes)[i];
        if (c >=0x20 && c < 0x7f) {
            [rep appendString:[NSString stringWithFormat:@"%c",c]];
        } else {
            [rep appendString:[NSString stringWithFormat:@"<%d>",c]];
        }
    }
    if (self.length > maxBytes) {
        rep = [NSMutableString stringWithFormat:@"%@ ...[%d more bytes]", rep, self.length - maxBytes];
    }
    return rep;
}

- (NSData *) decompressWithDict:(NSArray*)dict {
    if (dict.count >= DICT_LIMIT) {
        // dict too large
        return nil;
    }
    if (COMPRESSION_TRACE) NSLog(@"DECOMPRESSING");
    if (COMPRESSION_TRACE) NSLog(@"%@", [self asciiString]);
    
    NSData * uncompressed = [self performdecompressionWithDict:dict];
        
    uncompressed = [uncompressed unescaped];
    if (COMPRESSION_TRACE) NSLog(@"uncompressed after unescape:");
    if (COMPRESSION_TRACE) NSLog(@"%@", [uncompressed asciiString]);
    return uncompressed;
}


@end
