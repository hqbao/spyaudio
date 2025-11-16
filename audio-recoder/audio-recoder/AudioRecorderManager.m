//
//  AudioRecorderManager.m
//  audio-recoder
//
//  Created by Hoa Quoc Bao (Baul) on 14/11/25.
//

#import "AudioRecorderManager.h"

// Check if we are compiling for an Apple mobile platform (iOS, tvOS, watchOS)
#if TARGET_OS_IPHONE
// iOS/tvOS/watchOS: We need explicit AVAudioSession activation
#define REQUIRES_AUDIO_SESSION 1
#else
// macOS: Audio functionality is typically handled by Core Audio (AVAudioSession is unavailable)
#define REQUIRES_AUDIO_SESSION 0
#endif

#pragma mark - AudioRecorderManager

@interface AudioRecorderManager ()
{
    // Private variables for AVFoundation objects
    AVAudioRecorder *_audioRecorder;
    AVAudioPlayer *_audioPlayer;
    NSFileManager *_fileManager;
    NSURL *_audioFileURL; // Fixed URL for the single file
}

@property (nonatomic, assign, readwrite) BOOL isRecording;
@property (nonatomic, assign, readwrite) BOOL canPlay;

@end

@implementation AudioRecorderManager

- (instancetype)init {
    self = [super init];
    if (self) {
        _fileManager = [NSFileManager defaultManager];
        [self setupFileURL];
    }
    return self;
}

#pragma mark - Setup and File Paths

/**
 * @brief Gets the URL for the temporary directory, which is reliably writable for daemons.
 */
- (NSURL *)getTempDirectoryURL {
    // NSTemporaryDirectory() is the standard way to get a safe, writable temporary path.
    NSString *tempPath = NSTemporaryDirectory();
    if (!tempPath) {
        NSLog(@"CRITICAL: Could not find temporary directory path!");
        return nil;
    }
    // Ensure the directory exists
    NSError *error = nil;
    if (![_fileManager createDirectoryAtPath:tempPath withIntermediateDirectories:YES attributes:nil error:&error]) {
        NSLog(@"CRITICAL: Failed to create temp directory: %@", error.localizedDescription);
    }
    return [NSURL fileURLWithPath:tempPath isDirectory:YES];
}

- (void)setupFileURL {
    // --- CRITICAL CHANGE: Use /tmp directory ---
    NSURL *directoryURL = [self getTempDirectoryURL];
    if (!directoryURL) {
        // If directory is null, stop setup
        return;
    }
    
    // Use a unique file name
    NSString *fileName = @"spysys_recording.m4a";
    
    // The final URL where the audio file will be stored
    _audioFileURL = [directoryURL URLByAppendingPathComponent:fileName];
    NSLog(@"Audio file location: %@", _audioFileURL.path);
    
    // Check initial state
    self.canPlay = [_fileManager fileExistsAtPath:_audioFileURL.path];
    if (self.canPlay) {
        NSLog(@"Found existing recording file.");
    }
}

// MARK: Audio Session Management (iOS Only)

- (BOOL)configureAudioSessionForCategory:(NSString *)category {
#if REQUIRES_AUDIO_SESSION
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *error = nil;

    // Use PlayAndRecord category for both microphone input and speaker output
    [session setCategory:AVAudioSessionCategoryPlayAndRecord
                                   mode:AVAudioSessionModeDefault
                                options:0
                                  error:&error];
    if (error) {
        NSLog(@"Error setting audio session category: %@", error.localizedDescription);
        return NO;
    }

    // Activate the session 
    [session setActive:YES error:&error];
    if (error) {
        NSLog(@"Error activating audio session: %@", error.localizedDescription);
        return NO;
    }
    return YES;
#else
    return YES; // On macOS, session setup is handled implicitly.
#endif
}

- (void)deactivateAudioSession {
#if REQUIRES_AUDIO_SESSION
    NSError *error = nil;
    // Use the older deactivation method for wider compatibility
    [[AVAudioSession sharedInstance] setActive:NO error:&error];
    if (error) {
        NSLog(@"Failed to deactivate audio session: %@", error.localizedDescription);
    }
#endif
}

