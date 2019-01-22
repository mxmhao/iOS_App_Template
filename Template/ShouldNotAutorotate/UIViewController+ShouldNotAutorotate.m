//
//  UIViewController+ShouldNotAutorotate.m

#import "UIViewController+ShouldNotAutorotate.h"
#import <objc/runtime.h>

@implementation UIViewController (ShouldNotAutorotate)

+ (void)load
{
    Method sa = class_getInstanceMethod(self, @selector(shouldAutorotate));
    Method xm_sa = class_getInstanceMethod(self, @selector(xm_shouldAutorotate));
    method_exchangeImplementations(sa, xm_sa);

    Method sio = class_getInstanceMethod(self, @selector(supportedInterfaceOrientations));
    Method xm_sio = class_getInstanceMethod(self, @selector(xm_supportedInterfaceOrientations));
    method_exchangeImplementations(sio, xm_sio);
}

- (BOOL)xm_shouldAutorotate
{
    if ([self conformsToProtocol:@protocol(ShouldNotAutorotate)]) return NO;
    return [self xm_shouldAutorotate];//返回原来的结果
}

- (UIInterfaceOrientationMask)xm_supportedInterfaceOrientations
{
    if ([self conformsToProtocol:@protocol(ShouldNotAutorotate)]) return UIInterfaceOrientationMaskPortrait;
    return [self xm_supportedInterfaceOrientations];//返回原来的结果
}

@end
