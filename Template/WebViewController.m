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
    NSString *src = nil;
    if (webView.URL.isFileURL) {
        //"file://xxxx.index" 本地文件url
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
