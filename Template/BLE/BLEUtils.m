//
//  BLEConfig.m
//  
//
//  Created by mac on 2021/4/28.
//

#import "BLEUtils.h"
#import <CoreBluetooth/CoreBluetooth.h>

static unsigned short const crc16tab[] = {
    0x0000, 0x1021, 0x2042, 0x3063, 0x4084, 0x50a5, 0x60c6, 0x70e7,
    0x8108, 0x9129, 0xa14a, 0xb16b, 0xc18c, 0xd1ad, 0xe1ce, 0xf1ef,
};
//CRC-16/XMODEM 一种数据校验码算法，用来校验发送和接收到的蓝牙数据包，根据你们蓝牙协议去更换算法
unsigned short crc16_xmodem(unsigned char *ptr, unsigned int len)
{
    unsigned short crc = 0;
    unsigned char ch = 0;
 
    while (len-- != 0)
    {
        ch = crc >> 12;
        crc <<= 4;
        crc ^= crc16tab[ch ^ (*ptr / 16)];
 
        ch = crc >> 12;
        crc <<= 4;
        crc ^= crc16tab[ch ^ (*ptr & 0x0f)];
        ptr++;
    }
    return crc;
}

@interface BleDataBuilder : NSObject

+ (NSArray<NSData *> *)buildPkgs:(NSString *)msg;
+ (NSDictionary *)buildResultData:(NSData *)data;

@end

@interface BLEUtils () <CBCentralManagerDelegate, CBPeripheralDelegate>

@end

@implementation BLEUtils
{
    CBCentralManager *_centralManager;
    CBPeripheral *_peripheral;//当前连接的设备
    CBCharacteristic *_read;
    CBCharacteristic *_write;
    NSMutableDictionary<NSString *, CBPeripheral *> *_bles;
    
    NSArray<NSData *> *_dataPkgs;//分包后的二进制数据
    
    //数据包重发次数；根据你们的协议去判断要不要重发
    UInt8 _dataResendTimes;
    UInt8 _dataIndex;//当前发送的数据在数组中的下标
    NSTimer *_resendTimer;//数据包重发的延迟，用来取消
    //蓝牙重连次数；重连2次还没能够发送数据成功，就反馈数据失败
    UInt8 _deviceConnTimes;
    NSTimer *_stopScanTimer;    //延迟停止扫描
    NSTimer *_watiResultTimer;  //延迟等待数据结果返回
    NSTimer *_cancelConnTimer;  //延迟取消连接
}

//根据你们的协议去修改
static NSString * const BLE_UUID_Service = @"000F";//服务的uuid
static NSString * const BLE_UUID_Characteristic_OUT = @"0001";//write
static NSString * const BLE_UUID_Characteristic_IN = @"0002";//read/write/notify
//设备名的前缀
#define BLE_NAME_Prefix @"用你们的前缀" //我们蓝牙的专用前缀

- (instancetype)init
{
    self = [super init];
    if (self) {
        _bles = [NSMutableDictionary dictionaryWithCapacity:5];
        dispatch_queue_t centralQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        NSDictionary *dic = @{
            CBCentralManagerOptionShowPowerAlertKey: @YES,//当蓝牙关闭时，自动弹出打开提示框
        };
        _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:centralQueue options:dic];
        _dataResendTimes = 0;
        _deviceConnTimes = 0;
    }
    return self;
}

