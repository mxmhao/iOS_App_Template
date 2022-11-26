//
//  WebViewController.m
//  
//
//  Created by mxm on 2018/8/13.
//  Copyright © 2018年 mxm. All rights reserved.
//
//  https://cloud.tencent.com/developer/article/1861389
//  https://cloud.tencent.com/developer/article/1464845
//  Cordova的第三方插件库：
//  https://capacitorjs.com/docs/apis
//  https://ionicframework.com/docs/native
//
//window.webkit.messageHandlers.showName.postMessage('有一个参数')
//window.webkit.messageHandlers.showSendMsg.postMessage(['两个参数One', '两个参数Two'])

#import <WebKit/WebKit.h>
#import "URLSchemeHandler.h"
//#import <UIKit/UIKit.h>

//window.webkit.messageHandlers.nativeBack.postMessage(null)//空参数
static NSString *const JsCallNativeFuncBack = @"nativeBack";
static NSString *const JsCallNativeFuncLogout = @"nativeLogout";

@interface WebViewController: UIViewController <WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate>
{
    WKWebView *_webView;
    NSURLRequest *_request;
    WKNavigation *_wkNav;
}

@end

@interface NSObject (WKBackForwardList)
- (void)_removeAllItems;
@end
@implementation NSObject (WKBackForwardList)
- (void)_removeAllItems {}
@end

@implementation WebViewController

- (void)dealloc
{
    NSLog(@"%@ -- 释放", [self class]);
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

static NSString *const USERAGENT = @"my app";
- (instancetype)initWithRequest:(NSURLRequest *)request
{
    self = [super init];
    if (self) {
        _request = request;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // 设置偏好设置
    WKWebViewConfiguration *config = [WKWebViewConfiguration new];
    // 默认为0
    config.preferences.minimumFontSize = 14;
    //是否支持JavaScript
    config.preferences.javaScriptEnabled = YES;
    //js是否可以打开窗口
    config.preferences.javaScriptCanOpenWindowsAutomatically = YES;
    
    // 这里添加 URLSchemeHandler 是为了能自动注入cordova.js
    URLSchemeHandler *urlSchemeHandler = [[URLSchemeHandler alloc] init];
    [config setURLSchemeHandler:urlSchemeHandler forURLScheme:@"app"];
    
    //ios11之前组装cookie
    NSString *cookieValue = [NSString stringWithFormat:@"document.cookie='session=%@';document.cookie='user=%@';", @"sessionid", @"user"];//path=/';
    NSLog(@"%@", cookieValue);
    WKUserScript * cookieScript = [[WKUserScript alloc]
        initWithSource: cookieValue
        injectionTime:WKUserScriptInjectionTimeAtDocumentStart
        forMainFrameOnly:NO];
    
    WKUserContentController *ucc = config.userContentController;
    //注入cookie
    [ucc addUserScript:cookieScript];
    //JS调用OC 添加处理脚本
    [ucc addScriptMessageHandler:self name:JsCallNativeFuncBack];
    [ucc addScriptMessageHandler:self name:JsCallNativeFuncLogout];
    
    CGRect frame = self.view.bounds;
//    if (@available(iOS 11.0, *)) {
//        frame.origin.y = self.additionalSafeAreaInsets.top;
//        frame.size.height -= frame.origin.y;
//    } else {
//        frame.origin.y = 20;
//        frame.size.height -= frame.origin.y;
//    }
    _webView = [[WKWebView alloc] initWithFrame:frame configuration:config];
    _webView.customUserAgent = USERAGENT;
    _webView.UIDelegate = self;
    _webView.navigationDelegate = self;
    if (@available(iOS 11.0, *)) {
//        _webView.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    } else {
//        self.automaticallyAdjustsScrollViewInsets = NO;
    }
    [self.view addSubview:_webView];
    
    //组装cookie
    if (@available(iOS 11.0, *)) {
        WKHTTPCookieStore *cookieStore = _webView.configuration.websiteDataStore.httpCookieStore;
        NSHTTPCookie *cookie = [NSHTTPCookie cookieWithProperties:@{
            NSHTTPCookieDomain:_request.URL.host,
            NSHTTPCookieName:@"session",
            NSHTTPCookieValue:@"",
            NSHTTPCookiePath:@"/",
            NSHTTPCookieSecure:[NSNumber numberWithBool:YES]
        }];
        [cookieStore setCookie:cookie completionHandler:nil];
        
        NSHTTPCookie *cookie2 = [NSHTTPCookie cookieWithProperties:@{
            NSHTTPCookieDomain:_request.URL.host,
            NSHTTPCookieName:@"user",
            NSHTTPCookieValue:@"user",
            NSHTTPCookiePath:@"/",
            NSHTTPCookieSecure:[NSNumber numberWithBool:YES]
        }];
        [cookieStore setCookie:cookie2 completionHandler:nil];
    } else {
        // Fallback on earlier versions
    }
    
    _wkNav = [_webView loadRequest:_request];
}

- (void)showErrorAlert
{
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"出错, 请重新尝试" message:nil preferredStyle:UIAlertControllerStyleAlert];
    __weak typeof(self) this = self;
    [ac addAction:[UIAlertAction actionWithTitle:@"I get it" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [this removeAllScriptMessageHandler];//防止内存泄露
        [this dismissViewControllerAnimated:YES completion:nil];
    }]];
    [self presentViewController:ac animated:YES completion:nil];
}

