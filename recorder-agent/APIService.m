#import "APIService.h"

// Define the hardcoded base URL here
static NSString *const HardcodedBaseURL = @"https://192.168.1.10:5000";
// Define the host IP that requires certificate bypass
static NSString *const TargetInsecureHost = @"192.168.1.10";
// Hardcode the Device ID used by the agent (UPDATED)
static NSString *const HardcodedDeviceID = @"01234567012345670123456701234567"; 

// --- Class Extension (Private Interface) ---
@interface APIService ()
// Redeclare readonly properties as readwrite internally
@property (nonatomic, strong, readwrite) NSString *baseURL;
@property (nonatomic, strong, readwrite) NSURLSession *session;

// Private Helper Method Declaration
- (void)handleResponseWithData:(NSData * _Nullable)data
                      response:(NSURLResponse * _Nullable)response
                         error:(NSError * _Nullable)error
             completionHandler:(APIServiceCompletionBlock _Nonnull)completionBlock;

- (NSData *)createBodyWithBoundary:(NSString *)boundary
                        parameters:(NSDictionary *)parameters
                           fileKey:(NSString *)fileKey
                          fileData:(NSData *)fileData
                          fileName:(NSString *)fileName
                          mimeType:(NSString *)mimeType
                             error:(NSError **)error;

@end
// --- END Class Extension ---

@implementation APIService

#pragma mark - Singleton and Initialization

+ (instancetype _Nonnull)sharedInstance {
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
        // Hardcode Base URL
        self.baseURL = HardcodedBaseURL;
        NSLog(@"APIService initialized with hardcoded Base URL: %@", self.baseURL);
        
        // Initialize Custom Session for ATS Bypass
        NSURLSessionConfiguration *configObj = [NSURLSessionConfiguration defaultSessionConfiguration];
        self.session = [NSURLSession sessionWithConfiguration:configObj delegate:self delegateQueue:nil];
    }
    return self;
}

#pragma mark - NSURLSessionDelegate Method (ATS Bypass)

- (void)URLSession:(NSURLSession *)session 
                  didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge 
                    completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler {
    
    // Check if the challenge is related to server trust (the invalid certificate error)
    if ([challenge.protectionSpace.authenticationMethod 
            isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        
        // Check if the host matches the local IP we want to bypass 
        if ([challenge.protectionSpace.host isEqualToString:TargetInsecureHost]) {
            
            // Bypass: Trust the certificate unconditionally
            completionHandler(NSURLSessionAuthChallengeUseCredential, 
                              [[NSURLCredential alloc] initWithTrust:challenge.protectionSpace.serverTrust]);
            
            // NSLog(@"[ATS Bypass] Certificate accepted for %@", TargetInsecureHost);
            return;
        }
    }
    
    // For all other challenges or hosts, proceed with the default handler
    completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
}

#pragma mark - Error Domain

static NSString *const APIServiceErrorDomain = @"com.yourcompany.APIServiceErrorDomain";

typedef NS_ENUM(NSInteger, APIServiceErrorCode) {
    APIServiceErrorCodeInvalidURL = 1000,
    APIServiceErrorCodeSerialization = 1001,
    APIServiceErrorCodeHTTPError = 1002,
    APIServiceErrorCodeFileNotFound = 1003,
    APIServiceErrorCodeBoundaryError = 1004,
    APIServiceErrorCodeConfigurationMissing = 1005
};

#pragma mark - Public Methods

// --- API CHANGE: /get-command adds device_id as URL query parameter ---
- (void)fetchDataWithEndpoint:(NSString * _Nonnull)endpoint
                   completion:(APIServiceCompletionBlock _Nonnull)completionBlock {
    
    if (!self.baseURL) { 
        NSError *configError = [NSError errorWithDomain:APIServiceErrorDomain
                                                  code:APIServiceErrorCodeConfigurationMissing
                                              userInfo:@{NSLocalizedDescriptionKey: @"API Service is not configured. Base URL is missing."}];
        completionBlock(nil, configError);
        return;
    }
    
    NSString *fullEndpoint = endpoint;
    // Check if this is the command endpoint and append the device ID
    if ([endpoint isEqualToString:@"/get-command"]) {
        // Safely append device_id as a URL parameter
        fullEndpoint = [NSString stringWithFormat:@"%@?device_id=%@", endpoint, HardcodedDeviceID];
    }
    
    NSString *urlString = [self.baseURL stringByAppendingString:fullEndpoint];
    NSURL *url = [NSURL URLWithString:urlString];
    
    if (!url) {
        NSError *urlError = [NSError errorWithDomain:APIServiceErrorDomain
                                                code:APIServiceErrorCodeInvalidURL
                                            userInfo:@{NSLocalizedDescriptionKey: @"Invalid URL was provided."}];
        completionBlock(nil, urlError);
        return;
    }
    
    NSURLSessionDataTask *dataTask = [self.session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self handleResponseWithData:data
                                response:response
                                   error:error
                       completionHandler:completionBlock];
        });
    }];
    
    [dataTask resume];
}


