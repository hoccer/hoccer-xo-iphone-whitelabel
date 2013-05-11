//
//  Attachment.m
//  HoccerXO
//
//  Created by David Siegel on 12.03.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "Attachment.h"
#import "HXOMessage.h"
#import "HXOBackend.h"
#import "AppDelegate.h"
#import "CryptingInputStream.h"
#import "HXOUserDefaults.h"
#import "UIImage+ScaleAndCrop.h"
#import "ABPersonVCardCreator.h"
#import "ABPersonCreator.h"
#import "Vcard.h"
#import "NSData+Base64.h"

#import "NSString+StringWithData.h"

#import <Foundation/NSURL.h>
#import <MediaPlayer/MPMoviePlayerController.h>
#import <MobileCoreServices/UTType.h>
#import <MobileCoreServices/UTCoreTypes.h>
#import <AVFoundation/AVAsset.h>
#import <AVFoundation/AVFoundation.h>
#import <AddressBookUI/AddressBookUI.h>

@implementation Attachment
{
    NSString * _verbosityLevel;
    NSError * _transferError;
}

@dynamic localURL;
@dynamic mimeType;
@dynamic assetURL;
@dynamic mediaType;
@dynamic ownedURL;
@dynamic humanReadableFileName;
@dynamic contentSize;
@dynamic aspectRatio;

@dynamic remoteURL;
@dynamic transferSize;
@dynamic cipherTransferSize;
@dynamic cipheredSize;
@dynamic transferFailures;
@dynamic previewImageData;

@dynamic message;

@dynamic transferPaused;
@dynamic transferAborted;

@dynamic attachmentJsonString;
@dynamic attachmentJsonStringCipherText;

@dynamic state;

@synthesize transferConnection = _transferConnection;
@synthesize transferError = _transferError;
@synthesize transferHttpStatusCode;
@synthesize chatBackend = _chatBackend;
@synthesize previewImage = _previewImage;
@synthesize progressIndicatorDelegate;
@synthesize decryptionEngine;
@synthesize encryptionEngine;
@synthesize transferRetryTimer;

#define CONNECTION_TRACE ([[self verbosityLevel]isEqualToString:@"trace"])


+(NSString*) getStateName:(AttachmentState)state {

NSArray * TransferStateName = @[@"detached",
                                @"empty",
                                @"transfered",
                                @"transfers exhausted",
                                @"transfering",
                                @"transfer scheduled",
                                @"upload incomplete",
                                @"download incomplete",
                                @"transfer on hold",
                                @"wants transfer",
                                @"transfer paused",
                                @"transfer aborted"];
    if (state <= kAttachmentWantsTransfer) {
        return TransferStateName[state];
    }
    return nil;
}

// The attachment state is implicitly determined by the object state; there is no state variable
// - a completed transfer is indicated when transferSize equals contentSize
// - an ongoing transfer is indicated by a non-nil transferConnection
// - a schedules retry is indicated by a non-nil transferRetryTimer
// - a manual abort is indicated by a non-nil transferAborted date
// - a manual pause is indicated by a non-nil transferPaused date
// - an automatic hold is determined by contentSize and limit settings
// - once a transfer has been started, it is no longer held by transfer limits, but can be paused or aborted 

- (AttachmentState) state {
    AttachmentState myState = [self stateX];
    NSLog(@"state=%@",[Attachment getStateName:myState]);
    return myState;
}


- (AttachmentState) stateX {
    if (self.message == nil) {
        return kAttachmentDetached;
    }
    if (self.contentSize == 0) {
        return kAttachmentEmpty;
    }
    if ([self.transferSize isEqualToNumber: self.contentSize]) {
        return kAttachmentTransfered;
    }
    long long maxRetries = [[[HXOUserDefaults standardUserDefaults] valueForKey:kHXOMaxAttachmentDownloadRetries] longLongValue];
    if (self.transferFailures > maxRetries) {
        return kAttachmentTransfersExhausted;
    }
    if (self.transferAborted != nil) {
        return kAttachmentTransferAborted;
    }
    if (self.transferPaused != nil) {
        return kAttachmentTransferPaused;
    }
    if (self.transferConnection != nil) {
        return kAttachmentTransfering;
    }
    if (self.transferRetryTimer != nil) {
        return kAttachmentTransferScheduled;
    }
    if ([self.transferSize longLongValue]> 0) {
        if ([self.message.isOutgoing boolValue] == YES) {
            return kAttachmentUploadIncomplete;
        }
        return kAttachmentDownloadIncomplete;
    }
    // now check limits
    if ([self.message.isOutgoing boolValue]) {
        long long uploadLimit = [[[HXOUserDefaults standardUserDefaults] valueForKey:kHXOAutoUploadLimit] longLongValue];
        if (uploadLimit && [self.contentSize longLongValue] > uploadLimit) {
            return kAttachmentTransferOnHold;
        }
    } else {
        // incoming
        long long downloadLimit = [[[HXOUserDefaults standardUserDefaults] valueForKey:kHXOAutoDownloadLimit] longLongValue];
        if (downloadLimit && [self.contentSize longLongValue] > downloadLimit) {
            return kAttachmentTransferOnHold;
        }
    }
    return kAttachmentWantsTransfer;
}

- (NSString *) verbosityLevel {
    if (_verbosityLevel == nil) {
        _verbosityLevel = [[HXOUserDefaults standardUserDefaults] valueForKey: @"attachmentVerbosity"];
    }
    return _verbosityLevel;
}

+ (NSNumber *) fileSize: (NSString *) fileURL withError: (NSError**) myError {
    if (myError != nil) {
        *myError = nil;
    }
    NSString * myPath = [[NSURL URLWithString: fileURL] path];
    NSNumber * result =  @([[[NSFileManager defaultManager] attributesOfItemAtPath: myPath error:myError] fileSize]);
    if (myError != nil && *myError != nil) {
        NSLog(@"ERROR: can not determine size of file '%@'", myPath);
        result = @(-1);
    }
    // NSLog(@"Attachment filesize = %@ (of file '%@')", result, myPath);
    return result;
}

- (HXOBackend*) chatBackend {
    if (_chatBackend != nil) {
        return _chatBackend;
    }
    
    _chatBackend = ((AppDelegate*)[[UIApplication sharedApplication] delegate]).chatBackend;
    return _chatBackend;
    
}

