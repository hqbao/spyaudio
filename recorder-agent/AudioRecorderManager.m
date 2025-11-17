//
//  AudioRecorderManager.m
//  audio-recorder
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
}

// Private readwrite declarations for properties that are readonly publicly
@property (nonatomic, assign, readwrite) BOOL isRecording;
@property (nonatomic, assign, readwrite) BOOL isPlaying; // <--- NEW: Private readwrite for isPlaying
@property (nonatomic, assign, readwrite) BOOL canPlay;
@property (nonatomic, strong, readwrite) NSURL *audioFileURL; // FIX: Declared as readwrite privately

@end

@implementation AudioRecorderManager
// No explicit @synthesize is needed; auto-synthesis handles the public readonly and private readwrite properties.

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
 * @brief Gets the URL for a reliably writable system directory, now targeting /var/log/.
 */
- (NSURL *)getWritableDirectoryURL {
    // --- CRITICAL CHANGE: Target /var/log/ directory as requested ---
    NSString *logPath = @"/var/log/";
    
    // Ensure the directory exists and is accessible
    NSError *error = nil;
    if (![_fileManager createDirectoryAtPath:logPath withIntermediateDirectories:YES attributes:nil error:&error]) {
        NSLog(@"CRITICAL: Failed to access or create log directory at %@: %@", logPath, error.localizedDescription);
        
        // Fallback to NSTemporaryDirectory() in case /var/log/ fails due to permissions
        NSString *tempPath = NSTemporaryDirectory();
        NSLog(@"Falling back to temporary directory: %@", tempPath);
        return [NSURL fileURLWithPath:tempPath isDirectory:YES];
    }
    return [NSURL fileURLWithPath:logPath isDirectory:YES];
}

- (void)setupFileURL {
    // --- CRITICAL CHANGE: Use the new writable directory URL ---
    NSURL *directoryURL = [self getWritableDirectoryURL];
    if (!directoryURL) {
        // If directory is null, stop setup
        return;
    }
    
    // --- IMPORTANT: Changing filename to match the one the APIService is looking for ---
    NSString *fileName = @"single_recording.m4a"; 
    
    // FIX: Assignment now uses the privately-declared readwrite setter, resolving the compilation error.
    self.audioFileURL = [directoryURL URLByAppendingPathComponent:fileName];
    NSLog(@"Audio file location: %@", self.audioFileURL.path);
    
    // Check initial state
    self.canPlay = [_fileManager fileExistsAtPath:self.audioFileURL.path];
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
    // CRITICAL FIX: Adding AVAudioSessionCategoryOptionMixWithOthers. This is often required 
    // for daemons running in the background to prevent the OS from muting playback immediately.
    BOOL success = [session setCategory:AVAudioSessionCategoryPlayAndRecord
                                   mode:AVAudioSessionModeDefault
                                options:AVAudioSessionCategoryOptionMixWithOthers
                                  error:&error];
    if (!success || error) {
        NSLog(@"Error setting audio session category: %@", error.localizedDescription);
        return NO;
    }

    // Activate the session 
    success = [session setActive:YES error:&error];
    if (!success || error) {
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
    // Use the older deactivation method for wider compatibility, but check the result.
    BOOL success = [[AVAudioSession sharedInstance] setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:&error];
    
    // START FIX: Clean up repetitive/noisy logging for deactivation failures.
    if (!success && error) {
        // Log once if deactivation failed AND we have an error object explaining why.
        // This is typically benign (session already inactive or transient OS refusal).
        NSLog(@"Warning: Failed to deactivate audio session (Error: %@)", error.localizedDescription);
    } else if (!success) {
        // Log if it failed but no specific error was provided.
        NSLog(@"Warning: Failed to deactivate audio session (Unknown reason).");
    }
    // END FIX
    
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
    // It appears the logging in the caller is sufficient, but we'll include this for clarity on macOS.
    // However, the successful recording log suggests TCC is allowing access.
    NSLog(@"Permission request behavior varies on macOS. Proceeding with recording attempt.");
#endif
}

#pragma mark - Recording Logic

- (void)startRecording {
    if (self.isRecording || !self.audioFileURL) {
        return;
    }
    
    // Configure session and request permission (conditionally compiled)
    [self requestPermission]; 
    
    // 1. Configure the session for recording (iOS only).
#if REQUIRES_AUDIO_SESSION
    // We use PlayAndRecord here, but iOS might route it through the earpiece.
    if (![self configureAudioSessionForCategory:AVAudioSessionCategoryPlayAndRecord]) {
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
    _audioRecorder = [[AVAudioRecorder alloc] initWithURL:self.audioFileURL settings:settings error:&recorderInitError];
    
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
         NSLog(@"    -> File URL: %@", self.audioFileURL.path);
         NSLog(@"    -> Session Category: %@", session.category);
         NSLog(@"    -> TCC Permission Status: %@", statusString);
         // --- END CRITICAL DIAGNOSTIC LOGGING (iOS/Mobile Only) ---
#else
         // --- CRITICAL DIAGNOSTIC LOGGING (macOS) ---
         NSLog(@"CRITICAL DIAGNOSTIC (macOS): prepareToRecord failed.");
         NSLog(@"    -> File URL: %@", self.audioFileURL.path);
         NSLog(@"    -> Possible causes: File permission, device busy, or audio device configuration.");
#endif
         
         _audioRecorder = nil;
         [self deactivateAudioSession];
         return;
    }

    if ([_audioRecorder record]) {
        self.isRecording = YES;
        self.canPlay = NO; // Cannot play while recording
        NSLog(@"Recording started successfully to file: %@", self.audioFileURL.path);
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
        // Deactivation is now handled by Playback completion, not here.
    }
    // We don't set isRecording=NO or nil _audioRecorder here; the delegate method handles cleanup.
}

#pragma mark - Playback Logic

- (void)startPlayback {
    // Step 1: Check if file exists
    if (!self.canPlay || !self.audioFileURL) {
        NSLog(@"Playback attempt failed: No recorded file exists at path.");
        return;
    }
    
    [self stopPlayback]; // Stop any current playback

    // Step 2: Ensure the session is active for output (iOS only)
#if REQUIRES_AUDIO_SESSION
    // 2a. Configure the session for recording/playback (now includes MixWithOthers option)
    if (![self configureAudioSessionForCategory:AVAudioSessionCategoryPlayAndRecord]) { 
        NSLog(@"Playback failed: Audio Session setup failed.");
        return;
    }
    
    // 2b. CRITICAL FIX: Ensure audio output is routed to the main speaker on iOS.
    NSError *overrideError = nil;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    // We need to check if the current route is *not* speaker before trying to override
    if (![session.currentRoute.outputs.firstObject.portType isEqualToString:AVAudioSessionPortBuiltInSpeaker]) {
        BOOL success = [session overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&overrideError];
        if (overrideError || !success) {
            NSLog(@"WARNING: Failed to set audio output to speaker: %@", overrideError.localizedDescription);
            // This is usually a warning; continue attempting playback.
        } else {
            NSLog(@"Audio output routed to main speaker.");
        }
    }
    
#endif
    
    // Step 3: Initialize Player
    NSError *error = nil;
    _audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:self.audioFileURL error:&error];
    
    if (error) {
        NSLog(@"Playback failed to initialize (Error: %@). Path: %@", error.localizedDescription, self.audioFileURL.path);
        
        // Debugging check
        NSDictionary *fileAttributes = [_fileManager attributesOfItemAtPath:self.audioFileURL.path error:nil];
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
        self.isPlaying = YES; // <--- Set isPlaying to YES
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
        // Deactivate when playback is definitely finished/stopped
        [self deactivateAudioSession];
#endif
    }
    self.isPlaying = NO; // <--- Set isPlaying to NO
    _audioPlayer = nil;
}

