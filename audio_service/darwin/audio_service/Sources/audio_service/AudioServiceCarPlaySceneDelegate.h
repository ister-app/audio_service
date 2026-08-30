#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import <CarPlay/CarPlay.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Scene delegate for the CarPlay template application scene. The app opts in
/// by adding a CPTemplateApplicationSceneSessionRoleApplication entry to its
/// Info.plist scene manifest with UISceneDelegateClassName set to
/// "AudioServiceCarPlaySceneDelegate" (plain Objective-C runtime name, no
/// module prefix), plus the com.apple.developer.carplay-audio entitlement.
/// Without that entry this class is inert.
API_AVAILABLE(ios(14.0))
@interface AudioServiceCarPlaySceneDelegate : UIResponder <CPTemplateApplicationSceneDelegate>
@end

NS_ASSUME_NONNULL_END

#endif