- (NSURL *) contentURL {
    if (self.localURL != nil) {
        return [NSURL URLWithString: self.localURL];
    } else if (self.assetURL != nil) {
        return [NSURL URLWithString: self.assetURL];
    }
    return nil;
};

- (NSURL *) otherContentURL {
    if (self.localURL != nil) {
        if (self.assetURL != nil) {
            return [NSURL URLWithString: self.assetURL];
        }
    }
    return nil;
};

- (void) useURLs:(NSString *)theURL anOtherURL:(NSString *)theOtherURL {
    NSURL * url = [NSURL URLWithString: theURL];
    if ([url.scheme isEqualToString: @"file"]) {
        self.localURL = theURL;
    } else if ([url.scheme isEqualToString: @"assets-library"] || [url.scheme isEqualToString: @"ipod-library"]) {
        self.assetURL = theURL;
    } else {
        NSLog(@"ERROR:unhandled URL scheme %@", url.scheme);
    }
    if (theOtherURL != nil) {
        NSURL* anOtherUrl = [NSURL URLWithString: theOtherURL];
        if ([anOtherUrl.scheme isEqualToString: @"file"]) {
            self.localURL = theOtherURL;
        } else if ([anOtherUrl.scheme isEqualToString: @"assets-library"] || [url.scheme isEqualToString: @"ipod-library"]) {
            self.assetURL = theOtherURL;
        } else {
            NSLog(@"ERROR: unhandled URL otherURL scheme %@", anOtherUrl.scheme);
        }
    }
    if (self.mimeType == nil && self.localURL != nil) {
        self.mimeType = [Attachment mimeTypeFromURLExtension: self.localURL];
    }
    if (self.mimeType == nil && self.assetURL != nil) {
        self.mimeType = [Attachment mimeTypeFromURLExtension: self.assetURL];
    }
    
    NSError *myError = nil;
    if (self.localURL != nil) {
        self.contentSize = [Attachment fileSize: self.localURL withError:&myError];
    } else  if (self.assetURL != nil) {
        [self assetSizer:^(int64_t theSize, NSError * theError) {
            self.contentSize = @(theSize);
            // NSLog(@"Asset Size = %@ (of file '%@')", self.contentSize, self.assetURL);
        } url:self.assetURL];
    }
}

// loads or creates an image representation of the attachment and calls ImageLoaderBlock when ready
// Note: this function will not modify attachment object
- (void) loadImage: (ImageLoaderBlock) block {
    if ([self.mediaType isEqualToString: @"image"]) {
        [self loadImageAttachmentImage: block];
    } else if ([self.mediaType isEqualToString: @"video"]) {
        [self loadVideoAttachmentImage: block];
    } else if ([self.mediaType isEqualToString: @"audio"]) {
        [self loadAudioAttachmentImage: block];
    } else if ([self.mediaType isEqualToString: @"vcard"]) {
        [self loadVcardAttachmentImage: block];
    } else if ([self.mediaType isEqualToString: @"geolocation"]) {
        [self loadGeoLocationAttachmentImage: block];
    } else {
        NSLog(@"WARNING - Attachment loadImage: unhandled attachment type %@", self.mediaType);
    }
}


- (void) setPreviewImageFromImage:(UIImage*) theFullImage {
    float previewWidth = [[[HXOUserDefaults standardUserDefaults] valueForKey:kHXOPreviewImageWidth] floatValue];
    if (previewWidth > theFullImage.size.width) {
        previewWidth = theFullImage.size.width; // avoid scaling up preview
    }
    if (!(self.aspectRatio > 0)) {
        [self setAspectRatioForImage:theFullImage];
    }
    self.previewImage = [theFullImage imageScaledToSize:CGSizeMake(previewWidth, previewWidth/self.aspectRatio)];

#if 0
    // as a result of this benchwork we use JPEG previews;
    // JPEG previews are 5-10 times smaller on disk and compression is
    // 5-10 times faster; decompression takes only 10-20% longer and
    // are negligable anyway (< 1ms)
    // preview sizes with a width of 200 (which is 400 pixels on 
    NSDate * start = [NSDate date];
    NSData * myJPEG = UIImageJPEGRepresentation(self.previewImage, 0.9);
    NSDate * jpgReady = [NSDate date];
    NSData * myPNG = UIImagePNGRepresentation(self.previewImage);
    NSDate * pngReady = [NSDate date];
    
    NSDate * startL = [NSDate date];
    UIImage * myJPEGImage = [UIImage imageWithData:myJPEG];
    NSDate * jpgReadyL = [NSDate date];
    UIImage * myPNGImage = [UIImage imageWithData:myPNG];
    NSDate * pngReadyL = [NSDate date];
    
    NSLog(@"PNG size = %d, create time %f, load time %f", myPNG.length, [pngReady timeIntervalSinceDate:jpgReady],[pngReadyL timeIntervalSinceDate:pngReadyL]);
    NSLog(@"JPG size = %d, create time %f, load time %f", myJPEG.length, [jpgReady timeIntervalSinceDate:start],[jpgReadyL timeIntervalSinceDate:startL]);
    
    NSLog(@"JPG orienation = %d, PNG orientation = %d", myJPEGImage.imageOrientation, myPNGImage.imageOrientation);
    NSLog(@"JPG scale = %f, PNG scale = %f", myJPEGImage.scale, myPNGImage.scale);
    self.previewImageData = myJPEG;
#else
    self.previewImageData = UIImageJPEGRepresentation(self.previewImage, 0.9);
#endif
}

- (void) setAspectRatioForImage:(UIImage*) theImage {
    self.aspectRatio = (double)(theImage.size.width) / theImage.size.height;
}

- (void) loadPreviewImageIntoCacheWithCompletion:(CompletionBlock)finished {
    // NSLog(@"loadPreviewImageIntoCacheWithCompletion");
    if (self.previewImageData != nil) {
        // NSLog(@"loadPreviewImageIntoCacheWithCompletion:loading from database");
        // NSDate * start = [NSDate date];
        self.previewImage = [UIImage imageWithData:self.previewImageData];
        // NSLog(@"loadPreviewImageIntoCacheWithCompletion:loading from database took %f ms.", -[start timeIntervalSinceNow]*1000);
        if (!(self.aspectRatio > 0)) {
            [self setAspectRatioForImage:self.previewImage];
        }
        if (finished != nil) {
            if (self.previewImage != nil) {
                finished(nil);
            } else {
                NSString * myDescription = @"Attachment could not load preview image from database";
                finished([NSError errorWithDomain:@"com.hoccer.xo.attachment" code: 670 userInfo:@{NSLocalizedDescriptionKey: myDescription}]);
            }
        }
    } else {
        // create preview by loading full size image
        [self loadImage:^(UIImage* theImage, NSError* error) {
            // NSLog(@"loadImage for preview done");
            if (theImage) {
                [self setPreviewImageFromImage:theImage];
                if (finished != nil) {
                    finished(nil);
                }
            } else {
                NSLog(@"ERROR: Failed to get image: %@", error);
                if (finished != nil) {
                    finished(error);
                }
            }
        }];
    }
}


