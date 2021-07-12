//
//  BLEConfig.h
//  
//
//  Created by mac on 2021/4/28.
//

#import <Foundation/Foundation.h>

@protocol BLEConfigDelegate <NSObject>
//搜索到的蓝牙设备
- (void)didDiscoverBles:(NSArray *_Nullable)bles;
//蓝牙返回的配网结果
- (void)resultFromBle:(NSDictionary *_Nullable)data;
//连接失败
- (void)didFailToConnect;
//连接成功
- (void)didConnect;
//配网信息发送成功
- (void)didSendNetworkSettings;
//配网信息发送失败
- (void)didFailToSendNetworkSettings;

@end

NS_ASSUME_NONNULL_BEGIN

@interface BLEUtils : NSObject

@property (weak, nonatomic, nullable) id<BLEConfigDelegate> delegate;

- (void)scanBLE;

- (void)connectBLE:(NSString *)name message:(NSString *)message;

@end

NS_ASSUME_NONNULL_END
