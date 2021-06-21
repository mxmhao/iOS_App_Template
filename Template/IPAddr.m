#include <arpa/inet.h>
#include <ifaddrs.h>
#import <NetworkExtension/NetworkExtension.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#import <CoreLocation/CoreLocation.h>
#import <Foundation/Foundation.h>

@interface NetUtils : NSObject

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
+ (NSString *)fetchWiFiName
{
//    NSArray *ifs = (__bridge_transfer id)CNCopySupportedInterfaces();
//    id info = nil;
//    for (NSString *ifname in ifs) {
//        info = (__bridge_transfer id)CNCopyCurrentNetworkInfo((__bridge CFStringRef)ifname);
//        if (info && [info count]) {
//            break;
//        }
//    }
//    return info[@"SSID"];//BSSID是Mac地址
        
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

//    NSArray<NEHotspotNetwork *> *hns = [NEHotspotHelper supportedNetworkInterfaces];
//    NSLog(@"%@", hns);
//    return hns.firstObject.SSID;
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
+ (void)fetchCurrentWiFiName:(WiFiResult)result
{
    if (!CLLocationManager.locationServicesEnabled) return;
    
    wifiResult = [result copy];
    lm = [CLLocationManager new];
    lm.delegate = [self shared];
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

//连接Wi-Fi, ssid: Wi-Fi名称
+ (void)connectWiFi:(NSString *)ssid password:(NSString *)password
{
    NEHotspotConfiguration *hc = [[NEHotspotConfiguration alloc] initWithSSID:ssid passphrase:password isWEP:NO];
    [[NEHotspotConfigurationManager sharedManager] applyConfiguration:hc completionHandler:^(NSError * _Nullable error) {
        if (error && error.code != NEHotspotConfigurationErrorAlreadyAssociated && error.code != NEHotspotConfigurationErrorUserDenied) {
            NSLog(@"加入失败");
        } else if(error.code == NEHotspotConfigurationErrorUserDenied){
            NSLog(@"已取消");
        } else {
            NSLog(@"已连接");
        }
    }];
}

@end
