//
//  BLEUtils.h
//  
//
//  Created by mac on 2021/4/28.
//

#import <Foundation/Foundation.h>

@protocol BLEUtilsDelegate <NSObject>
@optional
//搜索到的蓝牙设备, scanDevice的回调
- (void)didDiscoverBles:(NSArray *_Nullable)bles callbackId:(NSString *_Nullable)callbackId;
//搜索到的蓝牙设备, scanDevice的回调
- (void)didFailToScan:(int)code message:(NSString *_Nullable)msg callbackId:(NSString *_Nullable)callbackId;
//蓝牙返回的配网结果
- (void)resultFromBle:(NSDictionary *_Nullable)bleResult;
- (void)resultFromBle:(NSDictionary *_Nullable)bleResult code:(int)code message:(NSString *_Nullable)msg;
//连接失败
- (void)didFailToConnect;
//连接成功
- (void)didConnect;
//配网信息发送成功
- (void)didSendNetworkSettings;
//配网信息发送失败
- (void)didFailToSendNetworkSettings;

@end

typedef void(^BLEConfigCompletion)(id _Nullable result, int code, NSString * _Nullable msg);
//typedef void(^BLEConfigScanResult)(NSArray * _Nullable bles, int code, NSString * _Nullable msg);

NS_ASSUME_NONNULL_BEGIN

@interface BLEUtils : NSObject

@property (weak, nonatomic, nullable) id<BLEUtilsDelegate> delegate;
/**
 蓝牙状态：
 0：已开启
 -1：未开启
 -2：没权限
 -3：不支持蓝牙
 -4：蓝牙重置中，即将更新
 -5 : 不知道的状态，即将更新
 */
- (instancetype)initWithFetchState:(void (^_Nullable)(NSInteger state))fetchState;
//扫描后在 [didDiscoverBles: callbackId:]
- (void)scanDevice:(NSString *)callbackId;

//- (void)scanDevice:(BLEConfigCompletion)result;//result 是NSArray类型的

- (void)connectBLE:(NSString *)name message:(NSString *)message;

//- (void)sendMessage:(NSString *)message bleName:(NSString *)name completion:(BLEConfigCompletion)completion;//result 是NSDictionary类型的
@end

NS_ASSUME_NONNULL_END
