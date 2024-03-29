//
//  HXOEnvironment.m
//  HoccerXO
//
//  Created by PM on 22.03.14.
//  Copyright (c) 2014 Hoccer GmbH. All rights reserved.
//

#import "HXOEnvironment.h"
#import "HXOBackend.h"
#import "AppDelegate.h"
#import "UserProfile.h"

#import <ifaddrs.h>
#import <arpa/inet.h>

#import <SystemConfiguration/CaptiveNetwork.h>

@interface HXOEnvironment ()
{
    CLLocationManager * _locationManager;
    CLLocation * _lastLocation;
    NSDate * _lastLocationUpdate;
    HXOBackend * _chatBackend;
    BOOL _activationState;
}
@end

@implementation HXOEnvironment


static NSString * LOCATION_TYPE_GPS = @"gps";         // location from gps
static NSString * LOCATION_TYPE_WIFI = @"wifi";       // location from wifi triangulation
static NSString * LOCATION_TYPE_NETWORK = @"network"; // location provided by cellular network (cell tower)
static NSString * LOCATION_TYPE_MANUAL = @"manual";   // location was set by user
static NSString * LOCATION_TYPE_OTHER = @"other";
static NSString * LOCATION_TYPE_NONE = @"none";       // indicates that location is invalid

#define LOCATION_DEBUG NO

static HXOEnvironment *instance;

+ (HXOEnvironment*)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[HXOEnvironment alloc] init];
    });
    return instance;
}

- (id)init {
    self = [super init];
    if (self) {
		_locationManager = [[CLLocationManager alloc] init];
		_locationManager.delegate = self;
        _locationManager.desiredAccuracy = kCLLocationAccuracyBest;
        _locationManager.distanceFilter = 10.0;
        _activationState = NO;
    }
    
    return self;
}

- (void)setActivation:(BOOL)active {
    // if (active != _activationState) {
        if (active) {
            [self activate];
        } else {
            [self deactivate];
            if (self.type != nil) {
                [[self chatBackend] sendEnvironmentDestroyWithType:self.type];
            }
        }
        _activationState = active;
    // }
}

- (BOOL)isActive {
    return _activationState;
}

- (void)activate {
    if (LOCATION_DEBUG) {NSLog(@"Environment: activate");}
    [self activateLocation];
}

- (void)deactivate {
    if (LOCATION_DEBUG) {NSLog(@"Environment: deactivate");}
    [self deactivateLocation];
}

