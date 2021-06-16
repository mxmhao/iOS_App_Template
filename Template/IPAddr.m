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

//获取当前连接Wi-Fi的名称
+ (NSString *)getCurrentWiFiName
{
//        如果是iOS13以上 未开启地理位置权限 需要提示一下
    if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined) {
       CLLocationManager *locationManager = [[CLLocationManager alloc] init];
       if (@available(iOS 14.0, *)) {
           /**
            Info.plist文件中加入
            <key>NSLocationTemporaryUsageDescriptionDictionary</key>
            <dict>
                <key>FetchWiFiNameUsageDescription</key>
                <string>APP需要获取当前WiFi信息</string>
            </dict>
            */
           //获取精确定位
           [locationManager requestTemporaryFullAccuracyAuthorizationWithPurposeKey:@"FetchWiFiNameUsageDescription"];
       } else if (@available(iOS 13.0, *)) {
           //获取定位权限
           [locationManager requestWhenInUseAuthorization];
       }
    }
    if (@available(iOS 14.0, *)) {
#warning 这里是回调,请自行处理返回值.
        [NEHotspotNetwork fetchCurrentWithCompletionHandler:^(NEHotspotNetwork * _Nullable currentNetwork) {
            NSLog(@"%@<--", currentNetwork.SSID);//BSSID是Mac地址, iOS14
        }];
    } else {
        NSArray *ifs = (__bridge_transfer id)CNCopySupportedInterfaces();
        id info = nil;
        for (NSString *ifnam in ifs) {
            info = (__bridge_transfer id)CNCopyCurrentNetworkInfo((__bridge CFStringRef)ifnam);
            if (info && [info count]) {
                break;
            }
        }
//        kCNNetworkInfoKeySSID
        return info[@"SSID"];//BSSID是Mac地址
    }
//    NSArray<NEHotspotNetwork *> *hns = [NEHotspotHelper supportedNetworkInterfaces];
//    NSLog(@"%@", hns);
//    return hns.firstObject.SSID;
    
    return nil;
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
