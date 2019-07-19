//
//  Share.m
//
//
//  Created by mxm on 2019/1/2.
//  Copyright © 2019 mxm. All rights reserved.
//

//#import <FBSDKShareKit/FBSDKShareKit.h>
//#import <FBSDKCoreKit/FBSDKCoreKit.h>
//#import <TwitterKit/TWTRKit.h>

#import <MessageUI/MessageUI.h>
#import <Social/Social.h>

@interface Share: NSObject ///<FBSDKSharingDelegate>

@end

@implementation Share

//各种appId注册
+ (void)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
//    [[FBSDKApplicationDelegate sharedInstance] application:app didFinishLaunchingWithOptions:launchOptions];
//    [[Twitter sharedInstance] startWithConsumerKey:@"" consumerSecret:@""];
}

//各种分享的回调
+ (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options
{
    /*
    if ([url.scheme hasPrefix:@"fb"]) {
        return [[FBSDKApplicationDelegate sharedInstance] application:app openURL:url sourceApplication:options[UIApplicationOpenURLOptionsSourceApplicationKey] annotation:options[UIApplicationOpenURLOptionsAnnotationKey]];
    } else if ([url.scheme hasPrefix:@"twitterkit"]) {
        return [[Twitter sharedInstance] application:app openURL:url options:options];
    }*/
    
    return NO;
}

#pragma mark - UIActivityViewController
/*
 Social ServiceType
 //------------------iOS12有效----------------------
 //推特
 @"com.apple.share.Twitter.post";
 //脸书
 @"com.apple.share.Facebook.post";
 
 //------------------iOS12有效，但是不能直接使用-------
 //QQ
 @"com.tencent.mqq.ShareExtension";
 //微信
 @"com.tencent.xin.sharetimeline";
 
 //------------------未验证-------------------------
 //Instagram
 @"com.burbn.instagram.shareextension";
 //新浪微博
 @"com.apple.share.SinaWeibo.post";
 //支付宝
 @"com.alipay.iphoneclient.ExtensionSchemeShare";
 //备忘录
 @"com.apple.mobilenotes.SharingExtension";
 //提醒事项
 @"com.apple.reminders.RemindersEditorExtension";
 //iCloud
 @"com.apple.mobileslideshow.StreamShareService";
 
 com.taobao.taobao4iphone.ShareExtension    //淘宝
 com.apple.share.Flickr.post    //Flickr
 com.laiwang.DingTalk.ShareExtension    //钉钉
 com.alipay.iphoneclient.ExtensionSchemeShare   //支付宝
 com.apple.Health.HealthShareExtension  //应该是健康管理
 */

//使用UIActivityViewController，只要含有ShareExtension的App都可使用
+ (void)share:(NSString *)URLString showFrom:(UIViewController *)vc
{//此方法使用的是iOS自带的分享控件，但是要预先填好数据
    
    /*
     1、 有图片时，url 和 title无效不显示 .
     NSArray *activityItems = @[shareImg,shareURL,shareTitle];
     
     2、可以添加多张图片，默认显示第一张，可以滑动查看图片，如：
     NSArray *activityItems = @[shareImg,shareImg1,shareURL,shareTitle];
     
     3、有url 和 title 时，优先显示url，不显示title，如：
     NSArray *activityItems = @[shareTitle,shareURL];
     
     4、只有文字时，才显示文字，如：
     NSArray *activityItems = @[shareTitle];
     */
    
    NSString *text = @"测试一下";
    NSURL *url = [NSURL URLWithString:URLString];
    
    NSArray *items = @[text, url];
    UIActivityViewController *avc = [[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:nil];
    avc.excludedActivityTypes = @[
        UIActivityTypeAirDrop,
        UIActivityTypeAddToReadingList
    ];
    //QQ和微信可以使用这种方式
    [vc presentViewController:avc animated:YES completion:nil];
}

//------------------------Facebook-------------------------
#pragma mark - Facebook
+ (void)facebookShare:(NSString *)URLString showFrom:(UIViewController *)vc
{//此方法使用的是自定义分享控件，点击分享后再调用此方法，然后填写数据
    //iOS自带方式
    static NSString * const type = @"com.apple.share.Facebook.post";//这个有效
    NSLog(@"Facebook分享：%@", [SLComposeViewController isAvailableForServiceType:type]?@"yes":@"no");//可以检测App是否安装
    //未安装App无法使用此方法
    SLComposeViewController *cvc = [SLComposeViewController composeViewControllerForServiceType:type];
    [cvc addURL:[NSURL URLWithString:URLString]];
//    cvc addImage:<#(UIImage *)#>
    cvc.completionHandler = ^(SLComposeViewControllerResult result){
        if (result == SLComposeViewControllerResultCancelled) {
            NSLog(@"点击了取消");
        } else {
            NSLog(@"点击了发送");
        }
    };
    //QQ和微信不允许使用这种方式
    [vc presentViewController:cvc animated:YES completion:nil];
    
    //使用Facebook官方SDK
//    FBSDKShareLinkContent *content = [FBSDKShareLinkContent new];
//    content.contentURL = [NSURL URLWithString:URLString];
    //预定义 话题标签
//    content.hashtag = [FBSDKHashtag hashtagWithString:@"#Image"];
    //预定义 引文
//    content.quote = @"快来围观啊";
    //方式一
//    [FBSDKShareDialog showFromViewController:vc withContent:content delegate:(id<FBSDKSharingDelegate>)self];
    
    //方式二：
//    FBSDKShareDialog *dialog = [FBSDKShareDialog new];
//    dialog.fromViewController = vc;
//    dialog.shareContent = content;
//    dialog.mode = FBSDKShareDialogModeShareSheet;
//    [dialog show];
}

//使用Facebook官方SDK的回调
/*
+ (void)sharer:(id<FBSDKSharing>)sharer didCompleteWithResults:(NSDictionary *)results
{
}

+ (void)sharer:(id<FBSDKSharing>)sharer didFailWithError:(NSError *)error
{
}

+ (void)sharerDidCancel:(id<FBSDKSharing>)sharer
{
}*/

//------------------------Twitter-------------------------
#pragma mark - Twitter
+ (void)twitterShare:(NSString *)URLString showFrom:(UIViewController *)vc
{//此方法使用的是自定义分享控件，点击分享后再调用此方法，然后填写数据
    static NSString * const type = @"com.apple.share.Twitter.post";//这个有效
    NSLog(@"Twitter分享：%@", [SLComposeViewController isAvailableForServiceType:type]?@"yes":@"no");//可以检测App是否安装
    //未安装App无法使用此方法
    SLComposeViewController *cvc = [SLComposeViewController composeViewControllerForServiceType:type];
    [cvc setInitialText:@"测试"];
    [cvc addURL:[NSURL URLWithString:URLString]];
    cvc.completionHandler = ^(SLComposeViewControllerResult result){
        if (result == SLComposeViewControllerResultCancelled) {
            NSLog(@"点击了取消");
        } else {
            NSLog(@"点击了发送");
        }
    };
    [vc presentViewController:cvc animated:YES completion:nil];
    
    //使用Twitter官方SDK
//    TWTRComposer *composer = [TWTRComposer new];
//    [composer setText:@"测试一下"];
//    [composer setURL:[NSURL URLWithString:URLString]];
//    [composer showFromViewController:vc completion:^(TWTRComposerResult result) {
//        if (result == TWTRComposerResultCancelled) {
//            NSLog(@"Tweet composition cancelled");
//        } else {
//             [SVProgressHUD showSuccessWithStatus:@"Share success"];
//             [SVProgressHUD dismissWithDelay:3];
//        }
//    }];
}

//-----------------------Email分享---------------------------
#pragma mark - Email
+ (void)emailShare:(NSString *)URLString showFrom:(UIViewController *)vc
{
    MFMailComposeViewController *mcvc = [[MFMailComposeViewController alloc]init];
    mcvc.mailComposeDelegate = (id<MFMailComposeViewControllerDelegate>)self;
    [mcvc setSubject:@"测试一下"];
    [mcvc setMessageBody:URLString isHTML:NO];
    [vc presentViewController:mcvc animated:YES completion:nil];
}

+ (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    NSLog(@"Result : %ld",(long)result);
    if (result == MFMailComposeResultSent) {
    }
    if (error) {
        NSLog(@"Error : %@", error);
    }
    [controller dismissViewControllerAnimated:YES completion:nil];
}

@end

/*
 [UIImage imageNamed:@"xxx.bundle/xxx"];
 或
 //静态库获取内部的图片或xib
 NSBundle *bundle = [NSBundle bundleForClass:[self class]];
 bundle = [UIImage imageNamed:bundle inBundle:bundle compatibleWithTraitCollection:nil];
 
 NSBundle *bundle = [NSBundle bundleForClass:[FrameworkViewController class]];FrameworkViewController *frameworkVC = [[FrameworkViewController alloc] initWithNibName:@"FrameworkViewController" bundle:bundle];
 */