- (void)deactivateLocation{
    if (LOCATION_DEBUG) {NSLog(@"Environment: stopUpdatingLocation");}
    [_locationManager stopUpdatingLocation];
    _lastLocationUpdate = nil;
}
- (void)activateLocation{
    if (LOCATION_DEBUG) {NSLog(@"Environment: startUpdatingLocation");}
    _lastLocationUpdate = nil;
    [_locationManager startUpdatingLocation];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation
		   fromLocation:(CLLocation *)oldLocation {
    if (_lastLocation == nil) {
        _lastLocation = oldLocation;
    }
    double distance = [newLocation distanceFromLocation:_lastLocation];
    double lastUpdateAgo = [_lastLocationUpdate timeIntervalSinceNow];
    if (LOCATION_DEBUG) {NSLog(@"Environment:didUpdateToLocation: distance change = %f, last update %f secs ago, accuracy %f, last accuracy %f", distance, lastUpdateAgo, newLocation.horizontalAccuracy, _lastLocation.horizontalAccuracy);}
    
	if (distance > 10 ||  lastUpdateAgo < -30 || newLocation.horizontalAccuracy < _lastLocation.horizontalAccuracy || _lastLocationUpdate == nil) {
        _lastLocationUpdate = [NSDate date];
        _lastLocation = newLocation;
        [self sendEnvironmentUpdate];
    } else {
        if (LOCATION_DEBUG) {NSLog(@"Environment:didUpdateToLocation: distance change too small, last update too recent, accuracy not improved");}
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    
    if (error.code == kCLErrorDenied){
        UIAlertView *locationAlert = [[UIAlertView alloc]initWithTitle:NSLocalizedString(@"Title_LocationDidFail", nil) message:NSLocalizedString(@"Message_LocationDidFail", nil) delegate:nil cancelButtonTitle:NSLocalizedString(@"Button_OK", nil) otherButtonTitles:nil, nil];
        [locationAlert show];
    }
}

- (HXOBackend*) chatBackend {
    if (_chatBackend != nil) {
        return _chatBackend;
    }
    
    _chatBackend = ((AppDelegate*)[[UIApplication sharedApplication] delegate]).chatBackend;
    return _chatBackend;
    
}

- (void) sendEnvironmentUpdate {
    [[self chatBackend] sendEnvironmentUpdate];
}

- (void) updateProperties {
    self.type = @"nearby"; // for now
    self.clientId = [UserProfile sharedProfile].clientId;
    self.timestamp = [HXOBackend millisFromDate:_lastLocationUpdate];
    
    self.locationType = LOCATION_TYPE_GPS;
    
    // longitude and latitude (in this order!), array of doubles
    NSMutableArray * myGeoLocation = [[NSMutableArray alloc] init];
    [myGeoLocation addObject:[NSNumber numberWithDouble:_lastLocation.coordinate.longitude]];
    [myGeoLocation addObject:[NSNumber numberWithDouble:_lastLocation.coordinate.latitude]];
    self.geoLocation = myGeoLocation;
    
    // accuracy of the location in meters; set to 0 if accuracy not available
    self.accuracy = [NSNumber numberWithFloat:_lastLocation.horizontalAccuracy];
    
    // bssids in the vicinity of the client
    // NSArray * bssids;
    NSString * bssid = [self fetchBSSID];
    // bssid = nil; // DEBUG, remove
    if (bssid != nil) {
        NSMutableArray * bssids = [[NSMutableArray alloc] init];
        [bssids addObject:bssid];
        self.bssids = bssids;
    }
    
    // possible other location identifiers
    // NSArray * identifiers;
}

- (NSDictionary*) asDictionary {
    [self updateProperties];
    NSMutableDictionary * result = [NSMutableDictionary dictionaryWithDictionary:
                                    @{@"type": self.type,
                                      @"clientId" : self.clientId,
                                      @"timestamp" : self.timestamp,
                                      @"locationType" : self.locationType,
                                      @"geoLocation" : self.geoLocation,
                                      @"accuracy" : self.accuracy}];
    if (self.groupId != nil) {
        result[@"groupId"] = self.groupId;
    }
    if (self.bssids != nil) {
        result[@"bssids"] = self.bssids;
    }
    if (self.name != nil) {
        result[@"name"] = self.name;
    }
    return result;
}

- (NSDictionary*)fetchSSIDInfo
{
    NSArray *ifs = CFBridgingRelease(CNCopySupportedInterfaces());
    if (LOCATION_DEBUG) NSLog(@"%s: Supported interfaces: %@", __func__, ifs);
    NSDictionary * info = nil;
    for (NSString *ifnam in ifs) {
        info = CFBridgingRelease(CNCopyCurrentNetworkInfo((__bridge CFStringRef)(ifnam)));
        if (LOCATION_DEBUG) NSLog(@"%s: %@ => %@", __func__, ifnam, info);
        if (info && [info count]) {
            break;
        }
    }
    return info;
}

- (NSString*) fetchBSSID {
    NSDictionary * info = [self fetchSSIDInfo];
    if (info != nil) {
        return [HXOEnvironment normalizeBSSID:info[(__bridge NSString*)kCNNetworkInfoKeyBSSID]];
    } else {
        return nil;
    }
}

+(NSString*)normalizeBSSID:(NSString*)someBSSID {
    NSScanner *scanner = [NSScanner scannerWithString:someBSSID];
    unsigned int byte;
    NSString * result = @"";
    bool ok = YES;
    unsigned int done = 0;
    for (int i = 0; ok && i<6;++i) {
        ok = ok && [scanner scanHexInt:&byte];
        if (ok) {
            result = [result stringByAppendingString:[NSString stringWithFormat:@"%02x",byte]];
            done+=2;
        }
        if (i < 5) {
            ok = ok && [scanner scanString:@":" intoString:nil];
            if (ok) {
                result = [result stringByAppendingString:@":"];
                done+=1;
            }
        }
    }
    if (ok) {
        if (LOCATION_DEBUG) NSLog(@"%s: returning normalized BSSID=%@, orig=%@", __func__, result, someBSSID );
        return result;
    }
    NSLog(@"WARNING: %s: returning nil BSSID,  failed to parse %@ at pos %d, gathered result up to %@", __func__, someBSSID, done, result);
    return nil;
}



@end
