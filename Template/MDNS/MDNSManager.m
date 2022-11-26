//
//  MDNSManager.m
//  AiHome
//
//  Created by macmini on 2022/5/10.
//

#import "MDNSManager.h"
#import <Network/Network.h>
#import "Const.h"

typedef void(^SwitchCompletionHandler)(int code, NSError * _Nullable error);

// MDNS有两种方式：NSNetServiceBrowser（已废弃），nw_browser_t
@interface MDNSManager (Delegate) <NSNetServiceBrowserDelegate>

@end

@implementation MDNSManager
{
    NSNetServiceBrowser *_netServiceBrowser;
    NSMutableArray<NSString *> *_findServices;
    NSMutableArray<NSString *> *_removeServices;
    NSMutableDictionary<NSString *, NSString *> *_ipDict;
    NSMutableDictionary<NSString *, NSNumber *> *_portDict;
    SwitchCompletionHandler _completionHandler;
    BOOL _isOn;
    dispatch_semaphore_t _lock;
}

+ (instancetype)shared
{
    static dispatch_once_t onceToken;
    static id instance;
    dispatch_once(&onceToken, ^{
        instance = [self new];
    });
    return instance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _netServiceBrowser = [NSNetServiceBrowser new];
        _netServiceBrowser.delegate = self;
        _lock = dispatch_semaphore_create(1);
        _findServices = [NSMutableArray arrayWithCapacity:10];
        _removeServices = [NSMutableArray arrayWithCapacity:10];
        _ipDict = [NSMutableDictionary dictionaryWithCapacity:10];
        _portDict = [NSMutableDictionary dictionaryWithCapacity:10];
    }
    return self;
}

- (NSString *)IPForDeviceId:(NSString *)deviceId
{
    return _ipDict[deviceId];
}

- (int)portForDeviceId:(NSString *)deviceId
{
    return [_portDict[deviceId] intValue];
}

static nw_browser_t nw_browser;
/*
 <Network/Network.h> 库，没有提供类似 NSNetService.hostName 的函数去拿到ip和port;
 nw_endpoint_get_bonjour_service_name 拿到的是 NSNetService.name；
 Network库，提供了函数，可通过UDP或TCP的方式，直接连接到扫描的到的 nw_endpoint_t；
 具体可查看官方文档或百度
 */
