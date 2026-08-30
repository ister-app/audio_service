#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "AudioServiceCarPlaySceneDelegate.h"
#import "AudioServiceCarPlayBrowseController.h"

API_AVAILABLE(ios(14.0))
@implementation AudioServiceCarPlaySceneDelegate {
    AudioServiceCarPlayBrowseController *_browseController;
}

- (void)templateApplicationScene:(CPTemplateApplicationScene *)templateApplicationScene
    didConnectInterfaceController:(CPInterfaceController *)interfaceController {
    _browseController = [[AudioServiceCarPlayBrowseController alloc]
        initWithInterfaceController:interfaceController];
    [_browseController start];
}

- (void)templateApplicationScene:(CPTemplateApplicationScene *)templateApplicationScene
    didDisconnectInterfaceController:(CPInterfaceController *)interfaceController {
    [_browseController stop];
    _browseController = nil;
}

@end

#endif
