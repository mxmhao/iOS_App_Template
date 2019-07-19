//
//  DeviceNetworkManager.h
//  此类用来测试服务器是否可达

#import <Foundation/Foundation.h>

typedef void(^ReachabilityResult)(BOOL isReachable);

@interface DeviceNetworkManager : NSObject

+ (instancetype)sharedManager;

- (void)deviceReachability:(ReachabilityResult)result;

- (BOOL)cancel;

@end

FOUNDATION_EXTERN BOOL UsersCannotUseTheNetwork(NSInteger status, BOOL isLoadOnWiFi);// status is AFNetworkReachabilityStatus
FOUNDATION_EXTERN NSNotificationName const NetworkUsableDidChangeNotification;
FOUNDATION_EXTERN NSNotificationName const NetworkUsableItem;

