#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "AudioServiceCarPlayBrowseController.h"
#import "AudioServiceCarPlayArtworkLoader.h"
#import "./include/audio_service/AudioServicePlugin.h"

static NSString *const kRecentRootId = @"recent";
static NSString *const kBrowsableRootId = @"root";

API_AVAILABLE(ios(14.0))
@implementation AudioServiceCarPlayBrowseController {
    CPInterfaceController *_interfaceController;
    AudioServiceCarPlayArtworkLoader *_artworkLoader;
    CPListTemplate *_rootTemplate;
    NSArray<CPListItem *> *_recentItems;
    NSArray<CPListItem *> *_browseItems;
    // parentMediaId -> pushed template, so notifyChildrenChanged can refresh
    // a list that is still on the navigation stack.
    NSMapTable<NSString *, CPListTemplate *> *_templatesByParentId;
    BOOL _stopped;
}

- (instancetype)initWithInterfaceController:(CPInterfaceController *)interfaceController {
    self = [super init];
    if (self) {
        _interfaceController = interfaceController;
        _artworkLoader = [AudioServiceCarPlayArtworkLoader new];
        _templatesByParentId = [NSMapTable strongToWeakObjectsMapTable];
        _recentItems = @[];
        _browseItems = @[];
    }
    return self;
}

- (void)start {
    NSString *title =
        [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"]
            ?: [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"]
            ?: @"";
    _rootTemplate = [[CPListTemplate alloc] initWithTitle:title sections:@[]];
    _rootTemplate.emptyViewTitleVariants = @[@"…"];
    [_interfaceController setRootTemplate:_rootTemplate animated:NO completion:nil];
    [self reloadRootPart:kRecentRootId];
    [self reloadRootPart:kBrowsableRootId];
    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(childrenChanged:)
               name:AudioServiceNotifyChildrenChangedNotification
             object:nil];
}

- (void)stop {
    _stopped = YES;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_artworkLoader cancelAll];
    _interfaceController = nil;
    _rootTemplate = nil;
}

#pragma mark - Data loading

- (void)fetchChildren:(NSString *)parentMediaId
           completion:(void (^)(NSArray *children))completion {
    __weak typeof(self) weakSelf = self;
    [AudioServicePlugin invokeHandlerMethod:@"getChildren"
                                  arguments:@{@"parentMediaId": parentMediaId}
                                     result:^(id result) {
        NSArray *children = @[];
        if ([result isKindOfClass:[NSDictionary class]]) {
            id value = ((NSDictionary *)result)[@"children"];
            if ([value isKindOfClass:[NSArray class]]) {
                children = value;
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            typeof(self) self = weakSelf;
            if (!self || self->_stopped) return;
            completion(children);
        });
    }];
}

- (void)reloadRootPart:(NSString *)parentMediaId {
    __weak typeof(self) weakSelf = self;
    [self fetchChildren:parentMediaId completion:^(NSArray *children) {
        typeof(self) self = weakSelf;
        if (!self) return;
        NSArray<CPListItem *> *items = [self listItemsFromChildren:children];
        if ([parentMediaId isEqualToString:kRecentRootId]) {
            self->_recentItems = items;
        } else {
            self->_browseItems = items;
        }
        [self updateRootSections];
    }];
}

- (void)updateRootSections {
    NSMutableArray<CPListSection *> *sections = [NSMutableArray new];
    if (_recentItems.count > 0) {
        [sections addObject:[[CPListSection alloc] initWithItems:_recentItems]];
    }
    if (_browseItems.count > 0) {
        [sections addObject:[[CPListSection alloc] initWithItems:_browseItems]];
    }
    [_rootTemplate updateSections:sections];
}

- (void)childrenChanged:(NSNotification *)notification {
    NSString *parentMediaId = notification.userInfo[@"parentMediaId"];
    if (!parentMediaId) return;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        typeof(self) self = weakSelf;
        if (!self || self->_stopped) return;
        if ([parentMediaId isEqualToString:kRecentRootId] ||
            [parentMediaId isEqualToString:kBrowsableRootId]) {
            [self reloadRootPart:parentMediaId];
            return;
        }
        CPListTemplate *template = [self->_templatesByParentId objectForKey:parentMediaId];
        if (!template) return;
        [self fetchChildren:parentMediaId completion:^(NSArray *children) {
            typeof(self) self = weakSelf;
            if (!self) return;
            NSArray<CPListItem *> *items = [self listItemsFromChildren:children];
            [template updateSections:
                items.count > 0 ? @[[[CPListSection alloc] initWithItems:items]] : @[]];
        }];
    });
}