+ (BOOL) tooLargeImage:(UIImage *)theFullImage {
    NSInteger photoQualityKiloPixelSetting = [[[HXOUserDefaults standardUserDefaults] objectForKey:@"photoQuality"] integerValue];
    double fullKiloPixelCount = theFullImage.size.height * theFullImage.size.width / 1000.0;
    if (photoQualityKiloPixelSetting == 0 || fullKiloPixelCount <= photoQualityKiloPixelSetting) {
        return NO;
    }
    return YES;
}


+ (UIImage *) qualityAdjustedImage:(UIImage *)theFullImage {
    NSInteger photoQualityKiloPixelSetting = [[[HXOUserDefaults standardUserDefaults] objectForKey:@"photoQuality"] integerValue];
    double fullKiloPixelCount = theFullImage.size.height * theFullImage.size.width / 1000.0;
    if (photoQualityKiloPixelSetting == 0 || fullKiloPixelCount <= photoQualityKiloPixelSetting) {
        return theFullImage;
    }
    // too many pixels for our quality setting, lets reduce
    double reductionFactor = sqrt(fullKiloPixelCount / photoQualityKiloPixelSetting);
    CGSize newSize = CGSizeMake((int)(theFullImage.size.width/reductionFactor), (int)(theFullImage.size.height/reductionFactor));
    NSLog(@"qualityAdjustedImage: original kpix %f, limit kpix %ld, new kpix %f",fullKiloPixelCount, (long)photoQualityKiloPixelSetting, newSize.width*newSize.height/1000);
    return [theFullImage imageScaledToSize:newSize];
}


- (void) makeImageAttachment:(NSString *)theURL anOtherURL:(NSString *)otherURL image:(UIImage*)theImage withCompletion:(CompletionBlock)completion  {
    self.mediaType = @"image";
    
    [self useURLs: theURL anOtherURL:otherURL];
    
    if (self.mimeType == nil) {
        NSLog(@"WARNING: could not determine mime type, setting default for image/jpeg");
        self.mimeType = @"image/jpeg";        
    }
    
    if (theImage != nil) {
        [self setPreviewImageFromImage:theImage];
        if (completion != nil) {
            completion(nil);
        }
    } else {
        [self loadPreviewImageIntoCacheWithCompletion: completion];
    }
}

- (void) makeVideoAttachment:(NSString *)theURL anOtherURL:(NSString *)theOtherURL withCompletion:(CompletionBlock)completion{
    self.mediaType = @"video";
    
    [self useURLs: theURL anOtherURL: theOtherURL];
    
    if (self.mimeType == nil) {
        NSLog(@"WARNING: could not determine mime type, setting default for video/quicktime");
        self.mimeType = @"video/quicktime";
    }

    [self loadPreviewImageIntoCacheWithCompletion: completion];
}

- (void) makeAudioAttachment:(NSString *)theURL anOtherURL:(NSString *)theOtherURL withCompletion:(CompletionBlock)completion{
    // TODO: handle also mp3 etc.
    self.mediaType = @"audio";
    self.mimeType = @"audio/mp4";

    // NSLog(@"makeAudioAttachment theURL=%@, theOtherURL=%@", theURL, theOtherURL);

    [self useURLs: theURL anOtherURL: theOtherURL];
    if (self.mimeType == nil) {
        NSLog(@"WARNING: could not determine mime type, setting default for audio/mp4");
        self.mimeType = @"audio/mp4";
    }
    
    [self loadPreviewImageIntoCacheWithCompletion: completion];
}

- (void) makeVcardAttachment:(NSString *)theURL anOtherURL:(NSString *)theOtherURL withCompletion:(CompletionBlock)completion {
    self.mediaType = @"vcard";
    self.mimeType = @"text/vcard";    
    [self useURLs: theURL anOtherURL: theOtherURL];
    [self loadPreviewImageIntoCacheWithCompletion: completion];
}

- (void) makeGeoLocationAttachment: (NSString*) theURL anOtherURL: (NSString*) theOtherURL withCompletion: (CompletionBlock) completion {
    self.mediaType = @"geolocation";
    self.mimeType = @"application/json";
    [self useURLs: theURL anOtherURL: theOtherURL];
    [self loadPreviewImageIntoCacheWithCompletion: completion];
}

// works only for geolocations right now 
- (void) loadAttachmentDict:(DictLoaderBlock) block {
    if (![self.mediaType isEqualToString:@"geolocation"]) {
        block(nil, nil);
        return;        
    }
    if (self.localURL == nil) {
        block(nil, nil);
        return;
    }
    NSData * jsonData = [NSData dataWithContentsOfURL: self.contentURL];
    NSError * error;
    NSDictionary * geoLocation = [NSJSONSerialization JSONObjectWithData: jsonData options: 0 error: & error];
    if (geoLocation == nil) {
        block(nil, error);
        return;
    }
    block(geoLocation, nil);
}


- (void) assetSizer: (SizeSetterBlock) block url:(NSString*)theAssetURL {
    // NSLog(@"assetSizer");
    ALAssetsLibraryAssetForURLResultBlock resultblock = ^(ALAsset *myasset)
    {
        // NSLog(@"assetSizer result");
        ALAssetRepresentation *rep = [myasset defaultRepresentation];
        int64_t mySize = [rep size];
        // NSLog(@"assetSizer calling block");
        block(mySize, nil);
        // NSLog(@"assetSizer calling ready");
    };
    
    ALAssetsLibraryAccessFailureBlock failureblock  = ^(NSError *myerror)
    {
        NSLog(@"ERROR: Failed to get asset %@ from asset library: %@", theAssetURL, [myerror localizedDescription]);
        block(0, myerror);
    };
    
    ALAssetsLibrary* assetslibrary = [[ALAssetsLibrary alloc] init];
    [assetslibrary assetForURL: [NSURL URLWithString: theAssetURL]
                   resultBlock: resultblock
                  failureBlock: failureblock];

}

