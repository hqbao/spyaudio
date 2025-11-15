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
        [self requestPermission];
    }
    return self;
}

#pragma mark - Setup and File Paths

- (NSURL *)getDirectoryURL {
    return [_fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask][0];
}

- (void)setupFileURL {
    // Define a fixed file name for overriding
    NSString *fileName = @"single_recording.m4a";
    _audioFileURL = [[self getDirectoryURL] URLByAppendingPathComponent:fileName];
    
    // Check if the file already exists to set initial canPlay state
    self.canPlay = [_fileManager fileExistsAtPath:_audioFileURL.path];
    if (self.canPlay) {
        NSLog(@"Found existing recording file.");
    }
}

- (void)requestPermission {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *error = nil;

    // Set category for both playing and recording
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
        }
    }];
}

#pragma mark - Recording Logic

- (void)startRecording {
    if (self.isRecording) return;
    
    // Recording settings (AAC format)
    NSDictionary *settings = @{
        AVFormatIDKey: @(kAudioFormatMPEG4AAC),
        AVSampleRateKey: @44100.0,
        AVNumberOfChannelsKey: @1,
        AVEncoderAudioQualityKey: @(AVAudioQualityHigh),
    };

    NSError *error = nil;
    // Use the fixed file URL
    _audioRecorder = [[AVAudioRecorder alloc] initWithURL:_audioFileURL settings:settings error:&error];
    
    if (error) {
        NSLog(@"Could not initialize audio recorder: %@", error.localizedDescription);
        return;
    }

    _audioRecorder.delegate = self;

    if ([_audioRecorder record]) {
        self.isRecording = YES;
        self.canPlay = NO; // Cannot play while recording
        NSLog(@"Recording started to file: %@", _audioFileURL.path);
    } else {
        NSLog(@"Failed to start recording. Check device/simulator microphone access.");
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
    // Step 1: Check if file exists before attempting playback
    if (!self.canPlay) {
        NSLog(@"Playback attempt failed: No recorded file exists.");
        return;
    }
    
    [self stopPlayback]; // Stop any current playback

    // Step 2: Reactivate audio session for playback reliability
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *sessionError = nil;
    // Set category again and activate to ensure the session is ready for output
    // The previous category (PlayAndRecord) is retained, but activation is key.
    [session setActive:YES error:&sessionError];
    if (sessionError) {
        NSLog(@"Error reactivating audio session for playback: %@", sessionError.localizedDescription);
        return;
    }
    
    // Step 3: Initialize Player
    NSError *error = nil;
    _audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:_audioFileURL error:&error];
    
    if (error) {
        // This is the common failure point for "DataSource read failed"
        NSLog(@"Playback failed to initialize (DataSource read failed): %@", error.localizedDescription);
        NSLog(@"Attempted file path: %@", _audioFileURL.path);
        
        // --- Added Debugging Check ---
        // Check file size to help debug why read failed
        NSDictionary *fileAttributes = [_fileManager attributesOfItemAtPath:_audioFileURL.path error:nil];
        NSNumber *fileSize = fileAttributes[NSFileSize];
        if (fileSize) {
             NSLog(@"File exists. File size: %@ bytes.", fileSize);
            if ([fileSize longLongValue] == 0) {
                 NSLog(@"CRITICAL: The file has 0 bytes. This means the recording failed to write data.");
            }
        } else {
            NSLog(@"File does not exist or attributes could not be read.");
            self.canPlay = NO;
        }
        // -----------------------------
        
        _audioPlayer = nil;
        return;
    }
    
    // Step 4: Play
    _audioPlayer.delegate = self;
    [_audioPlayer play];
    NSLog(@"Playback started.");
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
        // Recording finished successfully
        self.canPlay = [_fileManager fileExistsAtPath:_audioFileURL.path];
        
        // Log file status to aid debugging
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
    // Cleanup after playback finishes
    _audioPlayer = nil;
    NSLog(@"Playback finished.");
}

@end
