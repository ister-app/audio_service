#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "AudioServiceCarPlayArtworkLoader.h"

@implementation AudioServiceCarPlayArtworkLoader {
    NSCache<NSString *, UIImage *> *_cache;
    NSURLSession *_session;
    // urlString -> array of completion blocks waiting on one download.
    NSMutableDictionary<NSString *, NSMutableArray *> *_pending;
    NSMutableDictionary<NSString *, NSURLSessionDataTask *> *_tasks;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _cache = [NSCache new];
        _cache.countLimit = 200;
        _session = [NSURLSession sessionWithConfiguration:
            [NSURLSessionConfiguration defaultSessionConfiguration]];
        _pending = [NSMutableDictionary new];
        _tasks = [NSMutableDictionary new];
    }
    return self;
}

- (void)loadArtworkFromUrl:(NSString *)urlString
                   maxSize:(CGSize)maxSize
                completion:(void (^)(UIImage *_Nullable))completion {
    UIImage *cached = [_cache objectForKey:urlString];
    if (cached) {
        dispatch_async(dispatch_get_main_queue(), ^{ completion(cached); });
        return;
    }
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        dispatch_async(dispatch_get_main_queue(), ^{ completion(nil); });
        return;
    }
    @synchronized(self) {
        NSMutableArray *waiters = _pending[urlString];
        if (waiters) {
            [waiters addObject:[completion copy]];
            return;
        }
        _pending[urlString] = [NSMutableArray arrayWithObject:[completion copy]];
    }
    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [_session dataTaskWithURL:url
            completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        typeof(self) self = weakSelf;
        if (!self) return;
        UIImage *image = nil;
        if (data && !error) {
            image = [self downscaleImage:[UIImage imageWithData:data] toFit:maxSize];
        }
        [self finishUrl:urlString withImage:image];
    }];
    @synchronized(self) {
        _tasks[urlString] = task;
    }
    [task resume];
}

- (void)finishUrl:(NSString *)urlString withImage:(UIImage *)image {
    NSArray *waiters;
    @synchronized(self) {
        waiters = _pending[urlString];
        [_pending removeObjectForKey:urlString];
        [_tasks removeObjectForKey:urlString];
    }
    if (image) {
        [_cache setObject:image forKey:urlString];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        for (void (^waiter)(UIImage *) in waiters) {
            waiter(image);
        }
    });
}

- (UIImage *)downscaleImage:(UIImage *)image toFit:(CGSize)maxSize {
    if (!image) return nil;
    if (image.size.width <= maxSize.width && image.size.height <= maxSize.height) {
        return image;
    }
    CGFloat ratio = MIN(maxSize.width / image.size.width,
                        maxSize.height / image.size.height);
    CGSize target = CGSizeMake(image.size.width * ratio, image.size.height * ratio);
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    // CarPlay displays are 2x/3x; render at 2x so downscaled art stays sharp.
    format.scale = MAX(2.0, format.scale);
    UIGraphicsImageRenderer *renderer =
        [[UIGraphicsImageRenderer alloc] initWithSize:target format:format];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [image drawInRect:CGRectMake(0, 0, target.width, target.height)];
    }];
}

- (void)cancelAll {
    NSArray<NSURLSessionDataTask *> *tasks;
    @synchronized(self) {
        tasks = _tasks.allValues;
    }
    for (NSURLSessionDataTask *task in tasks) {
        [task cancel];
    }
}

@end

#endif
