# iOS_App_Template
[国内链接gitee](https://gitee.com/maoxm/iOS_App_Template)  
iOS工具类和模板代码，简单高效

## [工具类在“/Utils/”目录下，一般可以直接使用](/Utils)
1. [线程锁：XMLock.h](/Utils/XMLock.h)
2. [常量，常用判断，MIME类型获取，调试日志：Const.h](/Utils/Const.h)
3. [国际化，本地化：LocalizedManager/](/Utils/LocalizedManager)
4. [NSInputStream添加跳过（skip）方法：NSInputStream+Skip/](/Utils/NSInputStreamSkip)  
5. [工具类，计算文件MD5、创建图片缩略图、获取文件夹大小、获取可用存储空间大小、AES加解密：Utils.m](/Utils/Utils.m)  
6. [随app启动自动运行一些代码，不需要开发者主动调用，适用于一些第三库自动运行](/Utils/_XMAutoLaunch.m)  
7. [限制 UITextField 输入](/Utils/InputLimiter)  
8. [获取视频文件的第一帧，远程或本地视频都可](/Utils/Utils.m#L390)  
9. [禁止音乐远程控制](/Utils/Utils.m#L428)  
10. [用最简单的方式自定义一个Toast](/Utils/Toast.m)  


## [模板类在“/Template/”目录下，一般无法直接使用，主要用来参考里面的逻辑，或者直接修改模板代码](/Template)
1. [后台备份，相册备份：Backup/](/Template/Backup)
2. [后台下载：Download/](/Template/Download)
3. [后台上传：Upload/](/Template/Upload)  
        [上传下载备份中用到的：DownloadUploadBackupCommon/](/Template/DownloadUploadBackupCommon)
4. [屏幕旋转控制：ShouldNotAutorotate/](/Template/ShouldNotAutorotate)
5. [IP地址获取，当前Wi-Fi获取，连接Wi-Fi，监听WiFi切换：IPAddr.m](/Template/IPAddr.m)
6. [UITableViewCell侧滑删除，长按事件：TableViewTemplate.m](/Template/TableViewTemplate.m)
7. [UITableViewCell高度自适应：TableViewCellAutoCalculate.m](/Template/TableViewCellAutoCalculate.m)
8. [WKWebView简单使用：WebViewController.m](/Template/WebViewController.m)
9. [身份验证，生物识别：LocalAuthentication.m](/Template/LocalAuthentication.m)
10. [分享（社会化）：Share.m](/Template/Share.m)  
11. [蓝牙BLE：BLE/](/Template/BLE)  
12. [Swift坑爹的 ViewController的init指定构造器：Test2ViewController.swift](/Template/Test2ViewController.swift)  
13. [系统日历事件和提醒：EventKitTemplate.m](/Template/EventKitTemplate.m)  
14. [制作一个和启动页一模一样的页面，动态替换启动页：LaunchViewController.m](/Template/LaunchViewController.m)  
15. [纯代码实现iOS原生扫描，图片二维码识别：ScanViewController.m](/Template/ScanViewController.m)  
16. [文字转语音：SpeechUtils.m](/Template/SpeechUtils.m)  
17. [shell自动打包脚本：iOS_App_Template-archive.sh](/iOS_App_Template-archive.sh)  
18. [mDNS服务](/Template/MDNS)  
19. [一次性 GCD timer](/Template/TemplateUtils.m#L36)  
20. [复制到剪切板](/Template/TemplateUtils.m#L52)  
21. [使用iOS原生类请求 HTTP JSON，不依赖第三方库](/Template/TemplateUtils.m#L61)  
22. [从AppStore获取版App最新本号](/Template/TemplateUtils.m#L75)  
23. [使用UIDocumentPickerViewController获取手机本地（File app）文件](/Template/SelectFileViewController.m)  
24. [使用 NSURLSession.sharedSession 下载文件并获取进度，免得自己创建 NSURLSession  来设置 NSURLSessionDownloadDelegate 去获取进度](/Template/TemplateUtils.m#L111)  
25. [UITextField 添加 leftView 文字 并且为 leftView 留空白](/Template/TemplateUtils.m#L147)  
26. [设置 UIButton 图片和文字之间的间隔](/Template/TemplateUtils.m#L168)  
27. [用最简单的方式仿 UIAlertController 弹框](/Template/AlertViewController.m#L23)  
28. [移动 UITextField 的光标位置](/Template/TemplateUtils.m#L211)  
29. [组件化服务自动注册，与分阶段启动](/Template/ServiceRegister.m)  
30. [给 storyboard 或者 xib 添加国际化key填空，而不是将 storyboard 或者 xib 直接国际化，方便国际化 Localizable.strings 文件的统一管理](/Template/SwiftTemplate.swift#L11)  


## 长见识（自己去搜，去了解，去使用）
1. 音频控制、锁屏显示： MPRemoteCommandCenter、MPNowPlayingInfoCenter  
2. 音视频播放：AVFoundation； 音视频下载缓存：AVAssetDownloadURLSession  
3. HTTP上传文件的断点续传协议可参考（苹果公司为其NSURLSession上传文件定制的）：https://datatracker.ietf.org/doc/draft-ietf-httpbis-resumable-upload/  
4. 苹果系统有自己的[Swift响应式框架(闭源的)](https://developer.apple.com/documentation/combine/)，貌似性能比开源RX的好很多
