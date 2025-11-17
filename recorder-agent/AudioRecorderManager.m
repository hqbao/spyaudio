#import "AudioRecorderManager.h"

#if TARGET_OS_IPHONE
#define REQUIRES_AUDIO_SESSION 1
#else
#define REQUIRES_AUDIO_SESSION 0
#endif

#pragma mark - Private Interface

@interface AudioRecorderManager ()
{
    AVAudioRecorder *_audioRecorder;
    AVAudioPlayer *_audioPlayer;
    NSFileManager *_fileManager;
}

@property (nonatomic, assign, readwrite) BOOL isRecording;
@property (nonatomic, assign, readwrite) BOOL isPlaying; 
@property (nonatomic, assign, readwrite) BOOL canPlay;
@property (nonatomic, strong, readwrite) NSURL *audioFileURL; 

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

- (NSURL *)getWritableDirectoryURL {
    // Target /var/log/ for persistent storage as required
    NSString *logPath = @"/var/log/";
    
    NSError *error = nil;
    if (![_fileManager createDirectoryAtPath:logPath withIntermediateDirectories:YES attributes:nil error:&error]) {
        NSLog(@"CRITICAL: Failed to access or create log directory at %@: %@", logPath, error.localizedDescription);
        
        // Fallback to temporary directory
        NSString *tempPath = NSTemporaryDirectory();
        NSLog(@"Falling back to temporary directory: %@", tempPath);
        return [NSURL fileURLWithPath:tempPath isDirectory:YES];
    }
    return [NSURL fileURLWithPath:logPath isDirectory:YES];
}

- (void)setupFileURL {
    NSURL *directoryURL = [self getWritableDirectoryURL];
    if (!directoryURL) { return; }
    
    // Use .m4a extension for AAC format
    NSString *fileName = @"single_recording.m4a"; 
    
    self.audioFileURL = [directoryURL URLByAppendingPathComponent:fileName];
    NSLog(@"Audio file location: %@", self.audioFileURL.path);
    
    self.canPlay = [_fileManager fileExistsAtPath:self.audioFileURL.path];
    if (self.canPlay) {
        // NSLog(@"Found existing recording file.");
    }
}

#pragma mark - Audio Session Management

- (BOOL)configureAudioSessionForCategory:(NSString *)category {
#if REQUIRES_AUDIO_SESSION
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *error = nil;

    BOOL success = [session setCategory:AVAudioSessionCategoryPlayAndRecord
                                   mode:AVAudioSessionModeDefault
                                options:AVAudioSessionCategoryOptionMixWithOthers
                                  error:&error];
    if (!success || error) {
        NSLog(@"Error setting audio session category: %@", error.localizedDescription);
        return NO;
    }

    success = [session setActive:YES error:&error];
    if (!success || error) {
        NSLog(@"Error activating audio session: %@", error.localizedDescription);
        return NO;
    }
    return YES;
#else
    return YES; 
#endif
}

- (void)deactivateAudioSession {
#if REQUIRES_AUDIO_SESSION
    NSError *error = nil;
    [[AVAudioSession sharedInstance] setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:&error];
    
    if (error) {
         // This is often a benign warning, but good to log it
         // NSLog(@"Warning: Failed to deactivate audio session: %@", error.localizedDescription);
    }
#endif
}

- (void)requestPermission {
#if REQUIRES_AUDIO_SESSION
    // Temporarily suppress the deprecation warning for the old permission API.
    // This is necessary because the new API (AVAudioApplication) doesn't work reliably in daemons.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    
    // We rely on entitlements/bypass, but the API still needs this call
    [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
        if (!granted) {
            NSLog(@"Microphone permission denied by TCC (system TCC bypass assumed).");
        } else {
            // NSLog(@"Microphone access granted.");
        }
    }];
    
#pragma clang diagnostic pop
#endif
}

#pragma mark - Recording Logic

- (void)startRecording {
    if (self.isRecording || !self.audioFileURL) { return; }
    
    [self requestPermission]; 
    
#if REQUIRES_AUDIO_SESSION
    if (![self configureAudioSessionForCategory:AVAudioSessionCategoryPlayAndRecord]) {
        NSLog(@"Recording failed: Audio Session setup failed.");
        return;
    }
#endif

    // Recording settings: AAC format (kAudioFormatMPEG4AAC), 44.1kHz, Mono, High Quality
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
    
    if ([_audioRecorder prepareToRecord] && [_audioRecorder record]) {
        self.isRecording = YES;
        self.canPlay = NO; 
        NSLog(@"Recording started successfully.");
    } else {
        NSLog(@"Failed to start recording.");
        _audioRecorder = nil;
        [self deactivateAudioSession];
    }
}

- (void)stopRecording {
    if (_audioRecorder && _audioRecorder.isRecording) {
        [_audioRecorder stop];
    }
}

#pragma mark - Playback Logic

- (void)startPlayback {
    if (!self.canPlay || !self.audioFileURL) { return; }
    
    [self stopPlayback];

#if REQUIRES_AUDIO_SESSION
    if (![self configureAudioSessionForCategory:AVAudioSessionCategoryPlayAndRecord]) { return; }
    
    // Override to speaker to ensure audio is audible
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
#endif
    
    NSError *error = nil;
    _audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:self.audioFileURL error:&error];
    
    if (error) {
        NSLog(@"Playback failed to initialize (Error: %@).", error.localizedDescription);
        _audioPlayer = nil;
        [self deactivateAudioSession];
        return;
    }
    
    _audioPlayer.delegate = self;
    
    if ([_audioPlayer prepareToPlay] && [_audioPlayer play]) {
        self.isPlaying = YES;
        NSLog(@"Playback started.");
    } else {
        NSLog(@"Playback failed to prepare/play.");
        [self deactivateAudioSession];
    }
}

- (void)stopPlayback {
    if (_audioPlayer && _audioPlayer.isPlaying) {
        [_audioPlayer stop];
        self.isPlaying = NO;
        // NSLog(@"Playback stopped manually.");
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
        self.canPlay = [_fileManager fileExistsAtPath:self.audioFileURL.path];
        // Log file size for confirmation
        NSDictionary *attrs = [_fileManager attributesOfItemAtPath:self.audioFileURL.path error:nil];
        NSNumber *fileSize = attrs[NSFileSize];
        NSLog(@"Recording finished successfully. File size: %@ bytes.", fileSize);
    } else {
        NSLog(@"Recording failed or was interrupted (flag=NO).");
    }
    
    if ([self.delegate respondsToSelector:@selector(audioRecorderDidFinishRecordingSuccessfully:)]) {
        [self.delegate audioRecorderDidFinishRecordingSuccessfully:flag];
    }
    
    _audioRecorder = nil;
}

- (void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)recorder error:(NSError *)error {
    NSLog(@"Audio Recorder Encode Error: %@", error.localizedDescription);
    _audioRecorder = nil;
    [self deactivateAudioSession];
}

#pragma mark - AVAudioPlayerDelegate

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    _audioPlayer = nil;
    self.isPlaying = NO;
    // NSLog(@"Playback finished.");
#if REQUIRES_AUDIO_SESSION
    [self deactivateAudioSession];
#endif
}

@end