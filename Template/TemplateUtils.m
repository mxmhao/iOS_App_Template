//
//  LocalAuthentication.m
//  
//
//  Created by mxm on 2019/2/10.
//  Copyright © 2019 mxm. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface TemplateUtils : NSObject
@end

@implementation TemplateUtils

static const int kTimeoutInterval = 3;
NS_INLINE
dispatch_source_t fetchGCDTimer(void) {
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    /*!
     * @param start
     * 首次触发时间，单位纳秒。 See dispatch_time() and dispatch_walltime()
     * for more information. 我这里用 dispatch_time 计算3秒后的时间
     *
     * @param interval
     * 时间间隔，单位纳秒。 使用 DISPATCH_TIME_FOREVER 表示一次性的timer
     *
     * @param leeway
     * 可偏差时间
     */
    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, kTimeoutInterval * NSEC_PER_SEC), DISPATCH_TIME_FOREVER, 0.1 * NSEC_PER_SEC);
    return timer;
}

// 使用 GCD timer 的好处是不用考虑 runloop
- (void)gcdTimer
{
    dispatch_source_t timer = fetchGCDTimer();
    dispatch_source_set_event_handler(timer, ^() {
        // 如果是重复触发 timer 可在这里 停止 timer
//        dispatch_source_cancel(timer);
        // TODO sometings
    });
    
    // 启动 timer
    dispatch_resume(timer);
    // 停止timer
    dispatch_source_cancel(timer);
}

/// 复制到剪切板
+ (void)copyToClipboard:(NSString *)text
{
    if (!text || text.length == 0) {
        return;
    }
    UIPasteboard.generalPasteboard.string = text;
}

/// 使用iOS原生类请求 HTTP JSON
+ (void)postHttp:(NSURL *)url header:(NSDictionary *)headers body:(NSDictionary *)json completion:(void (^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completion
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
    request.HTTPMethod = @"POST";
    for (NSString *key in headers) {
        [request setValue:headers[key] forHTTPHeaderField:key];
    }
    [request setValue:@"application/json;charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:json options:kNilOptions error:NULL];
    NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:completion];
    [task resume];
}

/// 从AppStore获取版app最新本号
+ (void)fetchNewVersion
{
    /*
     http 和 https 貌似都可
     全球：
     https://itunes.apple.com/lookup?id=
     http://itunes.apple.com/lookup?bundleId=
     中国：
     https://itunes.apple.com/cn/lookup?id=
     http://itunes.apple.com/cn/lookup?bundleId=
     */
    [[NSURLSession.sharedSession dataTaskWithURL:[NSURL URLWithString:[@"http://itunes.apple.com/lookup?bundleId=" stringByAppendingString:NSBundle.mainBundle.bundleIdentifier]] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) return;
        
        NSError *err;
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&err];
        if (err) return;
        //dic[@"resultCount"].intValue > 0
//        NSLog(@"--: %@", dict);
        NSArray *arr = dict[@"results"];
        if (arr.count <= 0) return;
        
//        NSLog(@"--: %@", dic[@"resultCount"]);
        NSDictionary *info = arr[0];
        NSNumber *trackId = info[@"trackId"];
        NSString *version = info[@"version"];
        // 此链接可以跳到AppStore的app下载页
        NSString *trackViewUrl = info[@"trackViewUrl"];
        NSLog(@"--: %@", trackId);
        NSLog(@"--: %@", version);
    }] resume];
}

#pragma mark - 使用 NSURLSession.sharedSession 下载文件并获取进度，这样就可以不用自己创建NSURLSession 来设置NSURLSessionDownloadDelegate去获取进度
static NSURLSessionDownloadTask *_task;
static dispatch_source_t _timer;
- (void)downloadFile
{
    __weak __typeof(self) weakSelf = self;
    // 定时器，定时获取下载进度
    _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(_timer, dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), 0.5 * NSEC_PER_SEC, 0.1 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(_timer, ^() {
        __strong __typeof(weakSelf) self = weakSelf;
        if (nil == _task || _task.countOfBytesExpectedToReceive == 0) return;
        
        // 进度
        [NSString stringWithFormat:@"%lld%%", _task.countOfBytesReceived * 100 / _task.countOfBytesExpectedToReceive];
    });
    
    _task = [NSURLSession.sharedSession downloadTaskWithURL:[NSURL URLWithString:@"file url"] completionHandler:^(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        // 停止定时器
        dispatch_source_cancel(_timer);
        __strong __typeof(weakSelf) self = weakSelf;
        // 下载完成或出错
    }];
    [_task resume];
    // 启动定时器
    dispatch_resume(_timer);
}

@end

#pragma mark - UITextField 添加 leftView
@interface UITextField (LeftText)

- (void)setLeftText:(NSString *)text;

@end

@implementation UITextField (LeftText)

- (void)setLeftText:(NSString *)text
{
    // 使用 UIButton 可以设置留空白, UILabel不能留空白，因为 UITextField 会重新计算并设置 leftView 的 frame
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.userInteractionEnabled = NO;
    [btn setTitle:[text stringByAppendingString:@": "] forState:UIControlStateNormal];
    [btn setTitleColor:UIColor.blackColor forState:UIControlStateNormal];
    // 留空白
    btn.contentEdgeInsets = UIEdgeInsetsMake(0, 10, 0, 0);

    self.leftView = btn;
    // 这个必须设置，否则不会显示
    self.leftViewMode = UITextFieldViewModeAlways;
}

@end

#pragma mark - UIButton
@interface UIButton (ImageAndTitleSpace) @end
@implementation UIButton (ImageAndTitleSpace)
// 设置 UIButton 图片和文字之间的间隔
- (void)setImageAndTitleSpace:(CGFloat)space
{
    // 必须是 imageEdgeInsets 设置间隔，titleEdgeInsets 会导致 UIButtonTypeCustom 类型的文字出现省略。 left 必须是负数。image可能会超出 self.bounds 的左边界，注意设置了切割超出边界属性
    self.imageEdgeInsets = UIEdgeInsetsMake(0, -space, 0, 0);// storyboard 和 xib 的属性面板上可以设置
    
    // iOS 15 以上的也可以这么设置
    if (@available(iOS 15.0, *)) {
        UIButtonConfiguration *conf = UIButtonConfiguration.plainButtonConfiguration;
        // 这些都可以在 storyboard 和 xib 的属性面板上找到。
        conf.imagePadding = space;
        // 这玩意可以改变图片的位置，终于可以不用自定义了
        conf.imagePlacement = NSDirectionalRectEdgeTrailing;
        // 通过 UIButtonConfiguration 创建 UIButton
        [UIButton buttonWithConfiguration:conf primaryAction:nil];
    }
    
}
@end