#if CHEESY_PLAYER
- (void) loadVideoAttachmentImage: (ImageLoaderBlock) block {

    // synchronous loading, maybe make it async at some point
    MPMoviePlayerController * movie = [[MPMoviePlayerController alloc]
                                       initWithContentURL:[NSURL URLWithString:self.localURL]];
    UIImage * myImage = [movie thumbnailImageAtTime:0.0 timeOption:MPMovieTimeOptionExact];
    block(myImage, nil);
}

#else

- (void) loadVideoAttachmentImage: (ImageLoaderBlock) block {
    
    AVURLAsset * asset = [[AVURLAsset alloc] initWithURL:[NSURL URLWithString:self.localURL] options:nil];
    AVAssetImageGenerator *generate = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    NSError *err = NULL;
    CMTime time = CMTimeMake(1, 60);
    CGImageRef imgRef = [generate copyCGImageAtTime:time actualTime:NULL error:&err];
    
    // NSLog(@"loadVideoAttachmentImage err==%@, imageRef==%@", err, imgRef);
    
    block([[UIImage alloc] initWithCGImage:imgRef], nil);
}
#endif

+ (NSArray *)artworksForFileAtFileURL:(NSString *)fileURL {
    NSMutableArray *artworkImages = [NSMutableArray array];
    NSURL *URL = [NSURL URLWithString: fileURL];
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:URL options:nil];
    NSArray *artworks = [AVMetadataItem metadataItemsFromArray:asset.commonMetadata  withKey:AVMetadataCommonKeyArtwork keySpace:AVMetadataKeySpaceCommon];
    
    for (AVMetadataItem *i in artworks)
    {
        NSString *keySpace = i.keySpace;
        UIImage *im = nil;
        
        if ([keySpace isEqualToString:AVMetadataKeySpaceID3])
        {
            NSDictionary *d = [i.value copyWithZone:nil];
            im = [UIImage imageWithData:[d objectForKey:@"data"]];
        }
        else if ([keySpace isEqualToString:AVMetadataKeySpaceiTunes])
            im = [UIImage imageWithData:[i.value copyWithZone:nil]];
        
        if (im)
            [artworkImages addObject:im];
    }
    // NSLog(@"array description is %@", [artworkImages description]);
    return artworkImages;
}

- (void) loadAudioAttachmentImage: (ImageLoaderBlock) block {
    if (self.localURL == nil) {
        block(nil, nil);
        return;
    }
    // TODO - find a way how to retrieve artwork from an a file
    NSArray * myArtworkImages = [[self class]artworksForFileAtFileURL: self.localURL];
    if ([myArtworkImages count]) {
        UIImage * myfirstImage = myArtworkImages[0];
        block(myfirstImage, nil);
    } else {
        block([UIImage imageNamed:@"audio_leer.png"], nil);
    }
}

- (void) loadVcardAttachmentImage: (ImageLoaderBlock) block {
    if (self.localURL == nil) {
        block(nil, nil);
        return;
    }
    Vcard * myVcard = [[Vcard alloc] initWithVcardURL:self.contentURL];
    if (myVcard != nil) {
        UIImage * myPreviewImage = [myVcard previewImageWithScale:0];
        if (myPreviewImage) {
            block(myPreviewImage, nil);
            return;
        }
    }
    block([UIImage imageNamed:@"vcard_error_preview.png"], nil);
}

- (void) loadGeoLocationAttachmentImage: (ImageLoaderBlock) block {

    [self loadAttachmentDict:^(NSDictionary * geoLocation, NSError * error) {
        if (geoLocation != nil) {
            NSData * imageData = [NSData dataWithBase64EncodedString: geoLocation[@"previewImage"]];
            block([UIImage imageWithData: imageData], nil);
        } else {
            block(nil, error);
        }
    }];
}

- (void) loadImageAttachmentImage: (ImageLoaderBlock) block {
    if (self.localURL != nil) {
        block([UIImage imageWithContentsOfFile: [[NSURL URLWithString: self.localURL] path]], nil);
    } else if (self.assetURL != nil) {
        // NSLog(@"loadImageAttachmentImage assetURL");
        //TODO: handle different resolutions. For now just load a representation that is suitable for a chat bubble
        ALAssetsLibraryAssetForURLResultBlock resultblock = ^(ALAsset *myasset)
        {
            // NSLog(@"loadImageAttachmentImage assetURL result");
            ALAssetRepresentation *rep = [myasset defaultRepresentation];
            //CGImageRef iref = [rep fullResolutionImage];
            CGImageRef iref = [rep fullScreenImage];
            if (iref) {
                // NSLog(@"loadImageAttachmentImage assetURL calling block");
                block([UIImage imageWithCGImage:iref], nil);
                // NSLog(@"loadImageAttachmentImage assetURL calling block done");
            }
        };
        
        //
        ALAssetsLibraryAccessFailureBlock failureblock  = ^(NSError *myerror)
        {
            NSLog(@"ERROR: Failed to get image %@ from asset library: %@", self.localURL, [myerror localizedDescription]);
            block(nil, myerror);
        };
        
        if(self.assetURL && [self.assetURL length])
        {
            ALAssetsLibrary* assetslibrary = [[ALAssetsLibrary alloc] init];
            [assetslibrary assetForURL: [NSURL URLWithString: self.assetURL]
                           resultBlock: resultblock
                          failureBlock: failureblock];
        }
    } else {
        NSLog(@"ERROR: no image url");
        block(nil, nil);
    }
}

- (void) assetDataLoader: (DataSetterBlock) block url:(NSString*)theAssetURL {
    
    ALAssetsLibraryAssetForURLResultBlock resultblock = ^(ALAsset *myasset)
    {
        ALAssetRepresentation *rep = [myasset defaultRepresentation];
        NSError * myError = nil;
        int64_t mySize = [rep size];
        Byte *buffer = (Byte *)malloc(mySize);
        NSUInteger bufferLen = [rep getBytes: buffer fromOffset:0 length:mySize error:&myError];
        NSData * myData = [NSData dataWithBytesNoCopy: buffer length: bufferLen];
        block(myData, myError);
    };
    
    ALAssetsLibraryAccessFailureBlock failureblock  = ^(NSError *myerror)
    {
        NSLog(@"ERROR: Failed to get asset %@ from asset library: %@", theAssetURL, [myerror localizedDescription]);
        block(0, myerror);
    };
    
    ALAssetsLibrary* assetslibrary = [[ALAssetsLibrary alloc] init];
    [assetslibrary assetForURL: [NSURL URLWithString: theAssetURL]
                   resultBlock: resultblock
                  failureBlock: failureblock];
    
}