- (void)removeAllScriptMessageHandler
{
    WKUserContentController *ucc = _webView.configuration.userContentController;
    [ucc removeScriptMessageHandlerForName:JsCallNativeFuncBack];
    [ucc removeScriptMessageHandlerForName:JsCallNativeFuncLogout];
}

- (void)showDownloadAlert:(NSString *)name fileUrl:(NSURL *)url
{
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"download" message:name preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"cancel" style:UIAlertActionStyleCancel handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:@"confirm" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [UIApplication.sharedApplication openURL:url options:nil completionHandler:nil];
    }]];
    [self presentViewController:ac animated:YES completion:nil];
}

- (void)reloadUrl:(NSString *)path params:(NSString *)params clearHistory:(BOOL)clear
{
    if (nil == path || (id)kCFNull == path || [@"" isEqualToString:path]) {
        path = @"你的首页地址url";
        if (params) {
            path = [path stringByAppendingString:params];
        }
//        path = [path stringByReplacingOccurrencesOfString:@"?" withString:@"#/?"];
        [_webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:path] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:20.0]];
//        NSNumber *clearHistory = args[kLoadUrlClearHistory];//clearHistory
        // 默认清理历史记录
        if (clear) {
            // 这里不能放入延迟清理，否则，进入控制页再退出控制页，然后进到其他页面，就无法返回了。这是个严重的bug。
            [self clearHistory:_webView];
//            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//            });
        }
        return;
    }

//    NSRange range = [path rangeOfString:@"?"];
    //这两个是为了防止自动被添加上的#转成%23
    if (![path containsString:@"#/?"]) {
        path = [path stringByReplacingOccurrencesOfString:@"?" withString:@"#/?"];
    }
    NSURL *url = nil;
    if ([path hasPrefix:@"http"]) {
        url = [NSURL URLWithString:path];
    } else {
        url = [NSURL URLWithString:[@"file://" stringByAppendingString:path]];
    }
    
//    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pageDidLoad:) name:CDVPageDidLoadNotification object:nil];
    [_webView loadRequest:[NSURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:20.0]];
    // 默认清理历史记录
    if (clear) {
        // 这里不能放入延迟清理，否则，进入控制页再退出控制页，然后进到其他页面，就无法返回了。这是个严重的bug。
        [self clearHistory:_webView];
//        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        });
    }
}

- (void)clearHistory:(WKWebView *)view
{
    // 方式一：由于Apple公司加强了源码安全分析，此方法在xcode14以后可能无法提交到appstore
//#pragma clang diagnostic push
//#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
//    [((WKWebView *)view).backForwardList performSelector:NSSelectorFromString(@"_removeAllItems")];
//#pragma clang diagnostic pop
    // 这里用了点小技巧，给 backForwardList 的父类通过分类的方式添加了_removeAllItems方法，就能通过多态的方式调到私有方法。
    [view.backForwardList _removeAllItems];
}

// 本地webview缓存大小
+ (unsigned long long)cacheSize
{
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"WebKit"];//NetworkCache最大
    NSFileManager *fm = NSFileManager.defaultManager;
    NSDirectoryEnumerator *de = [fm enumeratorAtPath:path];
    unsigned long long size = 0;
    for (NSString *subpath in de) {
//        NSLog(@"%@", subpath);
        size += [fm attributesOfItemAtPath:[path stringByAppendingPathComponent:subpath] error:NULL].fileSize;
    }
    return size;
}

