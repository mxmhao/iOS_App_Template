//
//  DeviceNetworkManager.m
//  此类用来检测服务器是否可达

#import "DeviceNetworkManager.h"
#import <AFNetworking/AFNetworking.h>
#import "User.h"

NSNotificationName const NetworkUsableDidChangeNotification = @"nNetworkUsableDidChangeNotification";
NSNotificationName const NetworkUsableItem = @"kNetworkUsableItem";

//用户不能使用网络
BOOL UsersCannotUseTheNetwork(AFNetworkReachabilityStatus status, BOOL isLoadOnWiFi)
{
    return (AFNetworkReachabilityStatusReachableViaWiFi != status
            && AFNetworkReachabilityStatusReachableViaWWAN != status)//没网
    || (isLoadOnWiFi && AFNetworkReachabilityStatusReachableViaWiFi != status);//不符合用户设置
}

@implementation DeviceNetworkManager
{
    ReachabilityResult _result;
    AFNetworkReachabilityManager *_nrm;
    NSURLSessionDataTask *_task;
    AFNetworkReachabilityStatus _lastStatus;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _nrm = [AFNetworkReachabilityManager sharedManager];
        _lastStatus = _nrm.networkReachabilityStatus;
    }
    return self;
}

static DeviceNetworkManager *sharedManager = nil;
static dispatch_once_t onceTokenManager;
+ (instancetype)sharedManager
{
    dispatch_once(&onceTokenManager, ^{
        sharedManager = [[self class] new];//此单例是为了监听网络状态
        [[NSNotificationCenter defaultCenter] addObserver:sharedManager selector:@selector(reachabilityStatusChanged:) name:AFNetworkingReachabilityDidChangeNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:sharedManager selector:@selector(loadOnWiFiSwitch) name:LoadOnWiFiSwitchNotification object:nil];
    });
    return sharedManager;
}

static AFHTTPSessionManager *_httpManager = nil;
static dispatch_once_t onceToken;
+ (void)initHttpManager
{
    dispatch_once(&onceToken, ^{
        _httpManager = [AFHTTPSessionManager manager];
        _httpManager.requestSerializer.timeoutInterval = 5;
        _httpManager.operationQueue.maxConcurrentOperationCount = 4;
    });
}

- (void)loadOnWiFiSwitch
{
    if (UsersCannotUseTheNetwork(_nrm.networkReachabilityStatus, User.currentUser.loadOnWiFi)) {//用户不能使用网络
        [[NSNotificationCenter defaultCenter] postNotificationName:NetworkUsableDidChangeNotification object:nil userInfo:@{NetworkUsableItem: @NO}];
    } else {
        [self deviceReachability:^(BOOL isReachable) {
            NSLog(@"%@", isReachable? @"可达": @"不可达");
            if (isReachable) {
                [[NSNotificationCenter defaultCenter] postNotificationName:NetworkUsableDidChangeNotification object:nil userInfo:@{NetworkUsableItem: @YES}];
            }
        }];
    }
}

- (void)reachabilityStatusChanged:(NSNotification *)noti
{
    AFNetworkReachabilityStatus status = [noti.userInfo[AFNetworkingReachabilityNotificationStatusItem] integerValue];
    if ((AFNetworkReachabilityStatusReachableViaWWAN == status || AFNetworkReachabilityStatusNotReachable == status) && AFNetworkReachabilityStatusReachableViaWiFi == _lastStatus) {//从WiFi变成4G网络或无网络
        
    } else if (UsersCannotUseTheNetwork(status, User.currentUser.loadOnWiFi)) {//用户设置了只在WiFi是上传或下载
        [[NSNotificationCenter defaultCenter] postNotificationName:NetworkUsableDidChangeNotification object:nil userInfo:@{NetworkUsableItem: @NO}];
    } else {
        [self deviceReachability:^(BOOL isReachable) {
            NSLog(@"%@", isReachable? @"可达": @"不可达");
            if (isReachable) {
                [[NSNotificationCenter defaultCenter] postNotificationName:NetworkUsableDidChangeNotification object:nil userInfo:@{NetworkUsableItem: @YES}];
            }
        }];
    }
    _lastStatus = status;
    return;
    
    if (UsersCannotUseTheNetwork([noti.userInfo[AFNetworkingReachabilityNotificationStatusItem] integerValue], User.currentUser.loadOnWiFi)) {//用户不能使用网络
        [[NSNotificationCenter defaultCenter] postNotificationName:NetworkUsableDidChangeNotification object:nil userInfo:@{NetworkUsableItem: @NO}];
    } else {
        __weak typeof(self) this = self;
        [self deviceReachability:^(BOOL isReachable) {
            if (isReachable) {
                [[NSNotificationCenter defaultCenter] postNotificationName:NetworkUsableDidChangeNotification object:nil userInfo:@{NetworkUsableItem: @YES}];
            }
        }];
    }
}

- (void)deviceReachability:(ReachabilityResult)result
{
    if (nil != _task) {
        [_task cancel];
    }
    
    if (_nrm.isReachable) {
        [DeviceNetworkManager initHttpManager];
        _result = [result copy];
        [self checkReachability];
    } else {
        if (result) result(NO);
        return;
    }
}

//有可能是公网IP
- (void)checkReachability
{
    NSString *url = @"http://www.qq.com";//检测是否连接到互联网的API，比如：你官网的URL
    
    __weak typeof(self) this = self;
    _task = [_httpManager POST:url parameters:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id _Nullable responseObject) {
        _result(YES)
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        _result(NO)
        if (self == sharedManager) [self logout];//是单例发起的请求就退出，其它的不退出
    }];
}

- (BOOL)cancel
{
    if (nil != _task || _task.state == NSURLSessionTaskStateRunning) {
        [_task cancel];
        _task = nil;
    }
    return NO;
}

- (void)logout
{
    //停止一切
    User.currentUser = nil;
    [[NSNotificationCenter defaultCenter] postNotificationName:UserLogoutNotification object:nil];//通知退出登录
    
    onceTokenManager = 0;
    sharedManager = nil;
}

@end
