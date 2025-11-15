#import "APIService.h"

// Base URL for your actual audio server
// This is now set to your specific IP address and port.
static NSString *const BaseURL = @"http://192.168.1.10:5000";

@implementation APIService

#pragma mark - Singleton Implementation

// Implement the singleton pattern
+ (instancetype _Nonnull)sharedInstance {
    static APIService *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

#pragma mark - Error Domain

// Define a custom error domain for the APIService
static NSString *const APIServiceErrorDomain = @"com.yourcompany.APIServiceErrorDomain";

// Define error codes
typedef NS_ENUM(NSInteger, APIServiceErrorCode) {
    APIServiceErrorCodeInvalidURL = 1000,
    APIServiceErrorCodeSerialization = 1001,
    APIServiceErrorCodeHTTPError = 1002,
    APIServiceErrorCodeFileNotFound = 1003,
    APIServiceErrorCodeBoundaryError = 1004
};

#pragma mark - Public Methods

- (void)fetchDataWithEndpoint:(NSString * _Nonnull)endpoint
            completion:(APIServiceCompletionBlock _Nonnull)completionBlock {
    
    // 1. Construct the full URL
    NSString *urlString = [BaseURL stringByAppendingString:endpoint];
    NSURL *url = [NSURL URLWithString:urlString];
    
    if (!url) {
        // Handle invalid URL error
        NSError *urlError = [NSError errorWithDomain:APIServiceErrorDomain
                                                code:APIServiceErrorCodeInvalidURL
                                            userInfo:@{NSLocalizedDescriptionKey: @"Invalid URL was provided."}];
        completionBlock(nil, urlError);
        return;
    }
    
    // 2. Create the Request
    NSURLSession *session = [NSURLSession sharedSession];
    
    // 3. Create the Data Task
    NSURLSessionDataTask *dataTask = [session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        
        // Always dispatch the completion handler back to the main queue
        dispatch_async(dispatch_get_main_queue(), ^{
            [self handleResponseWithData:data
                                response:response
                                   error:error
                       completionHandler:completionBlock];
        });
    }];
    
    // 4. Start the Task
    [dataTask resume];
}


- (void)postDataToEndpoint:(NSString * _Nonnull)endpoint
                 payload:(NSDictionary * _Nonnull)payload
              completion:(APIServiceCompletionBlock _Nonnull)completionBlock {
    
    // 1. Construct the full URL
    NSString *urlString = [BaseURL stringByAppendingString:endpoint];
    NSURL *url = [NSURL URLWithString:urlString];
    
    if (!url) {
        NSError *urlError = [NSError errorWithDomain:APIServiceErrorDomain
                                                code:APIServiceErrorCodeInvalidURL
                                            userInfo:@{NSLocalizedDescriptionKey: @"Invalid URL was provided."}];
        completionBlock(nil, urlError);
        return;
    }
    
    // 2. Create the Request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    // 3. Serialize the payload to JSON data
    NSError *jsonError = nil;
    NSData *httpBody = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&jsonError];
    
    if (jsonError) {
        NSError *serializationError = [NSError errorWithDomain:APIServiceErrorDomain
                                                          code:APIServiceErrorCodeSerialization
                                                      userInfo:@{NSLocalizedDescriptionKey: @"Failed to serialize payload to JSON.",
                                                                 @"UnderlyingError": jsonError}];
        completionBlock(nil, serializationError);
        return;
    }
    
    [request setHTTPBody:httpBody];
    
    // 4. Create and start the Data Task
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        
        // Always dispatch the completion handler back to the main queue
        dispatch_async(dispatch_get_main_queue(), ^{
            [self handleResponseWithData:data
                                response:response
                                   error:error
                       completionHandler:completionBlock];
        });
    }];
    
    [dataTask resume];
}

/**
 * @brief Handles file upload using multipart/form-data.
 * Assumes the form-data key is "audio".
 */
