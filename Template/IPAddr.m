#include <arpa/inet.h>
#include <ifaddrs.h>
+ (NSString *)IPAddress
{
    struct ifaddrs *interfaces = NULL;
    if (getifaddrs(&interfaces) != 0) return nil;
    NSString *address = nil;
    
    struct ifaddrs *addr = NULL;
    addr = interfaces;
    while (addr != NULL) {
        //tvOS：en0：网线网卡；en1：WiFi网卡
        //iOS：en1：WiFi网卡
        if(addr->ifa_addr->sa_family == AF_INET &&
           (strcmp("en0", addr->ifa_name) == 0 || strcmp("en1", addr->ifa_name) == 0)) {
            address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)addr->ifa_addr)->sin_addr)];
            break;
        }
        addr = addr->ifa_next;
    }
    // Free memory
    freeifaddrs(interfaces);
    
    return address;
}
