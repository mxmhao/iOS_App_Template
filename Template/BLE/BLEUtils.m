//
//  BLEUtils.m
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
+ (BOOL)isSendDataCheckError:(NSData *)data;

@end

@interface BLEUtils () <CBCentralManagerDelegate, CBPeripheralDelegate>

@end

typedef void(^FetchState)(NSInteger state);

@implementation BLEUtils
{
    CBCentralManager *_centralManager;
    CBPeripheral *_peripheral;//当前连接的设备
    CBCharacteristic *_read;
    CBCharacteristic *_write;
    NSMutableDictionary<NSString *, CBPeripheral *> *_bles;
    
    NSArray<NSData *> *_dataPkgs;//分包后的二进制数据
    
    //数据包重发次数；如果向蓝牙外设发送数据后1秒内没有反馈ack，那么就要重发，重发超过3次就要重新连接蓝牙
    UInt8 _dataResendTimes;
    UInt8 _dataIndex;//当前发送的数据在数组中的下标
    BOOL _returnAck;//是否有ack回复
    NSTimer *_resendTimer;//数据包重发的延迟，用来取消
    //蓝牙重连次数；重连2次还没能够发送数据成功，就反馈配网失败
    UInt8 _deviceConnTimes;
    NSTimer *_stopScanTimer;    //延迟停止扫描
    NSTimer *_waitResultTimer;  //延迟等待配网结果返回
    NSTimer *_cancelConnTimer;  //延迟取消连接
    NSTimer *_waitOpenBluetoothTimer;  //等待蓝牙开启
    
    NSString *_callbackId;
    FetchState _fetchState;
    BOOL _isScaning;
}

//根据你们的协议去修改
static NSString * const BLE_UUID_Service = @"000F";//服务的uuid
static NSString * const BLE_UUID_Characteristic_OUT = @"0001";//write
static NSString * const BLE_UUID_Characteristic_IN = @"0002";//read/write/notify
//设备名的前缀
#define BLE_NAME_Prefix @"用你们的前缀" //我们蓝牙的专用前缀

- (instancetype)initWithFetchState:(void (^_Nullable)(NSInteger))fetchState
{
    self = [super init];
    if (self) {
        if (fetchState) {
            _fetchState = [fetchState copy];
        }
        _bles = [NSMutableDictionary dictionaryWithCapacity:5];
//        NSDictionary *options = @{
//            CBCentralManagerOptionShowPowerAlertKey : @YES,//当蓝牙关闭时，自动弹出打开提示框，建议最好不要弹出，因为还开启后还有繁琐的步骤，所以还是提示用户自己去开启的好
//        };
        //这里指定是全局并发队列，下面的代理调用的时候就是非主线程，有些操作需要在主线程中，请注意
        dispatch_queue_t centralQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:centralQueue options:nil];
        _dataResendTimes = 0;
        _deviceConnTimes = 0;
    }
    return self;
}

- (void)dealloc
{
    if (_centralManager && _centralManager.isScanning) {
        [_centralManager stopScan];
    }
}

- (void)scanDevice:(NSString *)callbackId
{
    _callbackId = callbackId;
    if (@available(iOS 13.0, *)) {
        CBManagerAuthorization auth;
        if (@available(iOS 13.1, *)) {
            auth = CBCentralManager.authorization;
        } else {
            auth = _centralManager.authorization;
        }
        if (CBManagerAuthorizationRestricted == auth || CBManagerAuthorizationDenied == auth) {
            [self.delegate didFailToScan:-3 message:@"没有蓝牙访问权限" callbackId:callbackId];
            return;
        }
    }
    if (_centralManager.state <= CBManagerStatePoweredOff) {
        NSLog(@"bluetooth state:%ld", _centralManager.state);
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
        CBCentralManagerScanOptionAllowDuplicatesKey : @NO,
    };
    NSArray *uuids = @[
//        [CBUUID UUIDWithString:@"00aa"]
    ];
    [_centralManager scanForPeripheralsWithServices:uuids options:option];
    _isScaning = YES;
//    NSLog(@"开始搜索");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        //下面不能在app启动过程中调用，不然搜索不到蓝牙设备的，真的是搞死个人呐
        [self stopScan];
    });
}