- (void) assetStreamLoader: (StreamSetterBlock) block url:(NSString*)theAssetURL {
    
    ALAssetsLibraryAssetForURLResultBlock resultblock = ^(ALAsset *myasset)
    {
        ALAssetRepresentation *rep = [myasset defaultRepresentation];
        // NSLog(@"Attachment assetStreamLoader for self.assetURL=%@", self.self.assetURL);
    /*
        NSString * myPath = [rep filename];
        NSInputStream * myStream = [NSInputStream inputStreamWithFileAtPath:myPath];
        NSLog(@"Attachment assetStreamLoader returning input stream for file at path=%@", myPath);
     */
        // Just for testing purposes, we need a AssetInputStream here
        NSError * myError = nil;
        int64_t mySize = [rep size];
        Byte *buffer = (Byte *)malloc(mySize);
        NSUInteger bufferLen = [rep getBytes: buffer fromOffset:0 length:mySize error:&myError];
        NSData * myData = [NSData dataWithBytesNoCopy: buffer length: bufferLen];
        NSInputStream * myStream = [NSInputStream inputStreamWithData: myData];
        block(myStream, myError); // TODO: error handling
        return;
     };
    
    ALAssetsLibraryAccessFailureBlock failureblock  = ^(NSError *myerror)
    {
        NSLog(@"ERROR: Failed to get asset %@ from asset library: %@", theAssetURL, [myerror localizedDescription]);
        block(0, myerror);
    };
    
    ALAssetsLibrary* assetslibrary = [[ALAssetsLibrary alloc] init];
    [assetslibrary assetForURL: [NSURL URLWithString: theAssetURL]
                   resultBlock: resultblock
                  failureBlock: failureblock];
    
}

- (void) uploadData {
    // NSLog(@"Attachment:upload remoteURL=%@, attachment=%@", self.remoteURL, self );
    if ([self.message.isOutgoing isEqualToNumber: @NO]) {
        NSLog(@"ERROR: uploadAttachment called on incoming attachment");
        return;
    }
    if (self.transferConnection != nil) {
        // do something about it
        NSLog(@"upload of attachment still running");
        return;
    }
    [self withUploadData:^(NSData * myData, NSError * myError) {
        if (myError == nil) {
            // NSLog(@"Attachment:upload starting withUploadData");
            NSURLRequest *myRequest  = [self.chatBackend httpRequest:@"PUT"
                                             absoluteURI:[self remoteURL]
                                                 payloadData:myData
                                                 payloadStream:nil
                                                 headers:[self uploadHttpHeaders]
                                        ];
            self.transferConnection = [NSURLConnection connectionWithRequest:myRequest delegate:[self uploadDelegate]];
            if (progressIndicatorDelegate) {
                [progressIndicatorDelegate transferStarted];
            } else {
                NSLog(@"Attachment:uploadData - no delegate for transferStarted");
            }
        } else {
            NSLog(@"ERROR: Attachment:upload error=%@",myError);
        }
    }];
}

- (void) uploadStream {
    // NSLog(@"Attachment:upload remoteURL=%@, attachment=%@", self.remoteURL, self );
    if ([self.message.isOutgoing isEqualToNumber: @NO]) {
        NSLog(@"ERROR: uploadAttachment called on incoming attachment");
        return;
    }
    if (self.transferConnection != nil) {
        // do something about it
        // NSLog(@"upload of attachment still running");
        return;
    }
    [self withUploadStream:^(NSInputStream * myStream, NSError * myError) {
        if (myError == nil) {
            // NSLog(@"Attachment:upload starting uploadStream");
            NSData * messageKey = self.message.cryptoKey;
            NSError * myError = nil;
            encryptionEngine = [[CryptoEngine alloc]
                                       initWithOperation:kCCEncrypt
                                       algorithm:kCCAlgorithmAES128
                                       options:kCCOptionPKCS7Padding
                                       key:messageKey
                                       IV:nil
                                       error:&myError];
            CryptingInputStream * myEncryptingStream = [[CryptingInputStream alloc] initWithInputStreamAndEngine:myStream cryptoEngine:encryptionEngine];
            NSURLRequest *myRequest  = [self.chatBackend httpRequest:@"PUT"
                                                         absoluteURI:[self remoteURL]
                                                             payloadData:nil
                                                             payloadStream:myEncryptingStream
                                                             headers:[self uploadHttpHeadersWithCrypto]
                                        ];
            self.transferConnection = [NSURLConnection connectionWithRequest:myRequest delegate:[self uploadDelegate]];
            if (progressIndicatorDelegate) {
                [progressIndicatorDelegate transferStarted];
            } else {
                NSLog(@"Attachment:withUploadStream - no delegate to signal transferStarted");
            }
        } else {
            NSLog(@"ERROR: Attachment:upload error=%@",myError);
        }
    }];
}

- (void) upload {
    // [self uploadData];
    [self uploadStream];
}

- (void) download {
    // NSLog(@"Attachment download remoteURL=%@, attachment=%@", self.remoteURL, self );
    NSLog(@"Attachment download remoteURL=%@, attachment.contentSize=%@", self.remoteURL, self.contentSize );
    if ([self.message.isOutgoing isEqualToNumber: @YES]) {
        NSLog(@"ERROR: downloadAttachment called on outgoing attachment, isOutgoing = %@", self.message.isOutgoing);
        return;
    }
    if (self.transferConnection != nil) {
        // do something about it
        // NSLog(@"download of attachment still running");
        return;
    }
    
    if (self.ownedURL == nil) {
        // create new destination file for download
        NSURL *appDocDir = [((AppDelegate*)[[UIApplication sharedApplication] delegate]) applicationDocumentsDirectory];
        self.ownedURL = [self localUrlForDownloadinDirectory: appDocDir];
    } else {
        // until we use ranged requests, let us delete the file in case it is left over
        NSString * myPath = [[NSURL URLWithString: self.ownedURL] path];
        [[NSFileManager defaultManager] removeItemAtPath: myPath error:nil];
    }
    
    // NSLog(@"Attachment:download ownedURL = %@", self.ownedURL);
    // NSLog(@"Attachment:download remoteURL = %@", self.remoteURL);
    
    NSData * messageKey = self.message.cryptoKey;
    NSError * myError = nil;
    self.decryptionEngine = [[CryptoEngine alloc]
                               initWithOperation:kCCDecrypt
                               algorithm:kCCAlgorithmAES128
                               options:kCCOptionPKCS7Padding
                               key:messageKey
                               IV:nil
                               error:&myError];
    NSURLRequest *myRequest  = [self.chatBackend httpRequest:@"GET"
                                     absoluteURI:[self remoteURL]
                                        payloadData:nil
                                        payloadStream:nil
                                        headers:[self downloadHttpHeaders]
                                ];
    self.transferConnection = [NSURLConnection connectionWithRequest:myRequest delegate:[self downloadDelegate]];
    if (progressIndicatorDelegate) {
        [progressIndicatorDelegate transferStarted];
    } else {
        NSLog(@"Attachment:download - no delegate for transferStarted");
    }
}

