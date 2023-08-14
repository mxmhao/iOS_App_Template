//
//  LocalAuthentication.m
//  
//
//  Created by mxm on 2019/2/10.
//  Copyright © 2019 mxm. All rights reserved.
//

#import <Foundation/Foundation.h>

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

@end