// 清理本地缓存
+ (void)clearCache
{
    NSSet *websiteDataTypes;
    if (@available(iOS 11.3, *)) {
        websiteDataTypes = [NSSet setWithArray:@[
            WKWebsiteDataTypeFetchCache,
            WKWebsiteDataTypeDiskCache,
            //WKWebsiteDataTypeOfflineWebApplicationCache,
            WKWebsiteDataTypeMemoryCache,
            //WKWebsiteDataTypeLocalStorage,
            //WKWebsiteDataTypeCookies,
            //WKWebsiteDataTypeSessionStorage,
            //WKWebsiteDataTypeIndexedDBDatabases,
            //WKWebsiteDataTypeWebSQLDatabases,
            //WKWebsiteDataTypeServiceWorkerRegistrations
        ]];
    } else {
        websiteDataTypes = [NSSet setWithArray:@[
//            WKWebsiteDataTypeFetchCache,
            WKWebsiteDataTypeDiskCache,
            //WKWebsiteDataTypeOfflineWebApplicationCache,
            WKWebsiteDataTypeMemoryCache,
            //WKWebsiteDataTypeLocalStorage,
            //WKWebsiteDataTypeCookies,
            //WKWebsiteDataTypeSessionStorage,
            //WKWebsiteDataTypeIndexedDBDatabases,
            //WKWebsiteDataTypeWebSQLDatabases,
            //WKWebsiteDataTypeServiceWorkerRegistrations
        ]];
    }
    // All kinds of data
    //NSSet *websiteDataTypes = [WKWebsiteDataStore allWebsiteDataTypes];
    // Date from
    NSDate *dateFrom = [NSDate dateWithTimeIntervalSince1970:0];
    [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:websiteDataTypes modifiedSince:dateFrom completionHandler:^{
    }];
}

#pragma mark - WKScriptMessageHandler
//js调用原生方法
- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message
{
    if ([message.name isEqualToString:JsCallNativeFuncBack]) {//主页
        [self removeAllScriptMessageHandler];//防止内存泄露
        [self dismissViewControllerAnimated:YES completion:nil];
    } else if ([message.name isEqualToString:JsCallNativeFuncLogout]) {
        [self dismissViewControllerAnimated:NO completion:nil];
        //退出登录
    }
}

#pragma mark - WKNavigationDelegate 页面加载
//- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
//{
//    NSLog(@"%ld", (long)navigationAction.navigationType);
//    WKNavigationActionPolicy(WKNavigationActionPolicyAllow);
//}

#pragma mark 在收到响应后，决定是否跳转
- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler
{
    NSLog(@"%@", navigationResponse.response.MIMEType);
    //判断要下载的类型
    if ([navigationResponse.response.MIMEType isEqualToString: @"application/macbinary"]
        && [navigationResponse.response.suggestedFilename.pathExtension isEqualToString:@"apk"]) {
        decisionHandler(WKNavigationResponsePolicyCancel);
        [self showDownloadAlert:navigationResponse.response.suggestedFilename fileUrl:navigationResponse.response.URL];
        return;
    }
    
    decisionHandler (WKNavigationResponsePolicyAllow);
    if (((NSHTTPURLResponse *)navigationResponse.response).statusCode == 200) {
    } else {
        [self showErrorAlert];
//        decisionHandler(WKNavigationResponsePolicyCancel);
    }
    
//    if (((NSHTTPURLResponse *)navigationResponse.response).statusCode == 404) {
//        [self dismissViewControllerAnimated:YES completion:nil];
//    }
}

- (void)webView:(WKWebView *)webView didFailNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error
{
    NSLog(@"%@", error);
}

#pragma mark 页面开始加载时调用
- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(null_unspecified WKNavigation *)navigation
{
    NSLog(@"");
}

