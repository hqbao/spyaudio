//
//  AudioRecorderManager.m
//  audio-recoder
//
//  Created by Hoa Quoc Bao (Baul) on 14/11/25.
//

#import "AudioRecorderManager.h"

// Note: kAppIdentifier constant is removed as we no longer use Application Support

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
        // Permission request is now a no-op on macOS for this simplified setup
        // The application's entitlements/info.plist handle mic access.
    }
    return self;
}

#pragma mark - Setup and File Paths (Adapted for Local Execution Directory)

/**
 * @brief Gets the path to the current executable directory (current working directory).
 */
- (NSURL *)getCurrentExecutionDirectoryURL {
    // For command-line tools, the current working directory is the most reliable place
    // to save files relative to where the user executed the binary.
    NSString *currentPath = [_fileManager currentDirectoryPath];
    return [NSURL fileURLWithPath:currentPath isDirectory:YES];
}

- (void)setupFileURL {
    // Get the URL for the directory where the binary is executed
    NSURL *directoryURL = [self getCurrentExecutionDirectoryURL];
    
    // Define a fixed file name for overriding
    NSString *fileName = @"single_recording.m4a";
    
    // Combine the directory URL and the file name
    _audioFileURL = [directoryURL URLByAppendingPathComponent:fileName];
    NSLog(@"Audio file location: %@", _audioFileURL.path);
    
    // Check if the file already exists to set initial canPlay state
    self.canPlay = [_fileManager fileExistsAtPath:_audioFileURL.path];
    if (self.canPlay) {
        NSLog(@"Found existing recording file.");
    }
}

/**
 * @brief Placeholder for macOS permission request, which is handled differently.
 */
- (void)requestPermission {
    // On macOS, microphone access is typically granted through app entitlements 
    // or by checking the status of AVCaptureDevice permission.
    // For a simple command-line tool, we proceed with recording and rely on 
    // the system to prompt if necessary, or fail gracefully.
    NSLog(@"Note: In macOS tools, microphone permission is handled by system settings/entitlements.");
}

#pragma mark - Recording Logic

- (void)startRecording {
    if (self.isRecording) return;
    
    // Recording settings (AAC format, compatible with macOS AVFoundation)
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
    
    // On macOS, we must prepare to record first
    if (![_audioRecorder prepareToRecord]) {
         NSLog(@"Failed to prepare audio recorder.");
         _audioRecorder = nil;
         return;
    }

    if ([_audioRecorder record]) {
        self.isRecording = YES;
        self.canPlay = NO; // Cannot play while recording
        NSLog(@"Recording started to file: %@", _audioFileURL.path);
    } else {
        NSLog(@"Failed to start recording. Check microphone access.");
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

    // Step 2: Initialize Player
    NSError *error = nil;
    // Note: AVAudioPlayer is available on macOS
    _audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:_audioFileURL error:&error];
    
    if (error) {
        NSLog(@"Playback failed to initialize (Error: %@). Path: %@", error.localizedDescription, _audioFileURL.path);
        
        // Debugging check
        NSDictionary *fileAttributes = [_fileManager attributesOfItemAtPath:_audioFileURL.path error:nil];
        NSNumber *fileSize = fileAttributes[NSFileSize];
        if (fileSize) {
             NSLog(@"File size: %@ bytes.", fileSize);
        } else {
            NSLog(@"File does not exist or attributes could not be read.");
        }
        
        _audioPlayer = nil;
        return;
    }
    
    // Step 3: Play
    _audioPlayer.delegate = self;
    
    // Must call prepareToPlay before calling play
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