- (void)scanBLE
{
    if (@available(iOS 13.0, *)) {
        CBManagerAuthorization auth;
        if (@available(iOS 13.1, *)) {
            auth = CBCentralManager.authorization;
        } else {
            auth = _centralManager.authorization;
        }
        if (auth != CBManagerAuthorizationNotDetermined && auth <= CBManagerAuthorizationDenied) {
//            [self.delegate didFailToScan:-1 message:@"没有蓝牙访问权限" callbackId:callbackId];
            return;
        }
    }
    if (_centralManager.state <= CBManagerStatePoweredOff) {
        return;
    }
    if (nil != _stopScanTimer) {
        [_stopScanTimer invalidate];
        _stopScanTimer = nil;
    }
    if (_centralManager.isScanning) {
        [_centralManager stopScan];
    }
    [self clean];
    [_bles removeAllObjects];
    //不重复扫描已发现设备
    NSDictionary *option = @{
        CBCentralManagerScanOptionAllowDuplicatesKey: @NO,
    };
    NSArray *uuids = @[
//        [CBUUID UUIDWithString:@"00FF"]//搜索有你指定服务的设备
    ];
    [_centralManager scanForPeripheralsWithServices:uuids options:option];
//    NSLog(@"开始搜索");
    //这个延迟停止很重要
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        //下面不能在app启动过程中调用，不然搜索不到蓝牙设备的，真的是搞死个人呐
        [self stopScan];
    });
}

//下面不能在app启动过程中调用，不然搜索不到蓝牙设备的，真的是搞死个人呐
- (void)stopScan
{
    //定时停止扫描
    __weak __typeof(&*self)weakSelf = self;
    _stopScanTimer = [NSTimer scheduledTimerWithTimeInterval:3 repeats:NO block:^(NSTimer * _Nonnull timer) {
        __strong __typeof(&*weakSelf)self = weakSelf;
        [self->_centralManager stopScan];
        self->_stopScanTimer = nil;
        NSLog(@"停止搜索");
        //组织数据
        NSMutableArray *arr = [NSMutableArray arrayWithCapacity:self->_bles.count];
        for (NSString *key in self->_bles.allKeys) {
            NSDictionary *device = @{
                @"devName" : key
            };
            [arr addObject:device];
        }
        //把数据返回给前端显示
        [self->_delegate didDiscoverBles:arr];
    }];
    //开启循环，不然_stopScanTimer到时不会运行
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:4]];
}

- (void)connectBLE:(NSString *)name message:(NSString *)message
{
    if (_bles.count == 0) return;//没有数据
    if (_peripheral && _peripheral.state == CBPeripheralStateConnected) {
        [_centralManager cancelPeripheralConnection:_peripheral];
    }
    
    CBPeripheral *per = _bles[name];
    if (nil == per) return;
    _dataPkgs= [BleDataBuilder buildPkgs:message];
    [_centralManager connectPeripheral:per options:nil];//发起连接的命令
    
    //长时间连接不上要自己断开连接，这个延迟停止很重要
    __weak __typeof(&*self)weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        self->_cancelConnTimer = [NSTimer scheduledTimerWithTimeInterval:8 repeats:NO block:^(NSTimer * _Nonnull timer) {
            __strong __typeof(&*weakSelf)self = weakSelf;
            [self->_centralManager cancelPeripheralConnection:per];
        }];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:8.5]];
    });
}

- (void)writeValue:(NSData *)data
{
    NSLog(@"写第%d包", _dataIndex);
    [_peripheral writeValue:data forCharacteristic:_write type:CBCharacteristicWriteWithResponse];
    
    //等待一段时间，要是没有返回信息，就要重发，这个要根据你们的协议去修改
    __weak __typeof(&*self)weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        //这个不能占用 蓝牙回调 线程
        self->_resendTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:NO block:^(NSTimer * _Nonnull timer) {
            __strong __typeof(&*weakSelf)self = weakSelf;
            [self resendPackage:data];
        }];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.5]];
    });
}

- (void)resendPackage:(NSData *)data
{
    NSLog(@"resendPackage: %d", _dataResendTimes);
    _dataResendTimes++;
    if (_dataResendTimes < 3) {//重发不能超过3次
        [self writeValue:data];
    } else {
        //3次都没收到正确回复，断开重连
        [self disConnect];
        //还要给用户一个提示？
    }
}

- (void)disConnect
{
    if (nil == _peripheral) return;
    
    [_centralManager cancelPeripheralConnection:_peripheral];
    if (nil != _peripheral) {
        [self clean];
    }
}

