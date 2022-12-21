//
// XmAutoLaunch
// 随app启动自动运行一些代码。减少必须别人调用的麻烦。
//

#import <UIKit/UIKit.h>

@interface NSObject (XMAutoLaunch)

@end

@implementation NSObject (XMAutoLaunch)

#pragma mark - load
+ (void)load
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(xm_applicationDidFinishLaunchingNotification:) name:UIApplicationDidFinishLaunchingNotification object:nil];
}

static BOOL xm_applicationDidFinishLaunching = NO;
#pragma mark - notification
+ (void)xm_applicationDidFinishLaunchingNotification:(NSNotification *)notification
{
    if (xm_applicationDidFinishLaunching) return;
    xm_applicationDidFinishLaunching = YES;
    
    // 处理自己的一些逻辑
}

@end