- (void) downloadOnTimer: (NSTimer*) theTimer {
    if (theTimer != transferRetryTimer) {
        NSLog(@"WARNING: downloadOnTimer: called by strange timer");
    } else {
        transferRetryTimer = nil;
    }
    [self download];
}

- (void) uploadOnTimer: (NSTimer*) theTimer {
    if (theTimer != transferRetryTimer) {
        NSLog(@"WARNING: downloadOnTimer: called by strange timer");
    } else {
        transferRetryTimer = nil;
    }
    [self upload];
}

- (void)pressedButton: (id)sender {
    // NSLog(@"Attachment pressedButton %@", sender);
    self.transferFailures = 0;
    if ([self.message.isOutgoing isEqualToNumber: @YES]) {
        [self upload];
    } else {
        [self download];
    }
}

-(void) withUploadData: (DataSetterBlock) execution {
    if (self.localURL != nil) {
        // NSLog(@"Attachment withUploadData self.localURL=%@", self.localURL);
        NSString * myPath = [[NSURL URLWithString: self.localURL] path];
        NSData *data = [[NSFileManager defaultManager] contentsAtPath:myPath];
        // NSLog(@"Attachment return uploadData len=%d, path=%@", [data length], myPath);
        execution(data, nil); // TODO: error handling
        return;
    }
    if (self.assetURL != nil) {
        // NSLog(@"Attachment uploadData assetURL=%@", self.assetURL);
        [self assetDataLoader: execution url: self.assetURL];
        return;
    }
    execution(nil, [NSError errorWithDomain:@"HoccerXO" code:1000 userInfo: nil]);
}

-(void) withUploadStream: (StreamSetterBlock) execution {
    if (self.localURL != nil) {
        // NSLog(@"Attachment withUploadStream self.localURL=%@", self.localURL);
        NSString * myPath = [[NSURL URLWithString: self.localURL] path];
        NSInputStream * myStream = [NSInputStream inputStreamWithFileAtPath:myPath];
        // NSLog(@"Attachment returning input stream for file at path=%@", myPath);
        execution(myStream, nil); // TODO: error handling
        return;
    }
    if (self.assetURL != nil) {
        // NSLog(@"Attachment withUploadStream assetURL=%@", self.assetURL);
        [self assetStreamLoader: execution url: self.assetURL];
        return;
    }
    execution(nil, [NSError errorWithDomain:@"HoccerXO" code:1000 userInfo: nil]);
}

-(NSDictionary*) uploadHttpHeadersWithCrypto {
    NSString * myPath = nil;
    if (self.localURL != nil) {
        myPath = [[NSURL URLWithString: self.localURL] path];
    } else {
        myPath = @"unknown";
    }
    NSString *contentDisposition = [NSString stringWithFormat:@"attachment; filename=\"%@\"", myPath];
    
    self.cipheredSize = [NSNumber numberWithInteger:[self.encryptionEngine calcOutputLengthForInputLength:[self contentSize].integerValue]];
    
    NSDictionary * headers = @{@"Content-Disposition": contentDisposition,
                               @"Content-Type"       : @"application/octet-stream",
                               @"Content-Length"     : [self.cipheredSize stringValue]};
    // NSLog(@"headers=%@", headers);
    return headers;
}



-(NSDictionary*) uploadHttpHeaders {
    NSString * myPath = nil;
    if (self.localURL != nil) {
        myPath = [[NSURL URLWithString: self.localURL] path];
    } else {
        myPath = @"unknown";
    }
	
    NSString *contentDisposition = [NSString stringWithFormat:@"attachment; filename=\"%@\"", myPath];

    NSDictionary * headers = @{@"Content-Disposition": contentDisposition,
                               @"Content-Type"       : self.mimeType,
                               @"Content-Length" : [self contentSize].stringValue};
    return headers;
}

-(NSDictionary*) downloadHttpHeaders {
    return nil;
}

- (NSString *) localUrlForDownloadinDirectory: (NSURL *) theDirectory {
    NSString * myRemoteURL = [NSURL URLWithString: [self remoteURL]];
    NSString * myRemoteFileName = myRemoteURL.lastPathComponent;
    NSURL * myNewFile = [NSURL URLWithString:myRemoteFileName relativeToURL:theDirectory];
    NSString * myNewFilename = [[[myNewFile absoluteString] stringByAppendingString:@"." ] stringByAppendingString: [Attachment fileExtensionFromMimeType: self.mimeType]];
    return myNewFilename;
}

+ (NSString *) fileExtensionFromMimeType: (NSString *) theMimeType {
    if (theMimeType == nil) return nil;
    CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)(theMimeType), NULL);
    CFStringRef extension = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassFilenameExtension);
    CFRelease(uti);
    return CFBridgingRelease(extension);
}

+ (NSString *) mimeTypeFromURLExtension: (NSString *) theURLString {
    NSURL * myURL = [NSURL URLWithString: theURLString];
    if ([myURL isFileURL]) {
        return [Attachment mimeTypeFromfileExtension:[myURL pathExtension]];
    } else {
        // NSString * myExtension = [myURL pathExtension];
        // NSLog(@"mimeTypeFromfileURLExtension: Extension from non-file URL: %@ is '%@'", myURL, myExtension);
        return [Attachment mimeTypeFromfileExtension:[myURL pathExtension]];        
    }
    return nil;
}