- (void)clean
{
    _peripheral = nil;
    _read = nil;
    _write = nil;
    _dataPkgs = nil;
    _dataResendTimes = 0;
    _dataIndex = 0;
    if (nil != _resendTimer) {
        [_resendTimer invalidate];
        _resendTimer = nil;
    }
    _deviceConnTimes = 0;
}

#pragma mark - 蓝牙回调
//蓝牙状态改变
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    switch (central.state) {
        case CBManagerStateUnknown:
            NSLog(@"CBManagerStateUnknown");
            break;
        case CBManagerStateResetting:
            NSLog(@"CBManagerStateResetting");
            break;
        case CBManagerStateUnsupported:
            NSLog(@"CBManagerStateUnsupported");
            break;
        case CBManagerStateUnauthorized:
            NSLog(@"CBManagerStateUnauthorized");
            break;
        case CBManagerStatePoweredOff:
            NSLog(@"CBManagerStatePoweredOff");
            //通知用户请打开蓝牙
            break;
        case CBManagerStatePoweredOn:
            NSLog(@"CBManagerStatePoweredOn");
            [self scanBLE];
            break;
        default:
            break;
    }
}


//扫描到设备后的回调
- (void)centralManager:(CBCentralManager *)central
 didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary *)advertisementData
                  RSSI:(NSNumber *)RSSI
{
    NSString *name = advertisementData[CBAdvertisementDataLocalNameKey];
    if (![name hasPrefix:BLE_NAME_Prefix]) return;
    NSLog(@"%@ -- %@", name, peripheral.name);//名字根据你们的蓝牙设备看，两种可能不同
    NSLog(@"advertisementData: %@，\nRSSI:%@", advertisementData, RSSI);
    [_bles setObject:peripheral forKey:name];
}

//连接成功的回调
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    if (_cancelConnTimer) {
        [_cancelConnTimer invalidate];
        _cancelConnTimer = nil;
    }
    [_delegate didConnect];
    //要不要给用户一个提示？
    NSLog(@"连接成功：%@", peripheral.name);
    _peripheral = peripheral;
    peripheral.delegate = self;
    //连接成功之后寻找你指定的服务，传nil会寻找所有服务
    [peripheral discoverServices:@[[CBUUID UUIDWithString:BLE_UUID_Service]]];
//    [_peripheral discoverServices:@[[CBUUID UUIDWithString:@"1800"]]];//基础服务被iOS屏蔽了
}

//连接失败的回调
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error
{
    if (_cancelConnTimer) {
        [_cancelConnTimer invalidate];
        _cancelConnTimer = nil;
    }
    //这个断开连接很重要
    [central cancelPeripheralConnection:peripheral];
    //要不要给用户一个提示?
    [_delegate didFailToConnect];
    if (error) {
        NSLog(@"连接失败: %@", error);
    }
//    _deviceConnTimes++;
//    if (_deviceConnTimes >= 2) {
//        return;
//    }
//    [central connectPeripheral:peripheral options:nil];
}

//连接断开的回调
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error
{
    //这个断开连接很重要
    [central cancelPeripheralConnection:peripheral];
    [self clean];
    if (error) {//CBErrorPeripheralDisconnected
        NSLog(@"连接断开错误：%@", error);
    } else {
        NSLog(@"连接断开");
    }
}

//发现服务的回调
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (error || peripheral.services.count == 0) {
        NSLog(@"查找服务失败：%@", error);
        [self disConnect];
        return;
    }
    
    NSArray *uuids = @[
        [CBUUID UUIDWithString:BLE_UUID_Characteristic_OUT],
        [CBUUID UUIDWithString:BLE_UUID_Characteristic_IN]
    ];
    [peripheral discoverCharacteristics:uuids forService:peripheral.services.firstObject];
}

