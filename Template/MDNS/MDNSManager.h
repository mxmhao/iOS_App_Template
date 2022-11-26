//
//  MDNSManager.h
//  AiHome
//
//  Created by macmini on 2022/5/10.
//

#import <Foundation/Foundation.h>

@class WKWebView;

NS_ASSUME_NONNULL_BEGIN

@interface MDNSManager : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (instancetype)shared;

//  这里有个意外的功能，会有UDP授权弹窗
- (void)switchMDNS:(BOOL)onOrOff completionHandler:(void (^)(int code, NSError * _Nullable error))completionHandler;

- (NSString *)IPForDeviceId:(NSString *)deviceId;
- (int)portForDeviceId:(NSString *)deviceId;

@end

NS_ASSUME_NONNULL_END