+ (NSString *) mimeTypeFromfileExtension: (NSString *) theExtension {
    if (theExtension == nil) return nil;
    CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)(theExtension), NULL);
    CFStringRef mimetype = UTTypeCopyPreferredTagWithClass (uti, kUTTagClassMIMEType);
    CFRelease(uti);
    return CFBridgingRelease(mimetype);
}

// connection delegate methods

- (id < NSURLConnectionDelegate >) uploadDelegate {
    return self;
}

- (id < NSURLConnectionDelegate >) downloadDelegate {
    return self;
}

-(void)connection:(NSURLConnection*)connection didReceiveResponse:(NSURLResponse*)response
{
    NSHTTPURLResponse * httpResponse = (NSHTTPURLResponse *)response;
    if (connection == _transferConnection) {
        // NSLog(@"Attachment transferConnection didReceiveResponse %@, status=%ld, %@",httpResponse, (long)[httpResponse statusCode],[NSHTTPURLResponse localizedStringForStatusCode:[httpResponse statusCode]]);
        self.transferHttpStatusCode = (long)[httpResponse statusCode];
        if ((long)[httpResponse statusCode] != 200) {
            // TODO: check if this is necessary and leads to duplicate error reporting
            NSString * myDescription = [NSString stringWithFormat:@"Attachment transferConnection didReceiveResponse http status code =%ld", self.transferHttpStatusCode];
            // NSLog(@"%@", myDescription);
            self.transferError = [NSError errorWithDomain:@"com.hoccer.xo.attachment" code: 667 userInfo:@{NSLocalizedDescriptionKey: myDescription}];
            [_chatBackend performSelectorOnMainThread:@selector(downloadFailed:) withObject:self waitUntilDone:NO];
            if ([self.message.isOutgoing isEqualToNumber: @YES]) {
                [_chatBackend performSelectorOnMainThread:@selector(uploadFailed:) withObject:self waitUntilDone:NO];
            } else {
                [_chatBackend performSelectorOnMainThread:@selector(downloadFailed:) withObject:self waitUntilDone:NO];
            }
        }
    } else {
        NSLog(@"ERROR: Attachment transferConnection didReceiveResponse without valid connection");        
    }
}


-(void) appendToFile:(NSString*)fileURL thisData:(NSData *) data {
    NSURL * myURL = [NSURL URLWithString: self.ownedURL];
    NSString * myPath = [myURL path];
    NSOutputStream * stream = [[NSOutputStream alloc] initToFileAtPath: myPath append:YES];
    [stream open];
    NSUInteger left = [data length];
    NSUInteger nwr = 0;
    do {
        nwr = [stream write:[data bytes] maxLength:left];
        if (-1 == nwr) break;
        left -= nwr;
    } while (left > 0);
    if (left) {
        NSLog(@"ERROR: Attachment appendToFile, stream error: %@", [stream streamError]);
    }
    [stream close];
}

-(void)connection:(NSURLConnection*)connection didReceiveData:(NSData*)data
{
    if (connection == _transferConnection) {
        if (CONNECTION_TRACE) {NSLog(@"Attachment transferConnection didReceiveData len=%lu", (unsigned long)[data length]);}
        if ([self.message.isOutgoing isEqualToNumber: @NO]) {
            NSError *myError = nil;
            NSData * plainTextData = [self.decryptionEngine addData:data error:&myError];
            if (myError != nil) {
                NSLog(@"ERROR: didReceiveData: decryption error: %@",myError);
                return;
            }
            [self appendToFile:self.ownedURL thisData:plainTextData];
            self.transferSize = [Attachment fileSize: self.ownedURL withError:&myError];
            if (progressIndicatorDelegate) {
                [progressIndicatorDelegate showTransferProgress: [self.transferSize floatValue] / [self.contentSize floatValue]];
            } else {
                NSLog(@"Attachment:didReceiveData - no delegate for showTransferProgress");
            }
        } else {
            NSLog(@"ERROR: Attachment transferConnection didReceiveData on outgoing (upload) connection");
        }
    } else {
        NSLog(@"ERROR: Attachment transferConnection didReceiveData without valid connection");
    }
}

-(void)connection:(NSURLConnection*)connection didSendBodyData:(NSInteger)bytesWritten totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite
{
    if (connection == _transferConnection) {
        if (CONNECTION_TRACE) {NSLog(@"Attachment transferConnection didSendBodyData %d", bytesWritten);}
        self.cipherTransferSize = @(totalBytesWritten);
        if (progressIndicatorDelegate) {
            [progressIndicatorDelegate showTransferProgress: (float)totalBytesWritten / (float) totalBytesExpectedToWrite];
        } else {
            NSLog(@"didSendBodyData - no delegate for showTransferProgress");
        }
    } else {
        NSLog(@"ERROR: Attachment transferConnection didSendBodyData without valid connection");
    }
}

-(void)connection:(NSURLConnection*)connection didFailWithError:(NSError*)error
{
    if (connection == _transferConnection) {
        NSLog(@"ERROR: Attachment transferConnection didFailWithError %@", error);
        self.transferConnection = nil;
        self.transferError = error;
        if (progressIndicatorDelegate) {
            [progressIndicatorDelegate transferFinished];
        } else {
            NSLog(@"didFailWithError - no delegate for transferFinished");
        }
        if ([self.message.isOutgoing isEqualToNumber: @YES]) {
            [_chatBackend performSelectorOnMainThread:@selector(uploadFailed:) withObject:self waitUntilDone:NO];
        } else {
            [_chatBackend performSelectorOnMainThread:@selector(downloadFailed:) withObject:self waitUntilDone:NO];
        }
    } else {
        NSLog(@"ERROR: Attachment transferConnection didFailWithError without valid connection");
    }
}

