#import <Foundation/Foundation.h>
#import "AudioRecorderManager.h" 

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The main daemon class responsible for persistent command polling, 
 * command execution, and coordinating the audio manager and API service.
 */
@interface RecorderAgent : NSObject <AudioRecorderDelegate>

/**
 * @brief Initializes the daemon and starts the command polling loop.
 */
- (instancetype)init;

/**
 * @brief Stops the recurring command polling timer.
 */
- (void)stopCommandLoop;

@end

NS_ASSUME_NONNULL_END