//
//  RecordViewController.h
//  HoccerXO
//
//  Created by Pavel on 29.04.13.
//  Copyright (c) 2013 Hoccer GmbH. All rights reserved.
//

#import "TDSemiModal.h"

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@protocol AudioRecorderDelegate;

@interface RecordViewController : TDSemiModalViewController <AVAudioRecorderDelegate, AVAudioPlayerDelegate>

@property (strong, nonatomic) AVAudioRecorder *audioRecorder;
@property (strong, nonatomic) AVAudioPlayer *audioPlayer;

@property (strong, nonatomic) IBOutlet UIView *sheetView;

@property (strong, nonatomic) IBOutlet UIButton *recordStopButton;
@property (strong, nonatomic) IBOutlet UIButton *playButton;

@property (strong, nonatomic) IBOutlet UIButton *useButton;
@property (strong, nonatomic) IBOutlet UIButton *cancelButton;

@property (strong, nonatomic) IBOutlet UILabel *timeLabel;

@property (weak) id<AudioRecorderDelegate> delegate;

@property (strong, nonatomic) NSURL *audioFileURL;

@property (strong, nonatomic) NSTimer *updateTimer;

//- (IBAction)recordAudio:(id)sender;
//- (IBAction)playAudio:(id)sender;
//- (IBAction)stop:(id)sender;

@end

@protocol AudioRecorderDelegate <NSObject>

- (void)audiorecorder:(RecordViewController *)audioRecorder didRecordAudio:(NSURL *)audioFileURL;

@end