//下面不能在app启动过程中调用，不然搜索不到蓝牙设备的，真的是搞死个人呐
- (void)stopScan
{
    CFTimeInterval waitTime = 6;
    //定时停止扫描
    __weak __typeof(self)weakSelf = self;
    _stopScanTimer = [NSTimer scheduledTimerWithTimeInterval:waitTime repeats:NO block:^(NSTimer * _Nonnull timer) {
        __strong __typeof(weakSelf)self = weakSelf;
        if (nil == self) {
            return;
        }
        [self->_centralManager stopScan];
        self->_stopScanTimer = nil;
        self->_isScaning = NO;
        NSLog(@"停止搜索");
        [self backData];
    }];
    //开启循环，不然_stopScanTimer到时不会运行
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:waitTime+0.1]];
}

- (void)backData
{
    //组织数据
    NSMutableArray *arr = [NSMutableArray arrayWithCapacity:self->_bles.count];
    for (NSString *key in self->_bles.allKeys) {
//            CBPeripheral *per = _bles[key];
        NSDictionary *device = @{
            @"ssid" : key,
            @"type": @"ble",
        };
        [arr addObject:device];
    }
    //把数据返回给前端显示
    [self->_delegate didDiscoverBles:arr callbackId:self->_callbackId];
}

- (void)connectBLE:(NSString *)name message:(NSString *)message
{
    if (_bles.count == 0) {//要不要给用户提示
        [_delegate didFailToConnect];
        return;//没有数据
    }
    if (_peripheral && _peripheral.state == CBPeripheralStateConnected) {
        [_centralManager cancelPeripheralConnection:_peripheral];
    }
    
    CBPeripheral *per = _bles[name];
    if (nil == per) {//要不要给用户提示
        [_delegate didFailToConnect];
        return;
    }
    _dataPkgs = [BleDataBuilder buildPkgs:message];
    [_centralManager connectPeripheral:per options:nil];//发起连接的命令
    //连接超时要停止
    __weak __typeof(&*self)weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        CFTimeInterval waitTime = 8;
        self->_cancelConnTimer = [NSTimer scheduledTimerWithTimeInterval:waitTime repeats:NO block:^(NSTimer * _Nonnull timer) {
            __strong __typeof(&*weakSelf)self = weakSelf;
            if (nil == self) {
                return;
            }
            [self->_centralManager cancelPeripheralConnection:per];
        }];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:waitTime+0.1]];
    });
}

//这里的逻辑是：只要didUpdateValueForCharacteristic没有ack反馈就会重发，所以不用考虑各种重发问题了
- (void)writeValue:(NSData *)data
{
    NSLog(@"写第%d包", _dataIndex);
    _returnAck = NO;
    [_peripheral writeValue:data forCharacteristic:_write type:CBCharacteristicWriteWithResponse];
    
    __weak __typeof(self)weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        //这个不能占用 蓝牙回调 线程
        CFTimeInterval waitTime = 1;
        self->_resendTimer = [NSTimer scheduledTimerWithTimeInterval:waitTime repeats:NO block:^(NSTimer * _Nonnull timer) {
            __strong __typeof(weakSelf)self = weakSelf;
            if (nil == self) {
                return;
            }
            if (self->_returnAck) return;
            [self resendPackage:data];
        }];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:waitTime+0.1]];
    });
}