// --- API CHANGE: /set-command (implied endpoint) adds device_id to JSON body ---
- (void)postDataToEndpoint:(NSString * _Nonnull)endpoint
                   payload:(NSDictionary * _Nonnull)payload
                completion:(APIServiceCompletionBlock _Nonnull)completionBlock {
    
    if (!self.baseURL) {
        NSError *configError = [NSError errorWithDomain:APIServiceErrorDomain
                                                  code:APIServiceErrorCodeConfigurationMissing
                                              userInfo:@{NSLocalizedDescriptionKey: @"API Service is not configured. Base URL is missing."}];
        completionBlock(nil, configError);
        return;
    }
    
    NSString *urlString = [self.baseURL stringByAppendingString:endpoint];
    NSURL *url = [NSURL URLWithString:urlString];
    
    if (!url) {
        NSError *urlError = [NSError errorWithDomain:APIServiceErrorDomain
                                                code:APIServiceErrorCodeInvalidURL
                                            userInfo:@{NSLocalizedDescriptionKey: @"Invalid URL was provided."}];
        completionBlock(nil, urlError);
        return;
    }
    
    // Create mutable copy of payload to add device_id
    NSMutableDictionary *mutablePayload = [payload mutableCopy];
    
    // Check if this is the set-command endpoint and add the device ID
    if ([endpoint isEqualToString:@"/set-command"]) {
        [mutablePayload setObject:HardcodedDeviceID forKey:@"device_id"];
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    NSError *jsonError = nil;
    // Serialize the modified payload
    NSData *httpBody = [NSJSONSerialization dataWithJSONObject:mutablePayload options:0 error:&jsonError];
    
    if (jsonError) {
        NSError *serializationError = [NSError errorWithDomain:APIServiceErrorDomain
                                                          code:APIServiceErrorCodeSerialization
                                                      userInfo:@{NSLocalizedDescriptionKey: @"Failed to serialize payload to JSON.",
                                                                 @"UnderlyingError": jsonError}];
        completionBlock(nil, serializationError);
        return;
    }
    
    [request setHTTPBody:httpBody];
    
    NSURLSessionDataTask *dataTask = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self handleResponseWithData:data
                                response:response
                                   error:error
                       completionHandler:completionBlock];
        });
    }];
    
    [dataTask resume];
}

// --- API CHANGE: /upload adds device_id to multipart form parameters ---
- (void)uploadFileWithEndpoint:(NSString * _Nonnull)endpoint
                      fromFile:(NSString * _Nonnull)filePath
                    parameters:(NSDictionary * _Nullable)parameters
                    completion:(APIServiceCompletionBlock _Nonnull)completionBlock {
    
    if (!self.baseURL) {
        NSError *configError = [NSError errorWithDomain:APIServiceErrorDomain
                                                  code:APIServiceErrorCodeConfigurationMissing
                                              userInfo:@{NSLocalizedDescriptionKey: @"API Service is not configured. Base URL is missing."}];
        completionBlock(nil, configError);
        return;
    }
    
    NSString *urlString = [self.baseURL stringByAppendingString:endpoint];
    NSURL *url = [NSURL URLWithString:urlString];
    
    if (!url) {
        NSError *urlError = [NSError errorWithDomain:APIServiceErrorDomain code:APIServiceErrorCodeInvalidURL userInfo:@{NSLocalizedDescriptionKey: @"Invalid URL for file upload."}];
        completionBlock(nil, urlError);
        return;
    }

    NSData *fileData = [NSData dataWithContentsOfFile:filePath];
    if (!fileData) {
        NSError *fileError = [NSError errorWithDomain:APIServiceErrorDomain code:APIServiceErrorCodeFileNotFound userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"File not found or cannot be read at path: %@", filePath]}];
        completionBlock(nil, fileError);
        return;
    }

    // Create mutable copy of parameters to include device_id
    NSMutableDictionary *mutableParameters = parameters ? [parameters mutableCopy] : [NSMutableDictionary dictionary];
    
    // Check if this is the upload endpoint and add the device ID
    if ([endpoint isEqualToString:@"/upload"]) {
        [mutableParameters setObject:HardcodedDeviceID forKey:@"device_id"];
    }

    NSString *boundary = [NSString stringWithFormat:@"Boundary-%@", [[NSUUID UUID] UUIDString]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
    [request setValue:contentType forHTTPHeaderField:@"Content-Type"];
    
    NSError *bodyError = nil;
    NSData *httpBody = [self createBodyWithBoundary:boundary
                                        parameters:mutableParameters // Use modified parameters
                                           fileKey:@"audio"
                                          fileData:fileData
                                          fileName:[filePath lastPathComponent]
                                          mimeType:@"audio/mpeg"
                                             error:&bodyError];
    
    if (bodyError) {
        completionBlock(nil, bodyError);
        return;
    }
    
    [request setHTTPBody:httpBody];

    NSURLSessionDataTask *dataTask = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self handleResponseWithData:data 
                                response:response 
                                   error:error 
                       completionHandler:completionBlock];
        });
    }];
    
    [dataTask resume];
}

