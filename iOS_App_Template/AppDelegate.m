//
//  AppDelegate.m
//  iOS_App_Template
//
//  Created by mxm on 2018/1/22.
//  Copyright © 2019 mxm. All rights reserved.
//
/**
 os_log是apple推出的新日志系统，iOS14之后Swift可用新的Logger类，这些日志性能比NSLog好；而os_signpost结合TimeProfile在性能优化的数据展示中能够更加直观、方便，
 https://www.jianshu.com/p/4c112d8506ad
 https://blog.csdn.net/tugele/article/details/81252603 ， https://www.avanderlee.com/debugging/oslog-unified-logging/
 https://blog.csdn.net/weixin_26638123/article/details/108171733
 https://wellphone.netlify.app/post/2019/introduction_to_the_log_library_of_ios_platform/
 一些可用的日志工具：可在github上搜索 iOS + log、logger、logging、debug
 https://github.com/CocoaDebug/CocoaDebug
 https://github.com/FLEXTool/FLEX
 https://github.com/alibaba/youku-sdk-tool-woodpecker
 https://github.com/DamonHu/HDWindowLogger#chinese
 https://github.com/kean/Pulse
 https://github.com/HDB-Li/LLDebugTool
 https://github.com/pmusolino/Wormholy
 https://github.com/ripperhe/Debugo
 https://github.com/bytedance/flutter_ume
 https://github.com/dbukowski/DBDebugToolkit
 https://github.com/meitu/MTHawkeye/blob/develop/Readme-cn.md
 https://github.com/willowtreeapps/Hyperion-iOS
 https://github.com/indragiek/InAppViewDebugger
 */

#import "AppDelegate.h"
#import <os/log.h>

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    
    // #import <os/log.h>
//    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//        for (int i = 0; i < 50; i++) {
//            [NSThread sleepForTimeInterval:1];
//            //自定义的
//            os_log_t myLog = os_log_create([NSBundle.mainBundle.bundleIdentifier cStringUsingEncoding:NSASCIIStringEncoding], "myDebug");
//            os_log(myLog, "%@ -- %d", @"gogogoogogogogo1", i);
//            //默认的
//            os_log(OS_LOG_DEFAULT, "%@ -- %d", @"gogogoogogogogo1", i);
//            os_log_info(myLog, "%@ -- %d", @"gogogoogogogogo2", i);
//            os_log_debug(myLog, "%@ -- %d", @"gogogoogogogogo3", i);
//            os_log_error(myLog, "%@ -- %d", @"gogogoogogogogo4", i);
//            NSLog(@"Hi %d", i);//CocoaDebug只能监听NSLog和printf，其他的监听不到
//        }
//    });
    return YES;
}

- (void)customCocoaDebug {
    // pod 'CocoaDebug', '~> 1.7.2', :configurations => ['Debug']
    
    //--- If want to custom CocoaDebug settings ---
//    CocoaDebug.serverURL = @"google.com";
//    CocoaDebug.ignoredURLs = @[@"aaa.com", @"bbb.com"];
//    CocoaDebug.onlyURLs = @[@"ccc.com", @"ddd.com"];
//    CocoaDebug.ignoredPrefixLogs = @[@"aaa", @"bbb"];
//    CocoaDebug.onlyPrefixLogs = @[@"ccc", @"ddd"];
//    CocoaDebug.logMaxCount = 1000;
//    CocoaDebug.emailToRecipients = @[@"aaa@gmail.com", @"bbb@gmail.com"];
//    CocoaDebug.emailCcRecipients = @[@"ccc@gmail.com", @"ddd@gmail.com"];
//    CocoaDebug.mainColor = @"#fd9727";
//    CocoaDebug.additionalViewController = [TestViewController new];
    
    //Deprecated! If want to support protobuf, check branch: origin/protobuf_support
    //--- If use Google's Protocol buffers ---
//    CocoaDebug.protobufTransferMap = @{
//        @"your_api_keywords_1": @[@"your_protobuf_className_1"],
//        @"your_api_keywords_2": @[@"your_protobuf_className_2"],
//        @"your_api_keywords_3": @[@"your_protobuf_className_3"]
//    };
    
    //--- If want to manual enable App logs (Take effect the next time when app starts) ---
//    CocoaDebugSettings.shared.enableLogMonitoring = YES;
}


- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


@end