-(void)connectionDidFinishLoading:(NSURLConnection*)connection
{
    if (connection == _transferConnection) {
        // NSLog(@"Attachment transferConnection connectionDidFinishLoading %@", connection);
        self.transferConnection = nil;

        if ([self.message.isOutgoing isEqualToNumber: @NO]) {
            // finish download
            NSError *myError = nil;
            NSData * plainTextData = [self.decryptionEngine finishWithError:&myError];
            if (myError != nil) {
                NSLog(@"connectionDidFinishLoading: decryption error: %@",myError);
                return;
            }
            [self appendToFile:self.ownedURL thisData:plainTextData];
            self.transferSize = [Attachment fileSize: self.ownedURL withError:&myError];

            if ([self.transferSize isEqualToNumber: self.contentSize]) {
                // NSLog(@"Attachment transferConnection connectionDidFinishLoading successfully downloaded attachment, size=%@", self.contentSize);
                self.localURL = self.ownedURL;
                // TODO: maybe do some UI refresh here, or use an observer for this
                [_chatBackend performSelectorOnMainThread:@selector(downloadFinished:) withObject:self waitUntilDone:NO];
                // progressIndicatorDelegate = nil; // attachment views are only reused during transfer
                // NSLog(@"Attachment transferConnection connectionDidFinishLoading, notified backend, attachment=%@", self);
            } else {
                NSString * myDescription = [NSString stringWithFormat:@"Attachment transferConnection connectionDidFinishLoading download failed, contentSize=%@, self.transferSize=%@", self.contentSize, self.transferSize];
                // NSLog(@"%@", myDescription);
                self.transferError = [NSError errorWithDomain:@"com.hoccer.xo.attachment" code: 667 userInfo:@{NSLocalizedDescriptionKey: myDescription}];
                [_chatBackend performSelectorOnMainThread:@selector(downloadFailed:) withObject:self waitUntilDone:NO];
            }
        } else {
            // upload finished
            if ([self.cipheredSize isEqualToNumber:self.cipherTransferSize]) {
                self.transferSize = self.contentSize;
                // NSLog(@"Attachment transferConnection connectionDidFinishLoading successfully uploaded attachment, size=%@", self.contentSize);
                [_chatBackend performSelectorOnMainThread:@selector(uploadFinished:) withObject:self waitUntilDone:NO];
            } else {
                NSString * myDescription = [NSString stringWithFormat:@"Attachment transferConnection connectionDidFinishLoading size mismatch, cipheredSize=%@, cipherTransferSize=%@", self.cipheredSize, self.cipherTransferSize];
                // NSLog(@"%@", myDescription);
                self.transferError = [NSError errorWithDomain:@"com.hoccer.xo.attachment" code: 666 userInfo:@{NSLocalizedDescriptionKey: myDescription}];
                [_chatBackend performSelectorOnMainThread:@selector(uploadFailed:) withObject:self waitUntilDone:NO];
            }
        }
        if (progressIndicatorDelegate) {
            [progressIndicatorDelegate transferFinished];
        } else {
            NSLog(@"connectionDidFinishLoading - no delegate for transferFinished");
        }
    } else {
        NSLog(@"ERROR: Attachment transferConnection connectionDidFinishLoading without valid connection");
    }
}


#pragma mark - Custom Getters and Setters

- (void) setContentSize:(id)size {
    if ([size isKindOfClass:[NSString class]]) {
        NSNumberFormatter * formatter = [[NSNumberFormatter alloc] init];
        size = [formatter numberFromString: size];
    }
    [self willChangeValueForKey:@"contentSize"];
    [self setPrimitiveValue: size forKey: @"contentSize"];
    [self didChangeValueForKey:@"contentSize"];
}

- (void) setTransferSize:(id)size {
    if ([size isKindOfClass:[NSString class]]) {
        NSNumberFormatter * formatter = [[NSNumberFormatter alloc] init];
        size = [formatter numberFromString: size];
    }
    [self willChangeValueForKey:@"transferSize"];
    [self setPrimitiveValue: size forKey: @"transferSize"];
    [self didChangeValueForKey:@"transferSize"];
}

- (void) setCipherTransferSize:(id)size {
    if ([size isKindOfClass:[NSString class]]) {
        NSNumberFormatter * formatter = [[NSNumberFormatter alloc] init];
        size = [formatter numberFromString: size];
    }
    [self willChangeValueForKey:@"cipherTransferSize"];
    [self setPrimitiveValue: size forKey: @"cipherTransferSize"];
    [self didChangeValueForKey:@"cipherTransferSize"];
}

- (void) setCipheredSize:(id)size {
    if ([size isKindOfClass:[NSString class]]) {
        NSNumberFormatter * formatter = [[NSNumberFormatter alloc] init];
        size = [formatter numberFromString: size];
    }
    [self willChangeValueForKey:@"cipheredSize"];
    [self setPrimitiveValue: size forKey: @"cipheredSize"];
    [self didChangeValueForKey:@"cipheredSize"];
}

#pragma mark - Attachment JSON Wrapping

- (NSDictionary*) JsonKeys {
    return @{
             @"url": @"remoteURL",
             @"contentSize": @"contentSize",
             @"mediaType": @"mediaType",
             @"mimeType": @"mimeType",
             @"aspectRatio": @"aspectRatio",
             @"fileName": @"humanReadableFileName"
             };
}

- (NSString*) attachmentJsonString {
    NSDictionary * myRepresentation = [HXOModel createDictionaryFromObject:self withKeys:self.JsonKeys];
    NSData * myJsonData = [NSJSONSerialization dataWithJSONObject: myRepresentation options: 0 error: nil];
    NSString * myJsonUTF8String = [[NSString alloc] initWithData:myJsonData encoding:NSUTF8StringEncoding];
    return myJsonUTF8String;
}

static const NSInteger kJsonRpcAttachmentParseError  = -32700;

-  (void) setAttachmentJsonString:(NSString*) theJsonString {
    NSError * error;
    id json = [NSJSONSerialization JSONObjectWithData: [theJsonString dataUsingEncoding:NSUTF8StringEncoding] options: 0 error: &error];
    if (json == nil) {
        NSLog(@"ERROR: setAttachmentJsonString: JSON parse error: %@ on string %@", error.userInfo[@"NSDebugDescription"], theJsonString);
        return;
    }
    if ([json isKindOfClass: [NSDictionary class]]) {
        [HXOModel updateObject:self withDictionary:json withKeys:[self JsonKeys]];        
    } else {
        NSLog(@"ERROR: attachment json not encoded as dictionary, json string = %@", theJsonString);
    }
}
    
- (NSString*) attachmentJsonStringCipherText {
    return [self.message encryptString: self.attachmentJsonString];
}

-(void) setAttachmentJsonStringCipherText:(NSString*) theB64String {
    self.attachmentJsonString = [self.message decryptString:theB64String];
}

- (void) prepareForDeletion {
    [super prepareForDeletion];
    if (self.ownedURL != nil) {
        NSString * myPath = [[NSURL URLWithString: self.ownedURL] path];
        [[NSFileManager defaultManager] removeItemAtPath: myPath error:nil];
    }
}

@end
