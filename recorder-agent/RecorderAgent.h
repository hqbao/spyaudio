#import <Foundation/Foundation.h>
#import "AudioRecorderManager.h" // We need the delegate protocol

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief The main daemon class responsible for persistent command polling, 
 * command execution, and coordinating the audio manager and API service.
 * * This class conforms to the AudioRecorderDelegate to handle post-recording actions (upload).
 */
@interface RecorderAgent : NSObject <AudioRecorderDelegate>

/**
 * @brief Initializes the daemon and starts the command polling loop.
 * @return An initialized instance of RecorderAgent.
 */
- (instancetype)init;

/**
 * @brief Stops the recurring command polling timer.
 */
- (void)stopCommandLoop;

@end

NS_ASSUME_NONNULL_END