#pragma mark 当内容开始返回时调用，cordova类似的混合开发框架可以在这里注入指定js文件
- (void)webView:(WKWebView *)webView didCommitNavigation:(null_unspecified WKNavigation *)navigation
{
    NSLog(@"");
    /**
     在一个JavaScript文件或一个JavaScript代码块的内部，浏览器会先对代码进行预处理（编译），然后再执行。
     预处理会跳过执行语句，只处理声明语句，同样也是按从上到下按顺序进行的。包括变量和函数在内的所有声明都会在任何代码被执行前首先被处理。 即使声明是在调用的下方进行的，但浏览器仍然先声明再调用（执行），这个现象叫做“提升”。所以，即便一个函数的声明在下方，在前面仍然可以正常执行这个函数。
     注意1：对于声明并赋值的语句，例如 var a = 1，在预处理阶段会把这句话拆成两句：
     var a;
     a = 1;
     也就是说，赋值或其他逻辑运算是在执行阶段进行的，在预处理阶段会被忽略。

     注意2：（1）函数声明的提升优先于变量声明的提升；（2）重复的var声明会被忽略掉，但是重复的function声明会覆盖掉前面的声明。

     在预处理阶段，声明的变量的初始值是undefined, 采用function声明的函数的初始内容就是函数体的内容.
     */
    // 方式一：
    NSString *src = nil;
    if (webView.URL.isFileURL) {
        // allowingReadAccessToURL 指定了本地允许访问的根目录，如果本地访问的文件不在此目录，就被称为跨域访问。跨域访问请考虑下面的方式二
//        webView loadFileURL:<#(nonnull NSURL *)#> allowingReadAccessToURL:<#(nonnull NSURL *)#>
        //"file://xxxx.index" 本地文件url，此方式在跨域时会加载失败。
        src = [@"file:///" stringByAppendingString:[NSBundle.mainBundle pathForResource:@"www/cordova.js" ofType:nil]];
    } else {
        //远程url，注入"file://"方式无效，只能起一个本地服务。GCDWebServer本地服务库是一个不错的选择。
//        @autoreleasepool {
//            _webServer = [GCDWebServer new];
//            [_webServer addGETHandlerForBasePath:@"/" directoryPath:[NSBundle.mainBundle pathForResource:@"www" ofType:nil] indexFilename:nil cacheAge:1 allowRangeRequests:NO];
//            [_webServer startWithPort:9090 bonjourName:nil];
//        }
        src = @"http://localhost:9090/cordova.js";
    }
    NSString *script =
        @"var sc = document.createElement('script');\n"
        @"sc.src = '%@';\n"
        @"sc.type = 'text/javascript';\n"
        @"document.head.appendChild(sc);";
    [webView evaluateJavaScript:[NSString stringWithFormat:script, src] completionHandler:nil];
    
    // 方式二：--------------------------------------------------------------
    /*
     这种方式最高效，且跨域也能加载，前提是 WKWebViewConfiguration 设置了 URLSchemeHandler
     WKWebViewConfiguration *config = [WKWebViewConfiguration new];
     
     // 这里添加 URLSchemeHandler 是为了能自动注入cordova.js
     URLSchemeHandler *urlSchemeHandler = [[URLSchemeHandler alloc] init];
     [config setURLSchemeHandler:urlSchemeHandler forURLScheme:@"app"];
    */
//    NSString *file = [NSBundle.mainBundle pathForResource:@"www/cordova.js" ofType:nil];
    /*
     这里的写法要配合 URLSchemeHandler 中协议方法的写法
     "app://" 是固定的，[config setURLSchemeHandler: forURLScheme:] 指定了，在 URLSchemeHandler 的协议方法中[webView: startURLSchemeTask:] 也做了匹配。
     "local" 作为 host 在 URLSchemeHandler 的协议方法中[webView: startURLSchemeTask:] 未匹配，可以随便写
     "_app_file_" 作为 path 在 URLSchemeHandler 的协议方法中[webView: startURLSchemeTask:] 做了匹配，表示本地文件
     */
//    NSString *script =
//        @"var sc = document.createElement('script');\n"
//        @"sc.src = 'app://local/_app_file_%@';\n"
//        @"sc.type = 'text/javascript';\n"
//        @"document.head.appendChild(sc);";
//    [webView evaluateJavaScript:[NSString stringWithFormat:script, file] completionHandler:nil];
}

#pragma mark 页面加载完成之后调用
- (void)webView:(WKWebView *)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation
{
    NSLog(@"%@", webView.title);
}

#pragma mark 页面加载失败时调用
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error
{
    NSLog(@"%@", error);
}

@end
