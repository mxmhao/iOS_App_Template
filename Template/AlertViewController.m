//
//  AlertViewController.m
//  iOS_App_Template
//
//  Created by macmini on 2023/12/7.
//  Copyright © 2023 mxm. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface AlertViewController : UIViewController

@end

NS_ASSUME_NONNULL_END

@interface AlertViewController ()

@end

@implementation AlertViewController
{
    // 自定义的弹框，弹框上面可能有 UITextField
    UIView *_alertView;
}

// 下层的 ViewController 可以直接调用 [self presentViewController: animated:YES completion:] 来呈现此 ViewController，就和呈现 UIAlertController 一样
- (instancetype)init
{
    self = [super init];
    if (self) {
        // 这两点设置非常重要，storyboard 上也可以设置
        // 这个最好设置成带 Over 的选项，加上半透明背景可保证能看到下层的 ViewController。PageSheet 和 FormSheet 也许也有这种效果，请自行百度他们的效果。
        self.modalPresentationStyle = UIModalPresentationOverFullScreen;
        // 这个是使用渐变转场动画，请自行百度他们的效果
        self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // 请自定义你的弹框
    _alertView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 270, 200)];
    [self.view addSubview:_alertView];
    // 背景使用有透明度的黑色，保证可以看到下层的 ViewController
    self.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.2];
    // 增加监听，当键盘出现或改变时收出消息
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    // 增加监听，当键退出时收出消息
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    // 这里给弹框添加动画，可以仿 UIAlertController 动画
    /*
    // 比例缩放
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    // 1秒后执行
//    animation.beginTime = CACurrentMediaTime() + 0.1;
    // 持续时间
//    animation.duration = 0.4;
    // 重复次数
//    animation.repeatCount = 1;
    // 起始scale
    animation.fromValue = @(1.18);
    // 终止scale
    animation.toValue = @(1);
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
//    animation.fillMode = kCAFillModeRemoved;
    
    // 透明度缩放
    CABasicAnimation *animationOpacity = [CABasicAnimation animationWithKeyPath:@"opacity"];
    // 1秒后执行
//    animationOpacity.beginTime = CACurrentMediaTime() + 0.1;
    // 持续时间
//    animationOpacity.duration = 0.4;
    // 重复次数
//    animationOpacity.repeatCount = 1;
    // 起始scale
    animationOpacity.fromValue = @(0.0);
    // 终止scale
    animationOpacity.toValue = @(1);
    animationOpacity.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
//    animationOpacity.fillMode = kCAFillModeRemoved;
    
    // 动画组
    CAAnimationGroup *group = [CAAnimationGroup animation];
    group.animations = @[animation, animationOpacity];
    // 持续时间
    group.duration = 0.4;
    // 动画结束是否恢复原状
    group.removedOnCompletion = YES;
    // 动画组
    group.fillMode = kCAFillModeRemoved;
    // 添加动画
    [_alertView.layer addAnimation:group forKey:@"group"];//*/
}

- (void)dealloc
{
    [NSNotificationCenter.defaultCenter removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [NSNotificationCenter.defaultCenter removeObserver:self name:UIKeyboardWillHideNotification object:nil];
    NSLog(@"%@ dealloc", NSStringFromClass([self class]));
}

// 弹框上有输入框时添加动画
- (void)keyboardWillShow:(NSNotification *)aNotification
{
    // 获取键盘的高度
    NSValue *aValue = aNotification.userInfo[UIKeyboardFrameEndUserInfoKey];
    CGRect keyboardRect = [aValue CGRectValue];
    NSLog(@"%@", NSStringFromCGRect(keyboardRect));
    
//    CGPoint center = self.view.center;
//    center.y -= CGRectGetHeight(keyboardRect)/2;
    [UIView animateWithDuration:.3 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        // 这种平移会有bug：当点击弹框上的按钮时动画会自动还原；而且只能在 viewDidAppear 中调用 becomeFirstResponder，否则会有bug
//        self->_alertView.center = center;
        // 这种不限制在哪调用 becomeFirstResponder
        self->_alertView.transform = CGAffineTransformMakeTranslation(0, -CGRectGetHeight(keyboardRect)/2);
    } completion:nil];
}

// 键盘消失
- (void)keyboardWillHide:(NSNotification *)aNotification
{
//    CGPoint center = self.view.center;
    [UIView animateWithDuration:.3 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
//        self->_alertView.center = center;
        self->_alertView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

@end
