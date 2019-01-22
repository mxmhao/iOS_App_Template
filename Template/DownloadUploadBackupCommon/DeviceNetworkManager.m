//
//  DeviceNetworkManager.m

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
    NSURLSessionDataTask *_IPTask;
    NSURLSessionDataTask *_customTask;
    NSURLSessionDataTask *_serverOnlineTask;
    AFNetworkReachabilityStatus _lastStatus;
    BOOL _isLongTimeCheck;
    
    BOOL _networked;
    
    BOOL _IPCheckFinish;
    BOOL _userCustomCheckFinish;
    BOOL _serverOnlineCheckFinish;
    BOOL _userCustomReachable;
}

- (void)setNetworked:(BOOL)networked
{
    _networked = _networked || networked;
}

- (void)setIPCheckFinish:(BOOL)finish
{
    _IPCheckFinish = finish;
}

- (void)setUserCustomCheckFinish:(BOOL)finish
{
    _userCustomCheckFinish = finish;
}

- (void)setserveronlineCheckFinish:(BOOL)finish
{
    _serverOnlineCheckFinish = finish;
}

- (void)setUserCustomReachable:(BOOL)reachable
{
    _userCustomReachable = reachable;
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
        _isLongTimeCheck = NO;
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
        sharedManager->_isLongTimeCheck = YES;
    });
    return sharedManager;
}

static AFHTTPSessionManager *_httpManager = nil;
static dispatch_once_t onceToken;
+ (void)initHttpManager
{
    dispatch_once(&onceToken, ^{
        _httpManager = [[AFHTTPSessionManager alloc] initWithBaseURL:nil sessionConfiguration:[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"DeviceNetworkManager"]];
        _httpManager.requestSerializer.timeoutInterval = 5;
        _httpManager.operationQueue.maxConcurrentOperationCount = 4;
//        [_httpManager.requestSerializer setValue:DataBean.currentDevice.pwd forHTTPHeaderField:@"Authorization"];
    });
}

+ (void)setAuthorization:(NSString *)authorization
{
    [_httpManager.requestSerializer setValue:authorization forHTTPHeaderField:@"Authorization"];
}

