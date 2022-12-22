//
// XmAutoLaunch
// 随app启动自动运行一些代码。减少必须别人调用的麻烦。
//

#import <UIKit/UIKit.h>

@interface NSObject (XMAutoLaunch)

@end

@interface XMAutoLaunch : NSObject

+ (void)xm_applicationDidFinishLaunchingNotification:(NSNotification *)notification;

@end

@implementation NSObject (XMAutoLaunch)

#pragma mark - load
+ (void)load
{
    [[NSNotificationCenter defaultCenter] addObserver:[XMAutoLaunch class] selector:@selector(xm_applicationDidFinishLaunchingNotification:) name:UIApplicationDidFinishLaunchingNotification object:nil];
}

@end

@implementation XMAutoLaunch

// 此方法会在调用 - application:(UIApplication *) didFinishLaunchingWithOptions:(NSDictionary *) 之后调用
+ (void)xm_applicationDidFinishLaunchingNotification:(NSNotification *)notification
{
    // 防止NSNotificationCenter删除其他开发者添加的监听，这里自己新建了一个类。
    [[NSNotificationCenter defaultCenter] removeObserver:[XMAutoLaunch class]];
    
    // 处理自己的一些逻辑
}

@end
