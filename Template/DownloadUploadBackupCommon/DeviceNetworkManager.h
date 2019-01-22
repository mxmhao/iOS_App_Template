//
//  DeviceNetworkManager.h

#import <Foundation/Foundation.h>

typedef void(^ReachabilityResult)(BOOL isReachable);

@interface DeviceNetworkManager : NSObject

+ (instancetype)sharedManager;

+ (void)setAuthorization:(NSString *)authorization;

- (void)deviceReachability:(ReachabilityResult)result;

- (BOOL)cancel;

@end

FOUNDATION_EXTERN BOOL UsersCannotUseTheNetwork(NSInteger status, BOOL isLoadOnWiFi);// status is AFNetworkReachabilityStatus
FOUNDATION_EXTERN NSNotificationName const NetworkUsableDidChangeNotification;
FOUNDATION_EXTERN NSNotificationName const NetworkUsableItem;