- (void)loadOnWiFiSwitch
{
    if (UsersCannotUseTheNetwork(_nrm.networkReachabilityStatus, User.currentUser.loadOnWiFi)) {//用户不能使用网络
        [[NSNotificationCenter defaultCenter] postNotificationName:NetworkUsableDidChangeNotification object:nil userInfo:@{NetworkUsableItem: @NO}];
    } else {
        __weak typeof(self) this = self;
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
        [self logout];
//        baseURL = ([DataBean.currentDevice.url rangeOfString:@"."].length == 0 ? DataBean.currentDevice.channelUrl : DataBean.currentDevice.url);
//        [[NSNotificationCenter defaultCenter] postNotificationName:NetworkUsableDidChangeNotification object:nil userInfo:@{NetworkUsableItem: @NO}];
        //退出登录
    } else if (UsersCannotUseTheNetwork(status, User.currentUser.loadOnWiFi)) {//用户不能使用网络
        if (cjMusicPlayer.isPlaying) {
            CJMusicPlayModel *playModel = cjMusicPlayer.playModelList.firstObject;
            if (![playModel.url hasPrefix:@"/var"]) {//不是播放本地文件，就立刻停止
                [cjMusicPlayer stopPlay];
//                [cjMusicPlayer remoteControlPause];
                [cjMusicPlayer removeFromSuperview];
            }
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:NetworkUsableDidChangeNotification object:nil userInfo:@{NetworkUsableItem: @NO}];
    } else {
        if (cjMusicPlayer.isPlaying) {
            CJMusicPlayModel *playModel = cjMusicPlayer.playModelList.firstObject;
            if (![playModel.url hasPrefix:@"/var"]) {//不是播放本地文件，就立刻停止
                [cjMusicPlayer stopPlay];
//                [cjMusicPlayer remoteControlPause];
                [cjMusicPlayer removeFromSuperview];
            }
        }
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
    if (nil != _IPTask) {
        [_IPTask cancel];
    }
    if (nil != _customTask) {
        [_customTask cancel];
    }
    if (nil != _serverOnlineTask) {
        [_serverOnlineTask cancel];
    }
    
    if (_nrm.isReachable) {
        [DeviceNetworkManager initHttpManager];
        _result = [result copy];
        _networked = NO;
        //现在的并发处理
        _IPCheckFinish = NO;
        [self checkIPReachability];
        _userCustomCheckFinish = NO;
        _userCustomReachable = NO;
        [self checkUserCustomReachability];
        _serverOnlineCheckFinish = NO;
        [self checkserveronlineReachability];
    } else {
        if (result) result(NO);
        return;
    }
}

//有可能是公网IP
- (void)checkIPReachability
{
    if (_isLongTimeCheck) {
        _httpManager.requestSerializer.timeoutInterval = 30;
    } else {
        _httpManager.requestSerializer.timeoutInterval = 5;
    }
    NSInteger port = DataBean.currentDevice.port > 0? DataBean.currentDevice.port : DeviceDefaultPort;
    NSString *addr = [NSString stringWithFormat:@"%@:%ld", DataBean.currentDevice.ip, (long)port];
    if (nil == addr) {
        NSLog(@"IP出错");
        _networked = _networked || NO;
        _IPCheckFinish = NO;
        [self checkFinish:NO];
        return;
    }
    NSString *url = [RegisterIsConnected stringByReplacingOccurrencesOfString:@"[ip]:[port]" withString:addr];
    
    __weak typeof(self) this = self;
    _IPTask = [_httpManager POST:url parameters:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id _Nullable responseObject) {
        //有返回说明可达
        NSLog(@"%@", responseObject);
        
        BOOL successed = [responseObject[@"code"] boolValue];
        NSString *str = responseObject[@"data"];
        [this setNetworked:successed && ![@"---" isEqualToString:str]];
        [this setIPCheckFinish:YES];
        [this checkFinish:YES];
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        //服务器能够联通，但服务器不能转发到此设备，也会返回错误
        NSLog(@"%@", error.localizedDescription);
        if (error.code == NSURLErrorCancelled) return;//自己取消的，就不用往下调用了
        [this setNetworked:NO];
        [this setIPCheckFinish:YES];
        [this checkFinish:NO];
    }];
}

//有可能是公网域名
- (void)checkUserCustomReachability
{
    if (_isLongTimeCheck) {
        _httpManager.requestSerializer.timeoutInterval = 30;
    } else {
        _httpManager.requestSerializer.timeoutInterval = 5;
    }
    NSString *addr = ([DataBean.currentDevice.url rangeOfString:@"."].length == 0 ? nil : DataBean.currentDevice.url);
    if (nil == addr) {
        NSLog(@"url出错");
        _networked = _networked || NO;
        _userCustomCheckFinish = NO;
        _userCustomReachable = NO;
        [self checkFinish:NO];
        return;
    }
    NSString *url = [RegisterIsConnected stringByReplacingOccurrencesOfString:@"[ip]:[port]" withString:addr];
    
    __weak typeof(self) this = self;
    _customTask = [_httpManager POST:url parameters:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id _Nullable responseObject) {
        //有返回说明可达
        NSLog(@"%@", responseObject);
        
        BOOL successed = [responseObject[@"code"] boolValue];
        NSString *str = responseObject[@"data"];
        [this setNetworked:successed && ![@"---" isEqualToString:str]];
        [this setUserCustomReachable:YES];
        [this setUserCustomCheckFinish:YES];
        [this checkFinish:NO];
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        //服务器能够联通，但服务器不能转发到此设备，也会返回错误
        NSLog(@"%@", error.localizedDescription);
        if (error.code == NSURLErrorCancelled) return;//自己取消的，就不用往下调用了
        [this setNetworked:NO];
        [this setUserCustomReachable:NO];
        [this setUserCustomCheckFinish:YES];
        [this checkFinish:NO];
    }];
}