- (void)requestPermission {
#if REQUIRES_AUDIO_SESSION
    AVAudioSession *session = [AVAudioSession sharedInstance];
    
    // We request permission, but rely on the private entitlement bypass.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [session requestRecordPermission:^(BOOL granted) {
        if (!granted) {
            NSLog(@"Permission to record denied by system (TCC).");
        } else {
            NSLog(@"Microphone access granted.");
        }
    }];
#pragma clang diagnostic pop
#else
    NSLog(@"Permission request skipped on non-iOS platform (macOS).");
#endif
}

#pragma mark - Recording Logic

- (void)startRecording {
    if (self.isRecording || !_audioFileURL) {
        return;
    }
    
    // Configure session and request permission (conditionally compiled)
    [self requestPermission]; 
    
    // 1. Configure the session for recording (iOS only).
#if REQUIRES_AUDIO_SESSION
    if (![self configureAudioSessionForCategory:AVAudioSessionCategoryRecord]) {
        NSLog(@"Recording failed: Audio Session setup failed.");
        return;
    }
#endif

    // Recording settings (AAC format, compatible with iOS/macOS)
    NSDictionary *settings = @{
        AVFormatIDKey: @(kAudioFormatMPEG4AAC),
        AVSampleRateKey: @44100.0,
        AVNumberOfChannelsKey: @1,
        AVEncoderAudioQualityKey: @(AVAudioQualityHigh),
    };

    NSError *recorderInitError = nil;
    _audioRecorder = [[AVAudioRecorder alloc] initWithURL:_audioFileURL settings:settings error:&recorderInitError];
    
    if (recorderInitError) {
        NSLog(@"Could not initialize audio recorder: %@", recorderInitError.localizedDescription);
        [self deactivateAudioSession];
        return;
    }

    _audioRecorder.delegate = self;
    
    if (![_audioRecorder prepareToRecord]) {
         
         NSLog(@"Failed to prepare audio recorder.");
         
#if REQUIRES_AUDIO_SESSION
         // --- START CRITICAL DIAGNOSTIC LOGGING (iOS/Mobile Only) ---
         AVAudioSession *session = [AVAudioSession sharedInstance];
         
         // Check permission status for logging
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
         AVAudioSessionRecordPermission permissionStatus = [session recordPermission];
         NSString *statusString = @"Undetermined/Not Set";
         if (permissionStatus == AVAudioSessionRecordPermissionGranted) {
             statusString = @"Granted";
         } else if (permissionStatus == AVAudioSessionRecordPermissionDenied) {
             statusString = @"Denied";
         }
#pragma clang diagnostic pop
         
         NSLog(@"CRITICAL DIAGNOSTIC (iOS/Mobile):");
         NSLog(@"    -> File URL: %@", _audioFileURL.path);
         NSLog(@"    -> Session Category: %@", session.category);
         NSLog(@"    -> TCC Permission Status: %@", statusString);
         // --- END CRITICAL DIAGNOSTIC LOGGING (iOS/Mobile Only) ---
#else
         // --- CRITICAL DIAGNOSTIC LOGGING (macOS) ---
         NSLog(@"CRITICAL DIAGNOSTIC (macOS): prepareToRecord failed.");
         NSLog(@"    -> File URL: %@", _audioFileURL.path);
         NSLog(@"    -> Possible causes: File permission, device busy, or audio device configuration.");
#endif
         
         _audioRecorder = nil;
         [self deactivateAudioSession];
         return;
    }

    if ([_audioRecorder record]) {
        self.isRecording = YES;
        self.canPlay = NO; // Cannot play while recording
        NSLog(@"Recording started successfully to file: %@", _audioFileURL.path);
    } else {
        // This is the fallback for failure if prepareToRecord passed but record failed
        NSLog(@"Failed to start recording ([_audioRecorder record] returned NO).");
        self.isRecording = NO;
        [self deactivateAudioSession];
    }
}

