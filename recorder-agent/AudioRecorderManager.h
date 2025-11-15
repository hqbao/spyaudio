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

// Changed 'weak' to 'assign' for compatibility with Manual Reference Counting (MRC)
@property (nonatomic, assign) id<AudioRecorderDelegate> delegate; 
@property (nonatomic, assign, readonly) BOOL isRecording;
@property (nonatomic, assign, readonly) BOOL canPlay; // Indicates if a recording file exists

// Initialization
- (instancetype)init;

// Recording methods
- (void)requestPermission; // This method is now a placeholder for macOS
- (void)startRecording;
- (void)stopRecording;

// Playback method
- (void)startPlayback;
- (void)stopPlayback;

@end

NS_ASSUME_NONNULL_END