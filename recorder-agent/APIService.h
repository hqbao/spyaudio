#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Define the completion block type for all API calls
typedef void (^APIServiceCompletionBlock)(id _Nullable responseObject, NSError * _Nullable error);

/**
 * @brief Singleton class for handling all network communication.
 * Implements NSURLSessionDelegate for ATS/SSL pinning bypass.
 */
@interface APIService : NSObject <NSURLSessionDelegate>

@property (nonatomic, strong, readonly) NSString *baseURL;

/**
 * @brief Returns the shared singleton instance of APIService.
 */
+ (instancetype)sharedInstance;

/**
 * @brief Performs a GET request. Used for the /get-command endpoint.
 */
- (void)fetchDataWithEndpoint:(NSString *)endpoint
                   completion:(APIServiceCompletionBlock)completionBlock;

/**
 * @brief Performs a POST request with JSON payload. Used for /set-command or simple feedback.
 */
- (void)postDataToEndpoint:(NSString *)endpoint
                   payload:(NSDictionary *)payload
                completion:(APIServiceCompletionBlock)completionBlock;

/**
 * @brief Performs a POST request with multipart/form-data for file uploads.
 * Used for the /upload endpoint.
 */
- (void)uploadFileWithEndpoint:(NSString *)endpoint
                      fromFile:(NSString *)filePath
                    parameters:(NSDictionary * _Nullable)parameters
                    completion:(APIServiceCompletionBlock)completionBlock;

@end

NS_ASSUME_NONNULL_END