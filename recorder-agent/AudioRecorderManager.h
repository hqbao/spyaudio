//
//  AudioRecorderManager.h
//  audio-recoder
//
//  Created by Hoa Quoc Bao (Baul) on 14/11/25.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

// Delegate protocol for communication back to the View Controller
@protocol AudioRecorderDelegate <NSObject>

- (void)audioRecorderDidFinishRecordingSuccessfully:(BOOL)flag;

@end


@interface AudioRecorderManager : NSObject <AVAudioRecorderDelegate, AVAudioPlayerDelegate>

@property (nonatomic, assign) id<AudioRecorderDelegate> delegate; // FIX: Changed 'weak' to 'assign' for MRC
@property (nonatomic, assign, readonly) BOOL isRecording;
@property (nonatomic, assign, readonly) BOOL isPlaying; // <--- NEW: Indicates if audio is currently playing
@property (nonatomic, assign, readonly) BOOL canPlay; // Indicates if a recording file exists

// Expose the actual file URL for use in APIService
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