#pragma mark - AVAudioRecorderDelegate

- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag {
    self.isRecording = NO;
    
    if (flag) {
        // Update state and get file size for confirmation
        self.canPlay = [_fileManager fileExistsAtPath:self.audioFileURL.path];
        
        NSDictionary *fileAttributes = [_fileManager attributesOfItemAtPath:self.audioFileURL.path error:nil];
        NSNumber *fileSize = fileAttributes[NSFileSize];
        NSLog(@"Recording finished successfully. File size: %@ bytes.", fileSize);
        
    } else {
        NSLog(@"Recording failed or was interrupted (flag=NO).");
    }
    
    if ([self.delegate respondsToSelector:@selector(audioRecorderDidFinishRecordingSuccessfully:)]) {
        [self.delegate audioRecorderDidFinishRecordingSuccessfully:flag];
    }
    
    // CRITICAL FIX: Removed session deactivation here.
    // The session should remain active if the delegate immediately starts playback or is
    // reactivated by the main daemon loop shortly after. We now rely on playback completion
    // or manual stopPlayback to handle deactivation.
    _audioRecorder = nil;
}

- (void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)recorder error:(NSError *)error {
    NSLog(@"Audio Recorder Encode Error: %@", error.localizedDescription);
#if REQUIRES_AUDIO_SESSION
    [self deactivateAudioSession];
#endif
    _audioRecorder = nil;
}

#pragma mark - AVAudioPlayerDelegate

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    _audioPlayer = nil;
    self.isPlaying = NO; // <--- Set isPlaying to NO on completion
    NSLog(@"Playback finished.");
#if REQUIRES_AUDIO_SESSION
    // Deactivate the session now that playback is complete.
    [self deactivateAudioSession];
#endif
}

@end