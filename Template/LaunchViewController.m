//
//  ViewController.m
//  iOS_App_Template
//
//  Created by mxm on 2018/1/22.
//  Copyright © 2019 mxm. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface LaunchViewController : UIViewController
{
    UIImageView *LaunchScreen;
}

@end

@implementation LaunchViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self addLaunchScreen];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self removeLaunchScreen];
    });
}

/**
 动态替换启动页
 https://blog.csdn.net/olsQ93038o99S/article/details/108924170
 https://github.com/iversonxh/DynamicLaunchImage
 添加一个和app启动页一模一样的页面，让用户误以为延长了启动页，此页面可做广告页
 */
- (void)addLaunchScreen
{
    UIViewController *vc = [[UIStoryboard storyboardWithName:@"LaunchScreen" bundle:nil] instantiateInitialViewController];
    vc.view.frame = UIScreen.mainScreen.bounds;
//    [vc.view setNeedsLayout];
//    [vc.view layoutIfNeeded];
//    [vc viewWillLayoutSubviews];
//    [vc viewDidLayoutSubviews];
//    [vc viewWillAppear:YES];
//    [vc viewDidAppear:YES];
//    [self.view addSubview:vc.view];
    UIGraphicsBeginImageContextWithOptions(UIScreen.mainScreen.bounds.size, NO, UIScreen.mainScreen.scale);
    [vc.view.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();//最好缓存到文档目录下，免除每次制作
    UIGraphicsEndImageContext();
    LaunchScreen = [[UIImageView alloc] initWithImage:image];
    LaunchScreen.frame = UIScreen.mainScreen.bounds;
    [self.view addSubview:LaunchScreen];
}

- (void)removeLaunchScreen
{
    [UIView animateWithDuration:0.3 animations:^{
        self->LaunchScreen.alpha = 0;
    } completion:^(BOOL finished) {
        [self->LaunchScreen removeFromSuperview];
    }];
}

@end
