//
//  UIViewController+ShouldNotAutorotate.h

#import <UIKit/UIKit.h>

/** 使用此协议后，不要在子类中重写shouldAutorotate和supportedInterfaceOrientations方法，否则旋转的控制就会失效 */
@protocol ShouldNotAutorotate @end

@interface UIViewController (ShouldNotAutorotate)

@end