//发现characteristics，由发现服务调用（上一步），获取读和写的characteristics
- (void)peripheral:(CBPeripheral *)peripheral
didDiscoverCharacteristicsForService:(CBService *)service
             error:(NSError *)error
{
    if (error || service.characteristics.count == 0) {
        [self disConnect];
        NSLog(@"查找特征失败: %@", error);
        return;
    }
    
    for (CBCharacteristic *characteristic in service.characteristics) {
//        NSLog(@"uuid: %@", characteristic.UUID);
        if ([characteristic.UUID.UUIDString isEqualToString:BLE_UUID_Characteristic_IN]) {
            _read = characteristic;
            //设置监听，订阅
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
//            [peripheral discoverDescriptorsForCharacteristic:characteristic];
        } else if ([characteristic.UUID.UUIDString isEqualToString:BLE_UUID_Characteristic_OUT]) {
            _write = characteristic;
        }
    }
    
    _dataIndex = 0;
    [self writeValue:_dataPkgs.firstObject];
}

- (void)peripheral:(CBPeripheral *)peripheral
didDiscoverDescriptorsForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error
{
//    NSLog(@"Des: %@", characteristic.descriptors);
//    Byte byte[] = {0x01, 0x00};
//    [peripheral writeValue:[NSData dataWithBytes:byte length:2] forDescriptor:characteristic.descriptors.firstObject];
}

//是否写入成功的代理
- (void)peripheral:(CBPeripheral *)peripheral
didWriteValueForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error
{
//    NSLog(@"back uuid: %@", characteristic.UUID);
    if (error) {
        [_delegate didFailToSendNetworkSettings];
//        [self disConnect];
        NSLog(@"===写入错误：%@", error);
//        [self resendPackage:_dataFrames[_dataIndex]];
    } else {
        NSLog(@"===写入成功");
        if (_resendTimer) {
            [_resendTimer invalidate];
        }
        
        //发送一个包成功后，要不要给用户一个提示?
        _dataResendTimes = 0;
        _dataIndex++;
        if (_dataIndex < _dataPkgs.count) {//数据包还没发完
            [self writeValue:_dataPkgs[_dataIndex]];
            return;
        }
        //数据包发完了
        //数据信息发送成功，要不要给用户一个提示？
        [_delegate didSendNetworkSettings];
        __weak __typeof(&*self)weakSelf = self;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            //等待一段时间，没有反馈数据结果就返回错误，根据你们的协议去改
            self->_watiResultTimer = [NSTimer scheduledTimerWithTimeInterval:5 repeats:NO block:^(NSTimer * _Nonnull timer) {
                __strong __typeof(&*weakSelf)self = weakSelf;
                [self->_delegate resultFromBle:nil];
            }];
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:6]];
        });
    }
}

//监听状态发生改变
- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error
{
    if (error) {
        NSLog(@"设置监听出错: %@", error);
//        [self disConnect];
    }
    NSLog(@"订阅状态变了 uuid: %@,: %d", characteristic.UUID, characteristic.isNotifying);
}
//数据接收
- (void)peripheral:(CBPeripheral *)peripheral
didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error
{
    if (error) {//出错了要干嘛？
        NSLog(@"didUpdateValue: %@", error);
//        [self resendPackage:_dataFrames[_dataIndex]];//重发？
//        [_delegate didFailToSendNetworkSettings];
        [self disConnect];
        return;
    }
    
    //只监听了一个特征，要不要做判断？
//     if ([characteristic.UUID.UUIDString isEqualToString:BLE_UUID_Characteristic_IN]) {
//     }
    NSData *data = characteristic.value;

    [_watiResultTimer invalidate];//有结果返回了就取消定时
    NSDictionary *result = [BleDataBuilder buildResultData:data];
    if (nil == result) {
//            [self disConnect];
    } else {
        [_delegate resultFromBle:result];
    }
}

@end


@implementation BleDataBuilder

//根据你们的蓝牙数据协议，组装你们的数据包
+ (NSArray<NSData *> *)buildPkgs:(NSString *)msg
{
    return nil;
}

+ (NSData *)buildSinglePkg:(NSData *)data range:(NSRange const)range
{
    return nil;
}

+ (NSDictionary *)buildResultData:(NSData *)data
{
    return nil;
}

@end
