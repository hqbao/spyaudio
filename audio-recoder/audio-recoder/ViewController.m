//
//  ViewController.m
//  audio-recoder
//
//  Created by Hoa Quoc Bao (Baul) on 14/11/25.
//

#import "ViewController.h"

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    self.title = @"Simple Audio Recorder";
    
    // 1. Initialize Audio Recorder Manager
    self.recorderManager = [[AudioRecorderManager alloc] init];
    self.recorderManager.delegate = self;
    
    // 2. Setup UI Elements (Centered)
    [self setupRecordButton];
    [self setupPlayButton];
    [self setupStatusLabel];
    
    // Initial UI state
    [self updateUI];
}

#pragma mark - UI Setup

- (void)setupRecordButton {
    self.recordButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.recordButton.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.recordButton addTarget:self action:@selector(recordButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    // Style for the main button
    self.recordButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
    
    [self.view addSubview:self.recordButton];
    
    // Constraints (Center in the top half)
    [NSLayoutConstraint activateConstraints:@[
        [self.recordButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.recordButton.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:120],
        [self.recordButton.widthAnchor constraintEqualToConstant:100],
        [self.recordButton.heightAnchor constraintEqualToConstant:100]
    ]];
}

- (void)setupPlayButton {
    self.playButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.playButton.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.playButton addTarget:self action:@selector(playButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.view addSubview:self.playButton];
    
    // Constraints (Below the record button)
    [NSLayoutConstraint activateConstraints:@[
        [self.playButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.playButton.topAnchor constraintEqualToAnchor:self.recordButton.bottomAnchor constant:30],
        [self.playButton.widthAnchor constraintEqualToConstant:120],
        [self.playButton.heightAnchor constraintEqualToConstant:40]
    ]];
}

- (void)setupStatusLabel {
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleTitle3];
    
    [self.view addSubview:self.statusLabel];
    
    // Constraints (Below the play button)
    [NSLayoutConstraint activateConstraints:@[
        [self.statusLabel.topAnchor constraintEqualToAnchor:self.playButton.bottomAnchor constant:20],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20]
    ]];
}

#pragma mark - Button Actions

- (void)recordButtonTapped:(UIButton *)sender {
    if (self.recorderManager.isRecording) {
        // Currently recording -> STOP
        [self.recorderManager stopRecording];
    } else {
        // Not recording -> START
        [self.recorderManager startRecording];
    }
    
    [self updateUI];
}

- (void)playButtonTapped:(UIButton *)sender {
    [self.recorderManager startPlayback];
    [self updateUI];
}

#pragma mark - UI Updates

- (void)updateUI {
    BOOL isRecording = self.recorderManager.isRecording;
    BOOL canPlay = self.recorderManager.canPlay;
    
    // --- Record/Stop Button UI ---
    UIImage *recordImage;
    UIColor *recordTintColor;
    
    if (isRecording) {
        recordImage = [UIImage systemImageNamed:@"stop.circle.fill"];
        recordTintColor = [UIColor systemRedColor]; // Red for stop
        self.statusLabel.text = @"Recording... Tap to Stop";
    } else {
        recordImage = [UIImage systemImageNamed:@"mic.circle.fill"];
        recordTintColor = [UIColor systemBlueColor]; // Blue for mic
        self.statusLabel.text = canPlay ? @"Tap to Re-record or Play" : @"Tap to Record First Clip";
    }
    
    // Animate the change for a smoother feel
    [UIView animateWithDuration:0.2 animations:^{
        [self.recordButton setImage:recordImage forState:UIControlStateNormal];
        self.recordButton.tintColor = recordTintColor;
        
        // Optional: Scale effect on press
        if (isRecording) {
            self.recordButton.transform = CGAffineTransformMakeScale(1.1, 1.1);
        } else {
            self.recordButton.transform = CGAffineTransformIdentity;
        }
        
        // --- Play Button UI ---
        [self.playButton setTitle:@"Play Last Clip" forState:UIControlStateNormal];
        // The play button is only enabled if a file exists AND we are not currently recording
        self.playButton.enabled = canPlay && !isRecording;
        self.playButton.alpha = self.playButton.enabled ? 1.0 : 0.5; // Dim if disabled
    }];
}

#pragma mark - AudioRecorderDelegate

- (void)audioRecorderDidFinishRecordingSuccessfully:(BOOL)flag {
    // Ensure UI is updated after AVFoundation finishes its processes
    [self updateUI];
}

@end
