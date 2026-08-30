#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <CarPlay/CarPlay.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Drives the CarPlay browse UI from the Dart audio handler's media browse
/// tree: the same getChildren/playFromMediaId contract Android Auto uses.
/// The root list shows the children of AudioService.recentRootId ('recent')
/// and AudioService.browsableRootId ('root'); browsable items push nested
/// lists, playable items start playback and show the shared Now Playing
/// template (whose content comes from MPNowPlayingInfoCenter for free).
API_AVAILABLE(ios(14.0))
@interface AudioServiceCarPlayBrowseController : NSObject

- (instancetype)initWithInterfaceController:(CPInterfaceController *)interfaceController;

/// Installs the root template and starts loading the browse tree.
- (void)start;

/// Detaches from the interface controller and cancels outstanding work.
- (void)stop;

@end

NS_ASSUME_NONNULL_END

#endif