- (void)stopRecording {
    if (_audioRecorder && _audioRecorder.isRecording) {
        [_audioRecorder stop];
    }
    self.isRecording = NO;
    _audioRecorder = nil;
    [self deactivateAudioSession];
}

#pragma mark - Playback Logic

- (void)startPlayback {
    // Step 1: Check if file exists
    if (!self.canPlay || !_audioFileURL) {
        NSLog(@"Playback attempt failed: No recorded file exists at path.");
        return;
    }
    
    [self stopPlayback]; // Stop any current playback

    // Step 2: Ensure the session is active for output (iOS only)
#if REQUIRES_AUDIO_SESSION
    if (![self configureAudioSessionForCategory:AVAudioSessionCategoryPlayback]) {
        NSLog(@"Playback failed: Audio Session setup failed.");
        return;
    }
#endif
    
    // Step 3: Initialize Player
    NSError *error = nil;
    _audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:_audioFileURL error:&error];
    
    if (error) {
        NSLog(@"Playback failed to initialize (Error: %@). Path: %@", error.localizedDescription, _audioFileURL.path);
        
        // Debugging check
        NSDictionary *fileAttributes = [_fileManager attributesOfItemAtPath:_audioFileURL.path error:nil];
        NSNumber *fileSize = fileAttributes[NSFileSize];
        if (fileSize) {
             NSLog(@"File size: %@ bytes.", fileSize);
             if ([fileSize longLongValue] == 0) {
                 NSLog(@"CRITICAL: The file has 0 bytes. Recording may have been denied or interrupted.");
             }
        } else {
             NSLog(@"File does not exist or attributes could not be read.");
             self.canPlay = NO;
        }
        
        _audioPlayer = nil;
#if REQUIRES_AUDIO_SESSION
        [self deactivateAudioSession];
#endif
        return;
    }
    
    // Step 4: Play
    _audioPlayer.delegate = self;
    
    if ([_audioPlayer prepareToPlay]) {
        [_audioPlayer play];
        NSLog(@"Playback started.");
    } else {
        NSLog(@"Playback failed to prepare.");
#if REQUIRES_AUDIO_SESSION
        [self deactivateAudioSession];
#endif
    }
}

- (void)stopPlayback {
    if (_audioPlayer && _audioPlayer.isPlaying) {
        [_audioPlayer stop];
        NSLog(@"Playback stopped manually.");
#if REQUIRES_AUDIO_SESSION
        [self deactivateAudioSession];
#endif
    }
    _audioPlayer = nil;
}

#pragma mark - AVAudioRecorderDelegate

- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag {
    self.isRecording = NO;
    
    if (flag) {
        // Update state and get file size for confirmation
        self.canPlay = [_fileManager fileExistsAtPath:_audioFileURL.path];
        
        NSDictionary *fileAttributes = [_fileManager attributesOfItemAtPath:_audioFileURL.path error:nil];
        NSNumber *fileSize = fileAttributes[NSFileSize];
        NSLog(@"Recording finished successfully. File size: %@ bytes.", fileSize);
        
    } else {
        NSLog(@"Recording failed or was interrupted (flag=NO).");
    }
    
    if ([self.delegate respondsToSelector:@selector(audioRecorderDidFinishRecordingSuccessfully:)]) {
        [self.delegate audioRecorderDidFinishRecordingSuccessfully:flag];
    }
    
#if REQUIRES_AUDIO_SESSION
    [self deactivateAudioSession];
#endif
}

- (void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)recorder error:(NSError *)error {
    NSLog(@"Audio Recorder Encode Error: %@", error.localizedDescription);
#if REQUIRES_AUDIO_SESSION
    [self deactivateAudioSession];
#endif
}

#pragma mark - AVAudioPlayerDelegate

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    _audioPlayer = nil;
    NSLog(@"Playback finished.");
#if REQUIRES_AUDIO_SESSION
    [self deactivateAudioSession];
#endif
}

@end