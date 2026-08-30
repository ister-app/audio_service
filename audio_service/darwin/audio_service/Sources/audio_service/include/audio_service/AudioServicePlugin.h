#import <AVFoundation/AVFoundation.h>
#if TARGET_OS_OSX
#import <FlutterMacOS/FlutterMacOS.h>
#else
#import <Flutter/Flutter.h>
#endif

/// Posted when Dart calls notifyChildrenChanged; userInfo carries
/// @"parentMediaId". Observed by the CarPlay browse controller.
extern NSNotificationName const AudioServiceNotifyChildrenChangedNotification;

@interface AudioServicePlugin : NSObject<FlutterPlugin>

@property (readonly, nonatomic) FlutterMethodChannel *channel;

/// Invokes a method on the Dart-side audio handler. Calls made before the
/// handler is configured (AudioService.init) are queued and flushed once
/// configure arrives, so a CarPlay scene may browse before the app UI runs.
+ (void)invokeHandlerMethod:(NSString *)method
                  arguments:(id _Nullable)arguments
                     result:(FlutterResult _Nullable)result;

@end

enum AudioProcessingState {
    ApsIdle,
    ApsLoading,
    ApsBuffering,
    ApsReady,
    ApsCompleted,
    ApsError
};

enum MediaAction {
    AStop,
    APause,
    APlay,
    ARewind,
    ASkipToPrevious,
    ASkipToNext,
    AFastForward,
    ASetRating,
    ASeekTo,
    APlayPause,
    APlayFromMediaId,
    APlayFromSearch,
    ASkipToQueueItem,
    APlayFromUri,
    APrepare,
    APrepareFromMediaId,
    APrepareFromSearch,
    APrepareFromUri,
    ASetRepeatMode,
    ASetShuffleModeEnabled, // deprecated
    ASetCaptioningEnabled,
    ASetShuffleMode,
    // iOS/macOS-specific
    ASeekBackward,
    ASeekForward,
    ASetSpeed,
};
