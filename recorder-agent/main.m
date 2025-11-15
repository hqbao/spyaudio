#import <Foundation/Foundation.h>
#import "APIService.h"
#import "AudioRecorderManager.h"

// Note: kAppIdentifier constant is removed as we no longer use Application Support

// Define a class that conforms to the AudioRecorderDelegate
@interface DemoMain : NSObject <AudioRecorderDelegate>
// Keep a reference to the recorder manager
@property (nonatomic, strong) AudioRecorderManager *audioManager;
// Keep a reference to the API service
@property (nonatomic, strong) APIService *apiService;

// Dispatch group to wait for the recording to finish before proceeding
@property (nonatomic, strong) dispatch_group_t recordingGroup; 

@end

@implementation DemoMain

- (instancetype)init {
    self = [super init];
    if (self) {
        _audioManager = [[AudioRecorderManager alloc] init];
        _audioManager.delegate = self;
        _apiService = [APIService sharedInstance];
        _recordingGroup = dispatch_group_create();
    }
    return self;
}

#pragma mark - Demo Logic

- (void)startDemoSequence {
    NSLog(@"\n--- 1. Starting Audio Recording Demo ---");
    
    // Start recording for 5 seconds (adjust timing in runUntilDate)
    [self.audioManager startRecording];
    NSLog(@"Recording started. Will automatically stop in 5 seconds...");
    
    // Enter the dispatch group to signal the start of a long task (recording)
    dispatch_group_enter(self.recordingGroup); 
    
    // Schedule a timer to stop recording and continue the sequence
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.audioManager stopRecording];
        NSLog(@"Recording stopped.");
        // The delegate method (audioRecorderDidFinishRecordingSuccessfully) 
        // will call dispatch_group_leave() and trigger the next step.
    });
}

#pragma mark - AudioRecorderDelegate

// This delegate method is called when stopRecording finishes saving the file
// FIX: Corrected method signature to match the AudioRecorderDelegate protocol
- (void)audioRecorderDidFinishRecordingSuccessfully:(BOOL)flag {
    if (flag) {
        NSLog(@"\n--- 2. Recording saved successfully. Starting Playback... ---");
        
        // Start playback of the recorded file
        [self.audioManager startPlayback];
        
        // Wait another 5 seconds for playback to finish before uploading
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.audioManager stopPlayback];
            [self uploadRecordedFile];
            
            // Leave the dispatch group now that the entire sequence is done
            // NOTE: The upload is asynchronous, but we leave the group here 
            // to allow the run loop to exit once the tasks have sufficient time.
            dispatch_group_leave(self.recordingGroup); 
        });
    } else {
        NSLog(@"\n--- ERROR: Recording failed. Cannot continue demo. ---");
        // Leave the dispatch group even on failure to prevent infinite wait
        dispatch_group_leave(self.recordingGroup); 
    }
}

#pragma mark - Network Logic

// Helper method to get the file URL (must match the logic in AudioRecorderManager)
- (NSString *)getRecordedFilePath {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    // Get the current working directory path
    NSString *currentPath = [fileManager currentDirectoryPath];
    
    // The file name is fixed
    NSString *fileName = @"single_recording.m4a";
    
    // Combine the directory path and the file name
    return [currentPath stringByAppendingPathComponent:fileName];
}

- (void)uploadRecordedFile {
    NSLog(@"\n--- 3. Uploading Recorded File via APIService ---");
    
    NSString *filePath = [self getRecordedFilePath];
    NSLog(@"Attempting to upload file from path: %@", filePath);

    // ----------------------------------------------------------------------
    // Endpoint: POST http://192.168.1.10:5000/upload (Form-Data)
    [self.apiService uploadFileWithEndpoint:@"/upload" fromFile:filePath completion:^(id data, NSError *error) {
        if (error) {
            NSLog(@"[POST /upload] Upload Error: %@", error.localizedDescription);
        } else if ([data isKindOfClass:[NSDictionary class]]) {
            NSDictionary *uploadResponse = (NSDictionary *)data;
            NSLog(@"[POST /upload] Success. Filename: %@, Message: %@", uploadResponse[@"filename"], uploadResponse[@"message"]);
        } else {
            NSLog(@"[POST /upload] Success, but received unexpected data format.");
        }
        
        // Also run the GET command after the upload attempt
        [self getCommandAfterUpload];
    }];
}

- (void)getCommandAfterUpload {
    NSLog(@"\n--- 4. Getting Command After Upload ---");
    
    // ----------------------------------------------------------------------
    // Endpoint: GET http://192.168.1.10:5000/get-command
    [self.apiService fetchDataWithEndpoint:@"/get-command" completion:^(id data, NSError *error) {
        if (error) {
            NSLog(@"[GET /get-command] Request Error: %@", error.localizedDescription);
        } else if ([data isKindOfClass:[NSDictionary class]]) {
            NSDictionary *commandResponse = (NSDictionary *)data;
            NSString *command = commandResponse[@"command"];
            
            NSLog(@"[GET /get-command] Success. Command: %@, ID: %@", command, commandResponse[@"id"]);
        } else {
            NSLog(@"[GET /get-command] Success, but received unexpected data format.");
        }
        NSLog(@"\n--- Demo Sequence Complete ---");
    }];
}

@end


int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSLog(@"--- Audio Recorder and API Service Demo Started ---");
        
        // Initialize the DemoMain class which runs the sequence
        DemoMain *demo = [[DemoMain alloc] init];
        
        // Start the sequence
        [demo startDemoSequence];
        
        // Keep the current thread alive long enough for recording (5s) + playback (5s) + network ops
        // Increased time to 15 seconds to ensure all steps complete gracefully.
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:15.0]];
        
        NSLog(@"--- Audio Recorder and API Service Demo Finished ---");
    }
    return 0;
}
