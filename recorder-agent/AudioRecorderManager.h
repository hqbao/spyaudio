#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol AudioRecorderDelegate <NSObject>

- (void)audioRecorderDidFinishRecordingSuccessfully:(BOOL)flag;

@end

/**
 * @brief Manages all AVFoundation recording and playback functionality.
 */
@interface AudioRecorderManager : NSObject <AVAudioRecorderDelegate, AVAudioPlayerDelegate>

@property (nonatomic, assign) id<AudioRecorderDelegate> delegate; 
@property (nonatomic, assign, readonly) BOOL isRecording;
@property (nonatomic, assign, readonly) BOOL isPlaying; 
@property (nonatomic, assign, readonly) BOOL canPlay; // True if an audio file exists

// Expose the file URL for the APIService upload
@property (nonatomic, strong, readonly) NSURL *audioFileURL;

// Initialization
- (instancetype)init;

// Recording methods
- (void)requestPermission;
- (void)startRecording;
- (void)stopRecording;

// Playback methods
- (void)startPlayback;
- (void)stopPlayback;

@end

NS_ASSUME_NONNULL_END