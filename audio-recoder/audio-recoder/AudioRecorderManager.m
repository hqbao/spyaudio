#import "AudioRecorderManager.h"

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
        // Configure session upon initialization
        [self configureAudioSession];
    }
    return self;
}

#pragma mark - Setup and File Paths

/**
 * @brief Gets the URL for the standard Documents Directory, which is writable
 * and accessible on both iOS and macOS apps.
 */
- (NSURL *)getDocumentsDirectoryURL {
    // NSSearchPathForDirectoriesInDomains is the robust way to find standard system directories
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if (paths.count > 0) {
        return [NSURL fileURLWithPath:paths[0] isDirectory:YES];
    }
    NSLog(@"CRITICAL: Could not find Documents directory path!");
    return nil;
}

- (void)setupFileURL {
    NSURL *directoryURL = [self getDocumentsDirectoryURL];
    if (!directoryURL) {
        // If directory is null, stop setup
        return;
    }
    
    NSString *fileName = @"single_recording.m4a";
    
    // The final URL where the audio file will be stored
    _audioFileURL = [directoryURL URLByAppendingPathComponent:fileName];
    NSLog(@"Audio file location: %@", _audioFileURL.path);
    
    // Check initial state
    self.canPlay = [_fileManager fileExistsAtPath:_audioFileURL.path];
    if (self.canPlay) {
        NSLog(@"Found existing recording file.");
    }
}

// MARK: Audio Session Management

- (void)configureAudioSession {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *error = nil;

    // Use PlayAndRecord category for both microphone input and speaker output
    // This simplifies the session management compared to switching categories.
    [session setCategory:AVAudioSessionCategoryPlayAndRecord mode:AVAudioSessionModeDefault options:0 error:&error];
    if (error) {
        NSLog(@"Error setting audio session category: %@", error.localizedDescription);
        return;
    }

    // Activate the session
    [session setActive:YES error:&error];
    if (error) {
        NSLog(@"Error activating audio session: %@", error.localizedDescription);
        return;
    }

    // Request recording permission
    [session requestRecordPermission:^(BOOL granted) {
        if (!granted) {
            NSLog(@"Permission to record denied. The app will not be able to record.");
        } else {
            NSLog(@"Microphone access granted.");
        }
    }];
}

#pragma mark - Recording Logic

- (void)startRecording {
    if (self.isRecording || !_audioFileURL) return;
    
    // Ensure the session is ready
    [self configureAudioSession];
    
    // Recording settings (AAC format, compatible with iOS/macOS)
    NSDictionary *settings = @{
        AVFormatIDKey: @(kAudioFormatMPEG4AAC),
        AVSampleRateKey: @44100.0,
        AVNumberOfChannelsKey: @1,
        AVEncoderAudioQualityKey: @(AVAudioQualityHigh),
    };

    NSError *error = nil;
    _audioRecorder = [[AVAudioRecorder alloc] initWithURL:_audioFileURL settings:settings error:&error];
    
    if (error) {
        NSLog(@"Could not initialize audio recorder: %@", error.localizedDescription);
        return;
    }

    _audioRecorder.delegate = self;
    
    if (![_audioRecorder prepareToRecord]) {
         NSLog(@"Failed to prepare audio recorder.");
         _audioRecorder = nil;
         return;
    }

    if ([_audioRecorder record]) {
        self.isRecording = YES;
        self.canPlay = NO; // Cannot play while recording
        NSLog(@"Recording started.");
    } else {
        NSLog(@"Failed to start recording. Permission may be denied or file access failed.");
        self.isRecording = NO;
    }
}

- (void)stopRecording {
    [_audioRecorder stop];
    self.isRecording = NO;
    _audioRecorder = nil;
}

#pragma mark - Playback Logic

- (void)startPlayback {
    // Step 1: Check if file exists
    if (!self.canPlay || !_audioFileURL) {
        NSLog(@"Playback attempt failed: No recorded file exists at path.");
        return;
    }
    
    [self stopPlayback]; // Stop any current playback

    // Step 2: Ensure the session is active for output
    [self configureAudioSession];
    
    // Step 3: Initialize Player
    NSError *error = nil;
    _audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:_audioFileURL error:&error];
    
    if (error) {
        // This is the common failure point for "DataSource read failed"
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
        return;
    }
    
    // Step 4: Play
    _audioPlayer.delegate = self;
    
    if ([_audioPlayer prepareToPlay]) {
        [_audioPlayer play];
        NSLog(@"Playback started.");
    } else {
        NSLog(@"Playback failed to prepare.");
    }
}

- (void)stopPlayback {
    if (_audioPlayer && _audioPlayer.isPlaying) {
        [_audioPlayer stop];
        NSLog(@"Playback stopped manually.");
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
}

- (void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)recorder error:(NSError *)error {
    NSLog(@"Audio Recorder Encode Error: %@", error.localizedDescription);
}

#pragma mark - AVAudioPlayerDelegate

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    _audioPlayer = nil;
    NSLog(@"Playback finished.");
}

- (void)requestPermission {
    
}

@end