- (void)resendPackage:(NSData *)data
{
    NSLog(@"resendPackage: %d", _dataResendTimes);
    _dataResendTimes++;
    if (_dataResendTimes < 3) {//重发不能超过3次
        [self writeValue:data];
    } else {
        //3次都没收到ack回复，断开重连
        [self disConnect];
        //还要给用户一个提示？
        [_delegate didFailToSendNetworkSettings];
//        [_delegate resultFromBle:nil code:-1 message:@"3次都没收到ack回复，断开重连"];
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
    _returnAck = NO;
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
    if (_fetchState) {
        _fetchState(central.state - CBManagerStatePoweredOn);
        _fetchState = nil;
    }
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
            if (nil != _callbackId) {
                [self.delegate didFailToScan:-3 message:@"没有蓝牙访问权限" callbackId:_callbackId];
            }
            break;
        case CBManagerStatePoweredOff:
        {
            NSLog(@"CBManagerStatePoweredOff");
            if (_isScaning) {
                NSLog(@"关了还扫？");
                if (nil != _callbackId) {
                    [self.delegate didDiscoverBles:nil callbackId:_callbackId];
                }
                _callbackId = nil;
                _isScaning = NO;
                return;
            }
            if (nil == _callbackId) {
                return;
            }
            //通知用户请打开蓝牙
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                CFTimeInterval waitTime = 10;
                self->_waitOpenBluetoothTimer = [NSTimer scheduledTimerWithTimeInterval:waitTime repeats:NO block:^(NSTimer * _Nonnull timer) {
                    if (nil == self) {
                        return;
                    }
                    if (nil != self->_callbackId) {
                        [self.delegate didDiscoverBles:nil callbackId:self->_callbackId];
                    }
                    self->_callbackId = nil;
                }];
                [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:waitTime+0.1]];
            });
        }
            break;
        case CBManagerStatePoweredOn:
            NSLog(@"CBManagerStatePoweredOn");
            if (_waitOpenBluetoothTimer) {
                [_waitOpenBluetoothTimer invalidate];
                _waitOpenBluetoothTimer = nil;
            }
            if (nil != _callbackId) {
                [self scanDevice:_callbackId];
            }
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
    [_bles setObject:peripheral forKey:name];
    NSLog(@"%@ -- %@", name, peripheral.name);//有些时候这两个名字不一样，最好要嵌入式那边做成一样
    NSLog(@"advertisementData: %@，\nRSSI:%@", advertisementData, RSSI);
//    [_centralManager connectPeripheral:peripheral options:nil];
}

//连接成功的回调
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    if (_cancelConnTimer) {
        [_cancelConnTimer invalidate];
        _cancelConnTimer = nil;
    }
    //要不要给用户一个提示？
    [_delegate didConnect];
//    [_delegate resultFromBle:nil code:1 message:@"已连接到蓝牙外设"];
    _peripheral = peripheral;
    peripheral.delegate = self;
    //连接成功之后寻找服务，传nil会寻找所有服务
    [peripheral discoverServices:@[[CBUUID UUIDWithString:BLE_UUID_Service]]];
//    [_peripheral discoverServices:@[[CBUUID UUIDWithString:@"1800"]]];//基础服务被iOS屏蔽了
    NSLog(@"连接成功：%@", peripheral.name);
}

//连接失败的回调
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error
{
    if (_cancelConnTimer) {
        [_cancelConnTimer invalidate];
        _cancelConnTimer = nil;
    }
    [central cancelPeripheralConnection:peripheral];
    //要不要给用户一个提示?
    [_delegate didFailToConnect];
//    [_delegate resultFromBle:nil code:-2 message:@"连接蓝牙失败"];

    NSLog(@"连接失败: %@", error);
//    _deviceConnTimes++;
//    if (_deviceConnTimes >= 2) {
//        return;
//    }
//    [central connectPeripheral:peripheral options:nil];
}

//连接断开的回调
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error
{
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
        [self disConnect];
        [_delegate didFailToSendNetworkSettings];
//        [_delegate resultFromBle:nil code:-3 message:@"找不到我们需要的蓝牙服务"];
        NSLog(@"查找服务失败：%@", error);
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
        [_delegate didFailToSendNetworkSettings];
//        [_delegate resultFromBle:nil code:-4 message:@"找不到我们需要的蓝牙特征"];
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
    if (error) {//这里都出错了，再发数据都没意义了？手机或者蓝牙外设出问题了？
        [self disConnect];
        [_delegate didFailToSendNetworkSettings];
//        [_delegate resultFromBle:nil code:-5 message:@"给蓝牙外设写数据写失败了"];
        NSLog(@"===写入错误：%@", error);
//        [self resendPackage:_dataPkgs[_dataIndex]];
    } else if (_returnAck) {//写入成功了，但是没ack反馈，有可能是这里回调快点，下面的ack反馈慢点
        
    } else {
        NSLog(@"===写入成功");
    }
}