- (void)uploadFileWithEndpoint:(NSString * _Nonnull)endpoint
                      fromFile:(NSString * _Nonnull)filePath
                    completion:(APIServiceCompletionBlock _Nonnull)completionBlock {
    
    NSString *urlString = [BaseURL stringByAppendingString:endpoint];
    NSURL *url = [NSURL URLWithString:urlString];
    
    if (!url) {
        NSError *urlError = [NSError errorWithDomain:APIServiceErrorDomain code:APIServiceErrorCodeInvalidURL userInfo:@{NSLocalizedDescriptionKey: @"Invalid URL for file upload."}];
        completionBlock(nil, urlError);
        return;
    }

    // 1. Check if file exists and read data
    NSData *fileData = [NSData dataWithContentsOfFile:filePath];
    if (!fileData) {
        NSError *fileError = [NSError errorWithDomain:APIServiceErrorDomain code:APIServiceErrorCodeFileNotFound userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"File not found or cannot be read at path: %@", filePath]}];
        completionBlock(nil, fileError);
        return;
    }

    // 2. Setup boundary and request
    NSString *boundary = [NSString stringWithFormat:@"Boundary-%@", [[NSUUID UUID] UUIDString]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    
    // Set Content-Type header with the boundary
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
    [request setValue:contentType forHTTPHeaderField:@"Content-Type"];
    
    // 3. Create multipart body
    NSError *bodyError = nil;
    NSData *httpBody = [self createBodyWithBoundary:boundary
                                         parameters:nil
                                            fileKey:@"audio" // The required form-data key
                                           fileData:fileData
                                       fileName:[filePath lastPathComponent]
                                       mimeType:@"audio/mpeg" // Assuming MP3
                                          error:&bodyError];
    
    if (bodyError) {
        completionBlock(nil, bodyError);
        return;
    }
    
    [request setHTTPBody:httpBody];

    // 4. Start the Data Task
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self handleResponseWithData:data response:response error:error completionHandler:completionBlock];
        });
    }];
    
    [dataTask resume];
}

#pragma mark - Private Helper: Multipart Body Creator

/**
 * @brief Constructs the multipart/form-data body for file uploads.
 */
- (NSData *)createBodyWithBoundary:(NSString *)boundary
                        parameters:(NSDictionary *)parameters
                           fileKey:(NSString *)fileKey
                          fileData:(NSData *)fileData
                          fileName:(NSString *)fileName
                          mimeType:(NSString *)mimeType
                             error:(NSError **)error {
    
    NSMutableData *body = [NSMutableData data];
    NSString *lineEnd = @"\r\n";

    // Add file data part
    [body appendData:[[NSString stringWithFormat:@"--%@%@", boundary, lineEnd] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"%@", fileKey, fileName, lineEnd] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Type: %@%@", mimeType, lineEnd] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Transfer-Encoding: binary%@", lineEnd] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[lineEnd dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:fileData];
    [body appendData:[lineEnd dataUsingEncoding:NSUTF8StringEncoding]];

    // Close the body with the final boundary
    [body appendData:[[NSString stringWithFormat:@"--%@--%@", boundary, lineEnd] dataUsingEncoding:NSUTF8StringEncoding]];

    if (body.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:APIServiceErrorDomain code:APIServiceErrorCodeBoundaryError userInfo:@{NSLocalizedDescriptionKey: @"Failed to construct multipart/form-data body."}];
        }
        return nil;
    }

    return body;
}

#pragma mark - Private Response Handler

/**
 * @brief Common handler for processing the network response, including error checking and JSON parsing.
 */
- (void)handleResponseWithData:(NSData * _Nullable)data
                      response:(NSURLResponse * _Nullable)response
                         error:(NSError * _Nullable)error
             completionHandler:(APIServiceCompletionBlock _Nonnull)completionBlock {
    
    // 1. Check for connection/system error (e.g., timeout, no internet)
    if (error) {
        completionBlock(nil, error);
        return;
    }
    
    // 2. Check for HTTP Status Code
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    NSInteger statusCode = httpResponse.statusCode;
    
    if (statusCode < 200 || statusCode > 299) {
        // Handle HTTP error status (4xx, 5xx)
        NSString *localizedMessage = [NSString stringWithFormat:@"Server returned HTTP status code: %ld", (long)statusCode];
        
        NSError *httpError = [NSError errorWithDomain:APIServiceErrorDomain
                                                 code:APIServiceErrorCodeHTTPError
                                             userInfo:@{NSLocalizedDescriptionKey: localizedMessage}];
        completionBlock(nil, httpError);
        return;
    }
    
    // 3. Check for data and perform JSON deserialization
    if (!data) {
        // No data received but no explicit error (can happen with some 204 No Content responses)
        completionBlock(nil, nil); 
        return;
    }
    
    NSError *jsonError = nil;
    id responseObject = [NSJSONSerialization JSONObjectWithData:data
                                                        options:0
                                                          error:&jsonError];
    
    if (jsonError) {
        // Handle JSON parsing error
        NSError *serializationError = [NSError errorWithDomain:APIServiceErrorDomain
                                                          code:APIServiceErrorCodeSerialization
                                                      userInfo:@{NSLocalizedDescriptionKey: @"Failed to parse JSON response.",
                                                                 @"UnderlyingError": jsonError}];
        completionBlock(nil, serializationError);
        return;
    }
    
    // 4. Success! Pass the deserialized object back.
    completionBlock(responseObject, nil);
}

@end