+ (void)searchForServices API_AVAILABLE(macos(10.15), ios(13.0), watchos(6.0), tvos(13.0))
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        nw_browse_descriptor_t nw_bd = nw_browse_descriptor_create_bonjour_service("_iotaithings._udp.", NULL);
        nw_browser = nw_browser_create(nw_bd, NULL);
    });
    nw_browser_set_state_changed_handler(nw_browser, ^(nw_browser_state_t state, nw_error_t  _Nullable error) {
        NSLog(@"nw_browser_state %d", state);
        switch (state) {
            case nw_browser_state_ready:
                NSLog(@"nw_browser_state_ready");
                break;
            case nw_browser_state_failed:
                NSLog(@"nw_browser_state_failed: %@", error);
                break;
            case nw_browser_state_cancelled:
                NSLog(@"nw_browser_state_cancelled");
                break;
            case nw_browser_state_waiting:
                NSLog(@"nw_browser_state_waiting");
                break;
            case nw_browser_state_invalid:
                NSLog(@"nw_browser_state_invalid");
                break;
        }
    });
    
    nw_browser_set_browse_results_changed_handler(nw_browser, ^(nw_browse_result_t  _Nonnull old_result, nw_browse_result_t  _Nonnull new_result, bool batch_complete) {
        NSLog(@"batch_complete %@", batch_complete ? @"YES" : @"NO");
        nw_browse_result_change_t browse_result_change = nw_browse_result_get_changes(old_result, new_result);
        switch (browse_result_change) {
            case nw_browse_result_change_invalid:
            case nw_browse_result_change_result_removed: {
                nw_endpoint_t endpoint = nw_browse_result_copy_endpoint(old_result);
                NSLog(@"移除了：%s", nw_endpoint_get_bonjour_service_name(endpoint));
            }
                break;
            case nw_browse_result_change_result_added: {
                nw_endpoint_t endpoint = nw_browse_result_copy_endpoint(new_result);
                NSLog(@"新增了：name: %s", nw_endpoint_get_bonjour_service_name(endpoint));
                nw_endpoint_type_t type = nw_endpoint_get_type(endpoint);
                switch (type) {
                        // 这几个是测试，其实拿不到真正的ip和port
                    case nw_endpoint_type_address: {
                        NSLog(@"nw_endpoint_type_t：nw_endpoint_type_address");
                        char *ip = nw_endpoint_copy_address_string(endpoint);
                        NSLog(@"新增了：addr: %s", ip);
                        free(ip);
                        NSLog(@"新增了：port: %hu", nw_endpoint_get_port(endpoint));
                    }
                        break;
                    case nw_endpoint_type_host: {
                        NSLog(@"nw_endpoint_type_t：nw_endpoint_type_host");
                        const char *hostname = nw_endpoint_get_hostname(endpoint);
                        NSLog(@"新增了：hostname: %s", hostname);
                        NSLog(@"新增了：port: %hu", nw_endpoint_get_port(endpoint));
                    }
                        break;
                    case nw_endpoint_type_bonjour_service:
                        NSLog(@"nw_endpoint_type_t：nw_endpoint_type_bonjour_service"); {
                            nw_connection_t connection = nw_connection_create(endpoint, nw_parameters_create_secure_udp(NW_PARAMETERS_DISABLE_PROTOCOL, NW_PARAMETERS_DEFAULT_CONFIGURATION));
                            nw_connection_set_state_changed_handler(connection, ^(nw_connection_state_t state, nw_error_t  _Nullable error) {
                                NSLog(@"nw_connection_set_state_changed_handler %d -- %@", state, error);
                                
                            });
                            nw_connection_set_viability_changed_handler(connection, ^(bool value) {
                                NSLog(@"nw_connection_set_viability_changed_handler %d", value);
                            });
                            
                            nw_connection_set_queue(connection, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
                            nw_connection_start(connection);
//                            nw_endpoint_handler_set_adaptive_read_handler();
                        }
                        
                        break;
                    case nw_endpoint_type_url:
                        NSLog(@"nw_endpoint_type_t：nw_endpoint_type_url");
                        break;
                    case nw_endpoint_type_invalid:
                        NSLog(@"nw_endpoint_type_t：nw_endpoint_type_invalid");
                        break;
                }
            }
                break;
        }
    });
    nw_browser_set_queue(nw_browser, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
    nw_browser_start(nw_browser);
}

+ (void)stopSearchForServices API_AVAILABLE(macos(10.15), ios(13.0), watchos(6.0), tvos(13.0))
{
    if (NULL == nw_browser) return;
    nw_browser_cancel(nw_browser);
}

- (void)switchMDNS:(BOOL)onOrOff completionHandler:(void (^)(int code, NSError * _Nullable error))completionHandler;
{
    if (_isOn == onOrOff) return;
    
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    _isOn = onOrOff;
    _completionHandler = [completionHandler copy];
    if (_isOn) {
        // type 是有固定格式的，_iot 是自定义名，_udp是协议名称，可以百度。
        [_netServiceBrowser searchForServicesOfType:@"_iot._udp." inDomain:@""];
//        [MDNSManager searchForServices];
    } else {
        [_netServiceBrowser stop];
    }
    dispatch_semaphore_signal(_lock);
}

#pragma mark - NSNetServiceBrowserDelegate
- (void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)browser
{
    BOOL isOn = _isOn;
    _isOn = YES;
    SwitchCompletionHandler hander = _completionHandler;
    _completionHandler = nil;
    if (isOn && hander) {
        hander(0, nil);
    }
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didNotSearch:(NSDictionary<NSString *, NSNumber *> *)errorDict
{
    BOOL isOn = _isOn;
    _isOn = NO;
    SwitchCompletionHandler hander = _completionHandler;
    _completionHandler = nil;
    if (isOn && hander) {
        hander(10001, nil);//启用mDNS失败
    }
}

- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)browser
{
    BOOL isOn = _isOn;
    _isOn = NO;
    SwitchCompletionHandler hander = _completionHandler;
    _completionHandler = nil;
    if (!isOn && hander) {
        hander(0, nil);
    }
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didFindDomain:(NSString *)domainString moreComing:(BOOL)moreComing
{
    
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didFindService:(NSNetService *)service moreComing:(BOOL)moreComing
{
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    [_findServices addObject:service.name];
    dispatch_semaphore_signal(_lock);
    if (moreComing) return;
    
    // 解析服务，解析后才能拿到 service.hostName ; service.port
//    service.delegate = self;
//    [service resolveWithTimeout:2]; //解析成功会有回调方法 - (void)netServiceDidResolveAddress:(NSNetService *)sender;
    // 这里和嵌入式定的协议是在 name 中包含了 ip和port，所以不用解析了
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    NSArray *arr;
    for (NSString *name in _findServices) {
        arr = [name componentsSeparatedByString:@"_"];
        if (!arr || arr.count < 4) continue;
        if (IsEmptyString(arr[1])) continue;
        if (IsEmptyString(arr[2])) continue;
        if (IsEmptyString(arr[3])) continue;
        
        _ipDict[arr[1]] = arr[2];
        _portDict[arr[1]] = @([arr[3] intValue]);
    }
    [_findServices removeAllObjects];
    dispatch_semaphore_signal(_lock);
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didRemoveDomain:(NSString *)domainString moreComing:(BOOL)moreComing
{
    
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didRemoveService:(NSNetService *)service moreComing:(BOOL)moreComing
{
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    // 先集中，后删除。
    [_removeServices addObject:service.name];
    dispatch_semaphore_signal(_lock);
    if (moreComing) return;
    
    
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    NSArray *arr;
    for (NSString *name in _removeServices) {
        arr = [name componentsSeparatedByString:@"_"];
        if (!arr || arr.count < 4) continue;
        
        [_ipDict removeObjectForKey:arr[1]];
        [_portDict removeObjectForKey:arr[1]];
    }
    [_removeServices removeAllObjects];
    dispatch_semaphore_signal(_lock);
}

@end
