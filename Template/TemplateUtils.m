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

@end