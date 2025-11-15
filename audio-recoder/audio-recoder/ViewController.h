#import <UIKit/UIKit.h>
#import "AudioRecorderManager.h" // Import the core logic

NS_ASSUME_NONNULL_BEGIN

@interface ViewController : UIViewController <AudioRecorderDelegate>

@property (nonatomic, strong) AudioRecorderManager *recorderManager;
@property (nonatomic, strong) UIButton *recordButton;
@property (nonatomic, strong) UIButton *playButton;
@property (nonatomic, strong) UILabel *statusLabel;

@end

NS_ASSUME_NONNULL_END
