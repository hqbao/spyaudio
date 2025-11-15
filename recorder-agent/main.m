#import <Foundation/Foundation.h>
#import "APIService.h"

/**
 * @brief Executes the asynchronous API calls for the demonstration.
 */
void runAPIDemo(void) {
    
    APIService *apiService = [APIService sharedInstance];
    
    // ----------------------------------------------------------------------
    // 1. Endpoint 1: GET http://192.168.1.10:5000/get-command
    // Expected Response: {"command": "WAIT", "id": 2, ...}
    [apiService fetchDataWithEndpoint:@"/get-command" completion:^(id data, NSError *error) {
        if (error) {
            NSLog(@"[GET /get-command] Request Error: %@", error.localizedDescription);
        } else if ([data isKindOfClass:[NSDictionary class]]) {
            NSDictionary *commandResponse = (NSDictionary *)data;
            NSString *command = commandResponse[@"command"];
            
            NSLog(@"[GET /get-command] Success. Command: %@, ID: %@", command, commandResponse[@"id"]);
        } else {
            NSLog(@"[GET /get-command] Success, but received unexpected data format.");
        }
    }];
    
    // ----------------------------------------------------------------------
    // 2. Endpoint 2: POST http://192.168.1.10:5000/upload (Form-Data)
    // The path to the audio file assuming it's in the same directory as the executable.
    NSString *audioFileName = @"sample_audio.mp3";
    
    // NOTE: This assumes 'sample_audio.mp3' exists in the current working directory 
    // when the daemon is run. You must ensure the file is present for testing.
    NSString *filePath = [NSString stringWithFormat:@"./%@", audioFileName];
    
    NSLog(@"[POST /upload] Attempting to upload file from path: %@", filePath);
    
    [apiService uploadFileWithEndpoint:@"/upload" fromFile:filePath completion:^(id data, NSError *error) {
        if (error) {
            NSLog(@"[POST /upload] Request Error: %@", error.localizedDescription);
        } else if ([data isKindOfClass:[NSDictionary class]]) {
            NSDictionary *uploadResponse = (NSDictionary *)data;
            NSLog(@"[POST /upload] Success. Filename: %@, Message: %@", uploadResponse[@"filename"], uploadResponse[@"message"]);
        } else {
            NSLog(@"[POST /upload] Success, but received unexpected data format.");
        }
    }];
}

int main(int argc, const char * argv[]) {
    // We use @autoreleasepool for memory management in Objective-C
    @autoreleasepool {
        NSLog(@"--- APIService Daemon Demo Started ---");
        
        // 1. Start the API demonstration calls
        runAPIDemo();
        
        // 2. Keep the current thread alive.
        // We run the main run loop in a non-blocking, date-based manner. 
        // Waiting for 10 seconds allows async network tasks to complete.
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:10.0]];
        
        NSLog(@"--- APIService Daemon Demo Finished ---");
    }
    return 0;
}
