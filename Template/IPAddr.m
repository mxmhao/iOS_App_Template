#include <arpa/inet.h>
#include <ifaddrs.h>
#import <NetworkExtension/NetworkExtension.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#import <CoreLocation/CoreLocation.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIApplication.h>
#import <notify_keys.h>

@interface NetUtils : NSObject <CLLocationManagerDelegate>

@end

@implementation NetUtils

//"utun0": VPN

+ (NSString *)IPAddressForWiFi
{
    struct ifaddrs *interfaces = NULL;
    if (getifaddrs(&interfaces) != 0) return nil;
    NSString *address = nil;
    
    for (struct ifaddrs *addr = interfaces; addr != NULL; addr = addr->ifa_next) {
        //tvOS：en0：网线网卡；en1：WiFi网卡
        //iOS：en0：WiFi网卡
        if(addr->ifa_addr->sa_family == AF_INET &&
           (strcmp("en0", addr->ifa_name) == 0 || strcmp("en1", addr->ifa_name) == 0)) {
            address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)addr->ifa_addr)->sin_addr)];
            break;
        }
//        if (addr->ifa_addr->sa_family == AF_INET6) {//IPv6
//            char ip6[INET6_ADDRSTRLEN];
//            if(inet_ntop(AF_INET6, &((struct sockaddr_in6 *)addr->ifa_addr)->sin6_addr, ip6, INET6_ADDRSTRLEN)) {
//                address = [NSString stringWithUTF8String:ip6];
//            }
//        }
    }
    // Free memory
    freeifaddrs(interfaces);
    
    return address;
}

//蜂窝网络地址
+ (NSString *)IPAddressForWWAN
{
    struct ifaddrs *interfaces = NULL;
    if (getifaddrs(&interfaces) != 0) return nil;
    NSString *address = nil;
    
    for (struct ifaddrs *addr = interfaces; addr != NULL; addr = addr->ifa_next) {
        if(addr->ifa_addr->sa_family == AF_INET &&
           strcmp("pdp_ip0", addr->ifa_name) == 0) {
            address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)addr->ifa_addr)->sin_addr)];
            break;
        }
    }
    // Free memory
    freeifaddrs(interfaces);
    
    return address;
}

//项目中还有很多其他的配置要添加，请参照以下链接：
//获取Wi-Fi列表 https://juejin.cn/post/6844903529618866183
//获取当前连接Wi-Fi的名称, https://zhuanlan.zhihu.com/p/76119256
//https://blog.csdn.net/iOS1501101533/article/details/109306856
//必须在“Signing & Capabilities”里添加“Access WiFi Information”
+ (NSString *)fetchWiFiName
{
    CFArrayRef wifiInterfaces = CNCopySupportedInterfaces();
    if (!wifiInterfaces || CFArrayGetCount(wifiInterfaces) <= 0) {
        return nil;
    }
    NSString *wifiName = nil;
    CFIndex count = CFArrayGetCount(wifiInterfaces);
    for (CFIndex i = 0; i < count; i++) {
        CFDictionaryRef infoDic = CNCopyCurrentNetworkInfo(CFArrayGetValueAtIndex(wifiInterfaces, i));
        if (infoDic) {
            wifiName = CFDictionaryGetValue(infoDic, kCNNetworkInfoKeySSID);//BSSID是Mac地址
            CFRelease(infoDic);
            break;
        }
    }
    CFRelease(wifiInterfaces);
    return wifiName;
}

+ (instancetype)shared
{
    static dispatch_once_t onceToken;
    static NetUtils *instance;
    dispatch_once(&onceToken, ^{
        instance = [self new];
    });
    return instance;
}

typedef void(^WiFiResult)(NSString * _Nullable wifiName);

static CLLocationManager *lm;
static WiFiResult wifiResult;
//必须在“Signing & Capabilities”里添加“Access WiFi Information”
//此方法必须在主线程中调用，因为CLLocationManager的一些操作会在主线程中
+ (void)fetchCurrentWiFiName:(WiFiResult)result
{
    if (!CLLocationManager.locationServicesEnabled) {
        result(nil);
        return;
    }
    
    wifiResult = [result copy];
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        lm = [CLLocationManager new];
        lm.delegate = [self shared];
    });
}

static void doReslut(BOOL authorized)
{
    lm = nil;
    if (nil == wifiResult) return;
    if (!authorized) {
        wifiResult(nil);
        wifiResult = nil;
        return;
    }
    if (@available(iOS 14.0, *)) {
        //必须在“Signing & Capabilities”里添加“Access WiFi Information”
        [NEHotspotNetwork fetchCurrentWithCompletionHandler:^(NEHotspotNetwork * _Nullable currentNetwork) {
            wifiResult(currentNetwork.SSID);
            wifiResult = nil;
        }];
    } else {
        wifiResult([NetUtils fetchWiFiName]);
        wifiResult = nil;
    }
}