//监听状态发生改变
- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error
{
    if (error) {
        [self disConnect];
        [_delegate didFailToSendNetworkSettings];
//        [_delegate resultFromBle:nil code:-6 message:@"监听蓝牙外设失败，收不到蓝牙数据的"];
        NSLog(@"设置监听出错: %@", error);
    }
    NSLog(@"订阅状态变了 uuid: %@,: %d", characteristic.UUID, characteristic.isNotifying);
}
//数据接收
- (void)peripheral:(CBPeripheral *)peripheral
didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error
{
//    return;
    //如果返回了ack
    _returnAck = YES;
    if (_resendTimer) {
        [_resendTimer invalidate];
    }
    
    if (error) {//出错了要干嘛？这个错误比较严重，重发意义不大？手机或者蓝牙外设出问题了？
//        [self resendPackage:_dataPkgs[_dataIndex]];//重发？
        [self disConnect];
        [_delegate didFailToSendNetworkSettings];
//        [_delegate resultFromBle:nil code:-7 message:@"蓝牙外设给我回数据出错了"];
        NSLog(@"didUpdateValue: %@", error);
        return;
    }
    
    //只监听了一个特征，要不要做判断？
//     if ([characteristic.UUID.UUIDString isEqualToString:BLE_UUID_Characteristic_IN]) {
//     }
    NSData *data = characteristic.value;
    if (data.length < 6) {
//        [self disConnect];
//        [_delegate didFailToSendNetworkSettings];
    }
    static Byte const ack = 0xAC;//ack数据的特征
    Byte byte[1];
    [data getBytes:byte length:1];
    if (ack != byte[0]) {//不是ack数据，而是反馈配网结果的数据
        NSDictionary *result = [BleDataBuilder buildResultData:data];
        if (nil == result) {
            [self disConnect];
//            [_delegate resultFromBle:nil code:-8 message:@"蓝牙外设发来的包无法用Json解析"];
            return;
        }
        int const code = [result[@"code"] intValue];
        /**
         code：
            0   已经连上服务器了，
            1   开始去连接路由器，
            2   连接路由器成功，
            -1   连接失败
         */
        if (code == 0 || code == -1) {
            [_waitResultTimer invalidate];//有结果返回了就取消定时
            [self disConnect];
        }
        [_delegate resultFromBle:result];
//        [_delegate resultFromBle:result code:0 message:@"蓝牙外设发过来的包"];
        return;
    }
    NSLog(@"%@, 蓝牙ack回复：%@", characteristic.UUID, data);
    //获取订阅特征回复的数据，查看蓝牙设备是否告诉我们，它接收的数据没有通过校验
    if ([BleDataBuilder isSendDataCheckError:data]) {//校验数据有误需要重发此包？这里重发意义不大，要么数据有问题，要么校验算法有问题，要么蓝牙外设的校验有问题。尽量不考虑传输过程中出现的错误，如果是这个错误就得检查手机或者外设的蓝牙有没有问题了，测出失败概率
//        [self resendPackage:_dataPkgs[_dataIndex]];
        [self disConnect];
        [_delegate didFailToSendNetworkSettings];
//        [_delegate resultFromBle:nil code:-9 message:@"给蓝牙外设发的包没通过数据校验"];
        return;
    }
    
    //发送一个包成功后，要不要给用户一个提示
    _dataResendTimes = 0;//发一个新包时归零
    _dataIndex++;
    if (_dataIndex < _dataPkgs.count) {//配网包还没发完
        [self writeValue:_dataPkgs[_dataIndex]];
        return;
    }
    //配网包发完了
    //配网信息发送成功，要不要给用户一个提示？
    [_delegate didSendNetworkSettings];
//    [_delegate resultFromBle:nil code:2 message:@"给蓝牙外设的配网信息包已经发完了"];
    NSLog(@"配网包发完了");
    __weak __typeof(self)weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        //等待一段时间，没有反馈配网结果就返回错误
        CFTimeInterval waitTime = 30;
        self->_waitResultTimer = [NSTimer scheduledTimerWithTimeInterval:waitTime repeats:NO block:^(NSTimer * _Nonnull timer) {
            __strong __typeof(weakSelf)self = weakSelf;
            if (nil == self) {
                return;
            }
            [self disConnect];
            [self->_delegate resultFromBle:nil];//
//            [self->_delegate resultFromBle:nil code:-10 message:@"等待蓝牙返回结果超时了"];
            NSLog(@"--蓝牙等待结果超时");
        }];
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:waitTime+0.1]];
    });
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

+ (BOOL)isSendDataCheckError:(NSData *)data
{
    return NO;
}

@end