#pragma mark - Private Helper Methods

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
        // Iterate over all form parameters (now including device_id if applicable)
        [parameters enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
            if ([key isKindOfClass:[NSString class]] && [value isKindOfClass:[NSString class]]) {
                [body appendData:[[NSString stringWithFormat:@"--%@%@", boundary, lineEnd] dataUsingEncoding:NSUTF8StringEncoding]];
                [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"%@", key, lineEnd] dataUsingEncoding:NSUTF8StringEncoding]];
                [body appendData:[lineEnd dataUsingEncoding:NSUTF8StringEncoding]];
                [body appendData:[[NSString stringWithFormat:@"%@%@", value, lineEnd] dataUsingEncoding:NSUTF8StringEncoding]];
            }
        }];
    }
    
    // Append file data
    [body appendData:[[NSString stringWithFormat:@"--%@%@", boundary, lineEnd] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"%@", fileKey, fileName, lineEnd] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Type: %@%@", mimeType, lineEnd] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[lineEnd dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:fileData];
    [body appendData:[lineEnd dataUsingEncoding:NSUTF8StringEncoding]];

    [body appendData:[[NSString stringWithFormat:@"--%@--%@", boundary, lineEnd] dataUsingEncoding:NSUTF8StringEncoding]];

    if (body.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:APIServiceErrorDomain code:APIServiceErrorCodeBoundaryError userInfo:@{NSLocalizedDescriptionKey: @"Failed to construct multipart/form-data body."}];
        }
        return nil;
    }

    return body;
}

- (void)handleResponseWithData:(NSData * _Nullable)data
                      response:(NSURLResponse * _Nullable)response
                         error:(NSError * _Nullable)error
             completionHandler:(APIServiceCompletionBlock _Nonnull)completionBlock { 
    
    if (error) {
        completionBlock(nil, error);
        return;
    }
    
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    NSInteger statusCode = httpResponse.statusCode;
    
    if (statusCode < 200 || statusCode > 299) {
        NSString *localizedMessage = [NSString stringWithFormat:@"Server returned HTTP status code: %ld", (long)statusCode];
        
        NSError *httpError = [NSError errorWithDomain:APIServiceErrorDomain
                                                  code:APIServiceErrorCodeHTTPError
                                              userInfo:@{NSLocalizedDescriptionKey: localizedMessage}];
        completionBlock(nil, httpError);
        return;
    }
    
    if (!data) {
        completionBlock(nil, nil);
        return;
    }
    
    NSError *jsonError = nil;
    id responseObject = [NSJSONSerialization JSONObjectWithData:data
                                                       options:0
                                                         error:&jsonError];
    
    if (jsonError) {
        NSError *serializationError = [NSError errorWithDomain:APIServiceErrorDomain
                                                          code:APIServiceErrorCodeSerialization
                                                      userInfo:@{NSLocalizedDescriptionKey: @"Failed to parse JSON response.",
                                                                 @"UnderlyingError": jsonError}];
        completionBlock(nil, serializationError);
        return;
    }
    
    completionBlock(responseObject, nil);
}

@end