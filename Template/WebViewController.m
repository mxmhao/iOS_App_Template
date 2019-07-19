//
//  WebViewController.m
//  iOS_App_Template
//
//  Created by mxm on 2018/3/5.
//  Copyright © 2018年 mxm. All rights reserved.
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

#pragma mark 当内容开始返回时调用
- (void)webView:(WKWebView *)webView didCommitNavigation:(null_unspecified WKNavigation *)navigation
{
    NSLog(@"");
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