#pragma mark - Item building

- (NSArray<CPListItem *> *)listItemsFromChildren:(NSArray *)children {
    NSMutableArray<CPListItem *> *items = [NSMutableArray new];
    NSUInteger limit = CPListTemplate.maximumItemCount;
    for (id child in children) {
        if (![child isKindOfClass:[NSDictionary class]]) continue;
        if (items.count >= limit) break;
        [items addObject:[self listItemFromMediaItem:(NSDictionary *)child]];
    }
    return items;
}

static NSString *stringValue(NSDictionary *map, NSString *key) {
    id value = map[key];
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

- (CPListItem *)listItemFromMediaItem:(NSDictionary *)mediaItem {
    NSString *text = stringValue(mediaItem, @"displayTitle")
        ?: stringValue(mediaItem, @"title") ?: @"";
    NSString *detail = stringValue(mediaItem, @"displaySubtitle")
        ?: stringValue(mediaItem, @"artist") ?: stringValue(mediaItem, @"album");
    BOOL playable = [mediaItem[@"playable"] isKindOfClass:[NSNumber class]]
        && [mediaItem[@"playable"] boolValue];
    CPListItem *item = [[CPListItem alloc] initWithText:text detailText:detail];
    item.userInfo = mediaItem;
    item.accessoryType = playable
        ? CPListItemAccessoryTypeNone
        : CPListItemAccessoryTypeDisclosureIndicator;
    NSString *artUri = stringValue(mediaItem, @"artUri");
    if (artUri) {
        __weak CPListItem *weakItem = item;
        [_artworkLoader loadArtworkFromUrl:artUri
                                   maxSize:CPListItem.maximumImageSize
                                completion:^(UIImage *image) {
            if (image) [weakItem setImage:image];
        }];
    }
    __weak typeof(self) weakSelf = self;
    item.handler = ^(id<CPSelectableListItem> selectedItem, dispatch_block_t completionBlock) {
        typeof(self) self = weakSelf;
        if (!self || self->_stopped) {
            completionBlock();
            return;
        }
        if (playable) {
            [self playMediaItem:mediaItem completion:completionBlock];
        } else {
            [self pushChildrenOfMediaItem:mediaItem completion:completionBlock];
        }
    };
    return item;
}

#pragma mark - Selection

- (void)playMediaItem:(NSDictionary *)mediaItem completion:(dispatch_block_t)completionBlock {
    NSString *mediaId = stringValue(mediaItem, @"id");
    if (!mediaId) {
        completionBlock();
        return;
    }
    [AudioServicePlugin invokeHandlerMethod:@"playFromMediaId"
                                  arguments:@{@"mediaId": mediaId}
                                     result:nil];
    CPNowPlayingTemplate *nowPlaying = [CPNowPlayingTemplate sharedTemplate];
    if (_interfaceController.topTemplate != nowPlaying) {
        if ([_interfaceController.templates containsObject:nowPlaying]) {
            [_interfaceController popToTemplate:nowPlaying animated:YES completion:nil];
        } else {
            [_interfaceController pushTemplate:nowPlaying animated:YES completion:nil];
        }
    }
    completionBlock();
}

- (void)pushChildrenOfMediaItem:(NSDictionary *)mediaItem
                     completion:(dispatch_block_t)completionBlock {
    NSString *mediaId = stringValue(mediaItem, @"id");
    // CarPlay allows a hierarchy of at most 5 templates.
    if (!mediaId || _interfaceController.templates.count >= 5) {
        completionBlock();
        return;
    }
    NSString *title = stringValue(mediaItem, @"displayTitle")
        ?: stringValue(mediaItem, @"title") ?: @"";
    __weak typeof(self) weakSelf = self;
    [self fetchChildren:mediaId completion:^(NSArray *children) {
        typeof(self) self = weakSelf;
        if (!self) {
            completionBlock();
            return;
        }
        NSArray<CPListItem *> *items = [self listItemsFromChildren:children];
        CPListTemplate *template = [[CPListTemplate alloc]
            initWithTitle:title
                 sections:items.count > 0
                     ? @[[[CPListSection alloc] initWithItems:items]] : @[]];
        template.emptyViewTitleVariants = @[title];
        [self->_templatesByParentId setObject:template forKey:mediaId];
        [self->_interfaceController pushTemplate:template animated:YES completion:nil];
        completionBlock();
    }];
}

@end

#endif
