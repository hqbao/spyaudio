#import "APIService.h"
#import <Security/SecCertificate.h> // Required for certificate handling
#import <CFNetwork/CFNetwork.h>     // Include for CFArrayRef handling

// Check if we are building for an iOS-based target (where UIDevice is available)
#if TARGET_OS_IPHONE
    // Import UIKit to access UIDevice for identifierForVendor
    #import <UIKit/UIDevice.h>
#endif

// --- Configuration Constants ---
static NSString *const HardcodedBaseURL = @"https://<domainname>:8000";
static NSString *const TargetInsecureHost = @"<domainname>";

// macOS Persistence Filename
static NSString *const kDeviceIDFilename = @".recagent_device_id";

// Your Pinned Certificate (DER format, HEX encoded)
// This is the certificate the server MUST present.
static NSString *const kPinnedCertHex = @"30820225308201cba0030201020214407b54ae718061ff919508c8d394966bd7f77e19300a06082a8648ce3d0403023074310b30090603550406130253473112301006035504080c0953696e6761706f72653112301006035504070c0953696e6761706f726531133011060355040a0c0a5472757374576f726c6431133011060355040b0c0a5472757374576f726c643113301106035504030c0a5472757374576f726c64301e170d3235313131373134343234385a170d3330313131363134343234385a306d310b30090603550406130253473112301006035504080c0953696e6761706f72653112301006035504070c0953696e6761706f7265310f300d060355040a0c06536563757265310f300d060355040b0c065365637572653114301206035504030c0b6578616d706c652e636f6d3059301306072a8648ce3d020106082a8648ce3d03010703420004fab72d5b1cfe32f35dbac250b5098024c7b99486d367a02e2944d1537e72db55bd42f640781ef7481308ae3b5aa93cc708d60f90cfccb76daf0c2ad928b18abaa3423040301d0603551d0e0416041492107517808b319dcac965457a46188f6c52fdb4301f0603551d2304183016801457fb0876d1a88a0b6fc8cf9a0733517ad5aec7da300a06082a8648ce3d0403020348003045022100f2bf52f66f0805c1f8bf90cdbc2391b2afa93ecf1b49545f01662fed60e3dd11022014590705fc8a676393c6ced3b4c8ffa8b32f0ab07e7319c8aad86ca25d880b11";


// --- Private Class Extension ---
@interface APIService ()
@property (nonatomic, strong, readwrite) NSString *baseURL;
@property (nonatomic, strong, readwrite) NSURLSession *session;
// New method declaration for dynamic device ID
- (NSString *)deviceId;
// Private method for macOS file persistence
- (NSString *)getOrCreatePersistentIDForMacOS;

// Certificate Pinning Helper
- (NSData *)dataFromHexString:(NSString *)hexString;
- (NSData *)pinnedCertificateData;

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
        
        // Initialize Custom Session for ATS Bypass / Pinning
        NSURLSessionConfiguration *configObj = [NSURLSessionConfiguration defaultSessionConfiguration];
        self.session = [NSURLSession sessionWithConfiguration:configObj delegate:self delegateQueue:nil];
        
        // Log the Device ID on startup
        NSLog(@"Initialized APIService. Device ID: %@", [self deviceId]);
    }
    return self;
}

#pragma mark - Certificate Pinning Helpers

/**
 * @brief Converts a hex string into NSData.
 * @param hexString The hex string (e.g., "DEADBEEF").
 * @return The NSData representation.
 */
- (NSData *)dataFromHexString:(NSString *)hexString {
    hexString = [[hexString lowercaseString] stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSMutableData *data = [NSMutableData new];
    unsigned char whole_byte;
    char byte_chars[3] = {'\0','\0','\0'};
    for (int i = 0; i < [hexString length] / 2; i++) {
        byte_chars[0] = [hexString characterAtIndex:i*2];
        byte_chars[1] = [hexString characterAtIndex:i*2+1];
        whole_byte = strtol(byte_chars, NULL, 16);
        [data appendBytes:&whole_byte length:1]; 
    }
    return data;
}

/**
 * @brief Returns the pinned certificate data in DER format.
 * @return NSData object of the pinned certificate.
 */
- (NSData *)pinnedCertificateData {
    // Lazy load the data from the constant hex string
    static NSData *pinnedData = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        pinnedData = [self dataFromHexString:kPinnedCertHex];
        if (pinnedData.length == 0) {
            NSLog(@"ERROR: Pinned certificate data conversion failed!");
        }
    });
    return pinnedData;
}


#pragma mark - Device Identifier Logic
// (Implementation remains unchanged from previous step, but included for completeness)

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


#pragma mark - NSURLSessionDelegate (Certificate Pinning Logic)

- (void)URLSession:(NSURLSession *)session 
                  didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge 
                    completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler {
    
    // 1. Only process challenges for server trust on our target insecure host
    if ([challenge.protectionSpace.authenticationMethod 
            isEqualToString:NSURLAuthenticationMethodServerTrust] &&
        [challenge.protectionSpace.host isEqualToString:TargetInsecureHost]) {
        
        SecTrustRef serverTrust = challenge.protectionSpace.serverTrust;
        if (!serverTrust) {
            // No server trust object provided, deny connection
            NSLog(@"[Cert Pinning] FAILED: No server trust object provided.");
            completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
            return;
        }
        
        // --- START MODERN CERTIFICATE EXTRACTION ---
        // SecTrustCopyCertificateChain is the modern replacement for SecTrustGetCertificateAtIndex
        CFArrayRef certArray = SecTrustCopyCertificateChain(serverTrust);
        if (!certArray) {
            NSLog(@"[Cert Pinning] FAILED: Could not copy certificate chain.");
            completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
            return;
        }

        SecCertificateRef leafCert = NULL;
        if (CFArrayGetCount(certArray) > 0) {
            // The leaf certificate is the first element (index 0) in the chain
            leafCert = (SecCertificateRef)CFArrayGetValueAtIndex(certArray, 0);
        }
        
        // Clean up the CFArrayRef
        CFRelease(certArray);

        if (!leafCert) {
            // Cannot get the leaf certificate, deny connection
            NSLog(@"[Cert Pinning] FAILED: Certificate chain was empty or leaf was invalid.");
            completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
            return;
        }
        // --- END MODERN CERTIFICATE EXTRACTION ---
        
        // 3. Get the raw DER data of the server certificate
        // SecCertificateCopyData is still the correct function to get the DER data.
        NSData *serverCertData = (NSData *)CFBridgingRelease(SecCertificateCopyData(leafCert));
        
        // 4. Get the pinned certificate data
        NSData *pinnedData = [self pinnedCertificateData];
        
        // 5. Compare the server's certificate data against the pinned certificate data
        if ([serverCertData isEqualToData:pinnedData]) {
            // SUCCESS: Certificate matches the pinned certificate!
            // NSLog(@"[Cert Pinning] SUCCESS: Pinned certificate match found for %@", TargetInsecureHost);
            
            // Allow connection using the server's identity
            completionHandler(NSURLSessionAuthChallengeUseCredential, 
                              [[NSURLCredential alloc] initWithTrust:serverTrust]);
            return;
        } else {
            // FAILED: Certificate does not match the pinned certificate!
            NSLog(@"[Cert Pinning] FAILED: Server certificate data MISMATCH for %@", TargetInsecureHost);
            completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
            return;
        }
    }
    
    // For all other hosts/challenges, proceed with default handling
    completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
}

#pragma mark - Public Methods (API Calls)
// (These methods are unchanged, included for context)

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