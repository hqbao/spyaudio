#import <Foundation/Foundation.h>

// Define the completion block signature.
// Data and Error are marked _Nullable because one or both may be nil.
typedef void (^APIServiceCompletionBlock)(id _Nullable data, NSError * _Nullable error);

/**
 * @brief A singleton class for handling RESTful API network requests using NSURLSession.
 */
@interface APIService : NSObject

/**
 * @brief Returns the shared singleton instance of the APIService.
 * The instance is guaranteed to be non-null.
 */
+ (instancetype _Nonnull)sharedInstance;

/**
 * @brief Performs a GET request to a specified API endpoint and calls the completion block.
 *
 * @param endpoint The path appended to the base URL (e.g., "/todos/1"). Must be non-null.
 * @param completionBlock The block to execute upon completion or failure. Must be non-null.
 */
- (void)fetchDataWithEndpoint:(NSString * _Nonnull)endpoint
            completion:(APIServiceCompletionBlock _Nonnull)completionBlock;

/**
 * @brief Performs a POST request with JSON payload to a specified API endpoint.
 *
 * @param endpoint The path appended to the base URL (e.g., "/todos"). Must be non-null.
 * @param payload An NSDictionary containing the data to send. Must be non-null.
 * @param completionBlock The block to execute upon completion or failure. Must be non-null.
 */
- (void)postDataToEndpoint:(NSString * _Nonnull)endpoint
                 payload:(NSDictionary * _Nonnull)payload
              completion:(APIServiceCompletionBlock _Nonnull)completionBlock;

/**
 * @brief Performs a POST request to upload a file using multipart/form-data.
 *
 * @param endpoint The path appended to the base URL (e.g., "/upload").
 * @param filePath The local path to the file to be uploaded.
 * @param completionBlock The block to execute upon completion or failure.
 */
- (void)uploadFileWithEndpoint:(NSString * _Nonnull)endpoint
                      fromFile:(NSString * _Nonnull)filePath
                    completion:(APIServiceCompletionBlock _Nonnull)completionBlock;

@end
