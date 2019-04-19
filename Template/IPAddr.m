#include <arpa/inet.h>
#include <ifaddrs.h>

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
           strcmp("pdp_ip0", addr->ifa_name) == 0 {
            address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)addr->ifa_addr)->sin_addr)];
            break;
        }
    }
    // Free memory
    freeifaddrs(interfaces);
    
    return address;
}
