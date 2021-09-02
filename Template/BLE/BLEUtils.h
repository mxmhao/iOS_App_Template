//
//  BLEUtils.h
//  
//
//  Created by min on 2021/4/28.
//

#import <Foundation/Foundation.h>

/**
 @param code 结果码
 @param dataFromBle ble返回的结果
 @param msg 结果描述
 */
typedef void(^BLEConfigCompletion)(int code, NSDictionary * _Nullable dataFromBle, NSString * _Nullable msg);
typedef void(^BLEScanResult)(int code, NSArray * _Nullable bles, NSString * _Nullable msg);

NS_ASSUME_NONNULL_BEGIN

@interface BLEUtils : NSObject

- (instancetype)initWithFetchState:(void (^_Nullable)(NSInteger state))fetchState;
/**
 蓝牙状态：
 0：已开启
 -1：未开启
 -2：没权限
 -3：不支持蓝牙
 -4：蓝牙重置中，即将更新
 -5 : 不知道的状态，即将更新
 */
- (NSInteger)bleState;
//扫描后在 [didDiscoverBles: callbackId:]
//- (void)scanDevice:(NSString *)callbackId;

- (void)scanDevice:(BLEScanResult _Nullable)result;//result 是NSArray类型的

- (void)sendMessage:(NSString *)message bleName:(NSString *)name completion:(BLEConfigCompletion _Nullable)completion;//result 是NSDictionary类型的
//当不再等待蓝牙返回消息后，请调用此方法
- (void)finish;

@end

NS_ASSUME_NONNULL_END
