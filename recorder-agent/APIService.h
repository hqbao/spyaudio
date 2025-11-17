#import <Foundation/Foundation.h>

// Define the completion block signature.
typedef void (^APIServiceCompletionBlock)(id _Nullable data, NSError * _Nullable error);

/**
 * @brief A singleton class for handling RESTful API network requests using NSURLSession.
 */
@interface APIService : NSObject <NSURLSessionDelegate>

// Public read-only access to baseURL 
@property (nonatomic, strong, readonly) NSString * _Nullable baseURL;

// The NSURLSession instance. Marked _Nonnull as it is initialized in -init.
@property (nonatomic, strong, readonly) NSURLSession * _Nonnull session;

/**
 * @brief Returns the shared singleton instance of the APIService.
 */
+ (instancetype _Nonnull)sharedInstance;

/**
 * @brief Performs a GET request.
 */
- (void)fetchDataWithEndpoint:(NSString * _Nonnull)endpoint
                   completion:(APIServiceCompletionBlock _Nonnull)completionBlock;

/**
 * @brief Performs a POST request with JSON payload.
 */
- (void)postDataToEndpoint:(NSString * _Nonnull)endpoint
                   payload:(NSDictionary * _Nonnull)payload
                completion:(APIServiceCompletionBlock _Nonnull)completionBlock;

/**
 * @brief Performs a POST request to upload a file using multipart/form-data.
 */
- (void)uploadFileWithEndpoint:(NSString * _Nonnull)endpoint
                      fromFile:(NSString * _Nonnull)filePath
                    parameters:(NSDictionary * _Nullable)parameters
                    completion:(APIServiceCompletionBlock _Nonnull)completionBlock;

@end