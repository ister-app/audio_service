#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Downloads and caches browse-list artwork. Browse media items carry a raw
/// artUri URL (unlike the now-playing item, whose art the Dart side
/// pre-downloads to a local file), so CarPlay lists fetch their own images.
API_AVAILABLE(ios(14.0))
@interface AudioServiceCarPlayArtworkLoader : NSObject

/// Fetches the image at urlString, downscaled to fit maxSize, and calls
/// completion on the main queue. Concurrent requests for the same URL share
/// one download. Completion receives nil on failure.
- (void)loadArtworkFromUrl:(NSString *)urlString
                   maxSize:(CGSize)maxSize
                completion:(void (^)(UIImage *_Nullable image))completion;

/// Cancels all in-flight downloads (their completions fire with nil).
- (void)cancelAll;

@end

NS_ASSUME_NONNULL_END

#endif