- (void)checkserveronlineReachability
{
    if (_isLongTimeCheck) {
        _httpManager.requestSerializer.timeoutInterval = 30;
    } else {
        _httpManager.requestSerializer.timeoutInterval = 15;
    }
//    NSString *addr = ([DataBean.currentDevice.url rangeOfString:@"."].length == 0 ? DataBean.currentDevice.channelUrl : DataBean.currentDevice.url);
    NSString *addr = DataBean.currentDevice.channelUrl;
    if (nil == addr) {
        NSLog(@"server online出错");
        _networked = _networked || NO;
        _serverOnlineCheckFinish = YES;
        [self checkFinish:NO];
        return;
    }
    NSString *url = [RegisterIsConnected stringByReplacingOccurrencesOfString:@"[ip]:[port]" withString:addr];
    
    __weak typeof(self) this = self;
    _serverOnlineTask = [_httpManager POST:url parameters:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id _Nullable responseObject) {
        //有返回说明可达
        NSLog(@"%@", responseObject);
        
        BOOL successed = [responseObject[@"code"] boolValue];
        NSString *str = responseObject[@"data"];
        [this setNetworked:successed && ![@"---" isEqualToString:str]];
        [this setserveronlineCheckFinish:YES];
        [this checkFinish:NO];
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        //服务器能够联通，但服务器不能转发到此设备，也会返回错误
        NSLog(@"%@", error.localizedDescription);
        if (error.code == NSURLErrorCancelled) return;//自己取消的，就不用往下调用了
        [this setNetworked:NO];
        [this setserveronlineCheckFinish:YES];
        [this checkFinish:NO];
    }];
}

- (void)checkFinish:(BOOL)localReachable
{
    if (!_IPCheckFinish || nil == _result) {//本地访问检测未完成
        return;
    } else if (localReachable) {//本地可达，直接完成回调
        DataBean.currentDevice.isLocal = YES;
        NSInteger port = DataBean.currentDevice.port > 0? DataBean.currentDevice.port : DeviceDefaultPort;
        baseURL = [NSString stringWithFormat:@"%@:%ld", DataBean.currentDevice.ip, port];
        if (_result) _result(_networked);
        _result = nil;
        return;
    }
    if (!_userCustomCheckFinish) return;
    if (_userCustomReachable) {//用户自定义可达，直接完成回调
        DataBean.currentDevice.isLocal = YES;
        baseURL = DataBean.currentDevice.url;
        if (_result) _result(_networked);
        _result = nil;
        return;
    }
    //IP检测和用户自定义检测都完成了
    //本地不可达
    if (!DataBean.currentDevice.isLocal) {//如果是本地设备，那就说明此设备是被搜索的到的，不用修改
        if (_networked) {
            baseURL = DataBean.currentDevice.channelUrl;
        } else {
            baseURL = ([DataBean.currentDevice.url rangeOfString:@"."].length == 0 ? DataBean.currentDevice.channelUrl : DataBean.currentDevice.url);
        }
    }
    if (_result) _result(_networked);
    _result = nil;
    if (!_networked) {
        if (self == sharedManager) [self logout];//是单例发起的请求就退出，其它的不退出
    }
}

- (BOOL)cancel
{
    if (nil != _IPTask || _IPTask.state == NSURLSessionTaskStateRunning) {
        [_IPTask cancel];
//        return YES;
    }
    if (nil != _customTask || _customTask.state == NSURLSessionTaskStateRunning) {
        [_customTask cancel];
//        return YES;
    }
    if (nil != _serverOnlineTask || _serverOnlineTask.state == NSURLSessionTaskStateRunning) {
        [_serverOnlineTask cancel];
        return YES;
    }
    return NO;
}

- (void)logout
{
    //停止一切
    User.currentUser = nil;
    [[NSNotificationCenter defaultCenter] postNotificationName:UserLogoutNotification object:nil];
    
    
    onceTokenManager = 0;
    sharedManager = nil;
}

@end