- (BOOL)hasAuthorized:(CLLocationManager *)manager status:(CLAuthorizationStatus)status
{
    switch (status) {
        case kCLAuthorizationStatusNotDetermined:
            [manager requestWhenInUseAuthorization];
            return NO;
        case kCLAuthorizationStatusRestricted:// 定位服务授权状态是受限制的。可能是由于活动限制定位服务，用户不能改变。这个状态可能不是用户拒绝的定位服务。
            //提醒用户跳到设置界面打开定位权限
            doReslut(NO);
//            [lm requestWhenInUseAuthorization];//此状态下申请也不会有弹框
            return NO;
        case kCLAuthorizationStatusDenied://已经被用户明确禁止定位
            //提醒用户跳到设置界面打开定位权限
            doReslut(NO);
//            [lm requestWhenInUseAuthorization];//此状态下申请也不会有弹框
            return NO;
            
        default:
            return YES;
    }
}

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager API_AVAILABLE(ios(14.0))
{
    if (![self hasAuthorized:manager status:manager.authorizationStatus]) {
        return;
    }
    
    static BOOL first = YES;
    if (manager.accuracyAuthorization == CLAccuracyAuthorizationFullAccuracy) {
        doReslut(YES);
        first = YES;
        return;
    }
    if (first) {
        //key在 info.plist中配置
        [manager requestTemporaryFullAccuracyAuthorizationWithPurposeKey:@"FetchWiFiNameUsageDescription"];
        first = NO;
    } else {
        doReslut(NO);
    }
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    if (![self hasAuthorized:manager status:status]) {
        return;
    }
    doReslut(YES);
}

/**
 连接Wi-Fi, ssid: Wi-Fi名称。这个功能，不用申请权限。
 必须在“Signing & Capabilities”里添加“Hotspot Configuration”
 SSID中不可以包含空格，否则无法连接成功
 SSID填写错误或包含了空格，虽然会创建一个连接，但用户是无法连接网络成功的
 模拟器上无法运行
 手机系统必须为iOS 11及更高系统
 当重复创建连接时，会抛出一个错误，但用户任然能连接上
 若删除应用，所有创建的连接都会消失
 
 https://qa.1r1g.com/sf/ask/4028706671/
 苹果的文档指出：
 如果joinOnce设置为true，则仅在配置了热点的应用程序在前台运行时，热点才会保持配置和连接。发生以下任何事件时，都会断开热点并删除其配置：

 该应用程序在后台停留超过15秒。
 设备进入睡眠状态。
 该应用程序崩溃，退出或被卸载。
 该应用程序将设备连接到其他Wi-Fi网络。
 也许我的应用被错误地识别为前景。

 设置joinOnce为false可使应用程序保持连接状态，但这不是可接受的解决方案，因为我的设备热点不提供Internet连接，因此不能在应用程序外部使用。
 设置joinOnce = false，但在这种情况下，如果未检测到 Internet连接，可能会提示用户切换到蜂窝网络。用户不会在后台自动切换，但切换到蜂窝网络是首选选项。
 */
+ (void)connectWiFi:(NSString *)ssid password:(NSString *)password
{
    NEHotspotConfiguration *hc = [[NEHotspotConfiguration alloc] initWithSSID:ssid passphrase:password isWEP:NO];
    hc.joinOnce = YES;
    [[NEHotspotConfigurationManager sharedManager] applyConfiguration:hc completionHandler:^(NSError * _Nullable error) {
        /*
         不过这里倒是有个奇怪的地方。applyConfiguration方法的回调，密码错误，不对什么的回调没有error。明明是有NEHotspotConfigurationError这个枚举的。

         所以这个时候你判断是否加入成功就不能通过有没有error来判断了。
         你可以判断ssid名跟你配置的是否一致来判断。
         */
        if (error && error.code != NEHotspotConfigurationErrorAlreadyAssociated && error.code != NEHotspotConfigurationErrorUserDenied) {
            NSLog(@"加入失败");
        } else if(error.code == NEHotspotConfigurationErrorUserDenied){
            NSLog(@"已取消");
        } else {
            NSLog(@"已连接");
        }
    }];
}

//监听WiFi切换
+ (void)onWiFiChange
{
    //CFNotificationCenterGetDarwinNotifyCenter 可用于 扩展与app 之间的通信，只可惜不能传递参数
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(), //center
        (__bridge const void *)([NSObject class]), // observer，要有这个，不然下面的无法删除
        onWiFiChangeCallback, // callback
        CFSTR(kNotifySCNetworkChange), // event name
        NULL, // object
        CFNotificationSuspensionBehaviorDeliverImmediately
    );
    //iOS10起App-Prefs:root=WIFI， iOS10之前prefs:root=WIFI      这个是网上流传的，无效
    //iOS11.3 起 App-Prefs:WIFI， 之前用 app-settings:WIFI       这个有效
    [UIApplication.sharedApplication openURL:[NSURL URLWithString:@"App-Prefs:WIFI"] options:[NSDictionary dictionary] completionHandler:nil];
}

//WiFi切换回调，CFNotificationCenterGetDarwinNotifyCenter下忽略 object 和 userInfo 参数
static void onWiFiChangeCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)

{//此回调是在主线程中运行
    NSString *notifyName = (__bridge NSString *)name;
//    if ([notifyName isEqualToString:@"com.apple.system.config.network_change"]) {
    if (CFStringCompare(name, CFSTR(kNotifySCNetworkChange), kCFCompareCaseInsensitive) == kCFCompareEqualTo) {
        [NSThread sleepForTimeInterval:0.1];//有时候要等一下才能获取到WiFi名称
        [NetUtils fetchCurrentWiFiName:^(NSString * _Nullable wifiName) {
            NSLog(@"wifi name: %@", wifiName);
        }];
    } else {
       NSLog(@"intercepted %@", notifyName);
    }
    //移除监听
    CFNotificationCenterRemoveObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        (__bridge const void *)([NSObject class]),//observer
        CFSTR(kNotifySCNetworkChange),
        NULL
    );
}

@end
