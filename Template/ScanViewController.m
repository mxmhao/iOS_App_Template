//
//  ScanViewController.m
//  iOS_App_Template
//
//  Created by mxm on 2021/9/12.
//  Copyright © 2021 mxm. All rights reserved.
//
//  参考的 https://github.com/xiesha/SHCustomQRCoden 感谢作者

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

typedef void(^ScanCallback)(NSString *_Nullable decodeString);

//颜色(默认支付宝蓝)
#define STYLECOLOR [UIColor colorWithRed:57/255.f green:187/255.f blue:255/255.f alpha:1.0]

@interface ScanViewController : UIViewController <AVCaptureMetadataOutputObjectsDelegate, AVCaptureVideoDataOutputSampleBufferDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate>

@end

@implementation ScanViewController
{
    CAGradientLayer             *_gradientLayer;
    CGRect                      _scanRect;
    
    AVCaptureDevice             *_device;
    AVCaptureDeviceInput        *_input;
    AVCaptureMetadataOutput     *_output;
    AVCaptureVideoDataOutput    *_videoOutput;
    AVCaptureSession            *_session;
    AVCaptureVideoPreviewLayer  *_previewlayer;
    UIButton                    *_btnLight;//开灯按钮
    UIButton                    *_btnBack;//取消按钮
    UIButton                    *_btnAlbum;//相册按钮
    UILabel                     *_labDesc;//扫描框下提示
    UILabel                     *_labTitle;//顶部标题
    
    ScanCallback                _completion;
    ScanCallback                _cancel;
}

//权限判断
+ (BOOL)hasAuth
{
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera] ||
        authStatus == AVAuthorizationStatusRestricted ||
        authStatus == AVAuthorizationStatusDenied) {//判断相机
        return NO;
    }
    return YES;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self initCamera];
    [self initScanLayer];
    [self initBtn];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [_session startRunning];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [_session stopRunning];
}

- (void)initCamera
{
    _device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    _input = [AVCaptureDeviceInput deviceInputWithDevice:_device error:nil];
    
    _output = [AVCaptureMetadataOutput new];
    [_output setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
//        [_output setRectOfInterest:CGRectMake((frame.size.height - 220)*0.5/UIScreen.mainScreen.bounds.size.height, (frame.size.width - 220)*0.5/UIScreen.mainScreen.bounds.size.width, 220/UIScreen.mainScreen.bounds.size.height, 220/UIScreen.mainScreen.bounds.size.width)];
    
    _videoOutput = [AVCaptureVideoDataOutput new];//根据亮度判断是否显示开灯按钮
    [_videoOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    
    _session = [AVCaptureSession new];
    [_session setSessionPreset:AVCaptureSessionPresetHigh];
    if ([_session canAddInput:_input]) {
        [_session addInput:_input];
    }
    if ([_session canAddOutput:_output]) {
        [_session addOutput:_output];
    }
    if ([_session canAddOutput:_videoOutput]) {
        [_session addOutput:_videoOutput];
    }
    _output.metadataObjectTypes = @[AVMetadataObjectTypeQRCode];
    _previewlayer = [AVCaptureVideoPreviewLayer layerWithSession:_session];
    _previewlayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    _previewlayer.frame = self.view.layer.bounds;
    [self.view.layer insertSublayer:_previewlayer atIndex:0];
//    [_session startRunning];
}

//懵层
- (void)initScanLayer
{
    CGRect bounds = self.view.bounds;
    CGFloat height, width = height = 260;
    CGFloat x = (CGRectGetWidth(bounds) - width) * 0.5;
    CGFloat y = (CGRectGetHeight(bounds) - height) * 0.5 - 60;//-60是为了偏上一点点
    //镂空 的矩形
    CGRect qrRect = CGRectMake(x, y, width, height);
    _scanRect = qrRect;
    
    ///top 与 left 互换  width 与 height 互换
    _output.rectOfInterest = CGRectMake(y/CGRectGetHeight(bounds), x/CGRectGetWidth(bounds), height/CGRectGetHeight(bounds), width/CGRectGetWidth(bounds));
    
    //方式一：
    // 创建一个绘制路径
    CGMutablePathRef mPath = CGPathCreateMutable();
    // 绘制 添加背景
    CGPathAddRect(mPath, nil, bounds);
    // 添加 镂空矩形
    CGPathAddRect(mPath, nil, qrRect);
    
    //方式二：
//        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:mPath cornerRadius:0];
//        UIBezierPath *qrRectPath = [UIBezierPath bezierPathWithRect:qrRect];
//        [path appendPath:qrRectPath];
//        [path setUsesEvenOddFillRule:YES];
    
    CAShapeLayer *fillLayer = [CAShapeLayer layer];
//        fillLayer.path = path.CGPath;
    fillLayer.path = mPath;
    fillLayer.fillRule = kCAFillRuleEvenOdd;//奇偶校验，可以镂空
    fillLayer.fillColor = [UIColor colorWithRed:0/255.0 green:0/255.0 blue:0/255.0 alpha:.6].CGColor;
    [self.view.layer addSublayer:fillLayer];
    
    UIColor *color = STYLECOLOR;
    //白色矩形
    UIBezierPath *bezierPath = [UIBezierPath bezierPathWithRect:qrRect];
    CAShapeLayer *shapeLayer = [CAShapeLayer layer];
    shapeLayer.backgroundColor = UIColor.clearColor.CGColor;
    shapeLayer.path = bezierPath.CGPath;
    shapeLayer.lineWidth = 0.5;
//    shapeLayer.strokeColor = UIColor.whiteColor.CGColor;
    shapeLayer.strokeColor = color.CGColor;
    shapeLayer.fillColor = UIColor.clearColor.CGColor;
    [self.view.layer addSublayer:shapeLayer];
    
    CGFloat lineLength = 26;
    //四个角落
    UIBezierPath *cornerBezierPath = [UIBezierPath bezierPath];
    
    [cornerBezierPath moveToPoint:CGPointMake(x, y+lineLength)];//左上角
    [cornerBezierPath addLineToPoint:CGPointMake(x, y)];
    [cornerBezierPath addLineToPoint:CGPointMake(x+lineLength, y)];
    
    [cornerBezierPath moveToPoint:CGPointMake(x+height-lineLength, y)];//右上角
    [cornerBezierPath addLineToPoint:CGPointMake(x+height, y)];
    [cornerBezierPath addLineToPoint:CGPointMake(x+height, y+lineLength)];
    
    [cornerBezierPath moveToPoint:CGPointMake(x+height, y+height-lineLength)];//右下角
    [cornerBezierPath addLineToPoint:CGPointMake(x+height, y+height)];
    [cornerBezierPath addLineToPoint:CGPointMake(x+height-lineLength, y+height)];
    
    [cornerBezierPath moveToPoint:CGPointMake(x+lineLength, y+height)];//左下角
    [cornerBezierPath addLineToPoint:CGPointMake(x, y+height)];
    [cornerBezierPath addLineToPoint:CGPointMake(x, y+height-lineLength)];
    
    CAShapeLayer *cornerShapeLayer = [CAShapeLayer layer];
    cornerShapeLayer.backgroundColor = UIColor.clearColor.CGColor;
    cornerShapeLayer.path = cornerBezierPath.CGPath;
    cornerShapeLayer.lineWidth = 3.0;
    cornerShapeLayer.strokeColor = color.CGColor;
    cornerShapeLayer.fillColor = UIColor.clearColor.CGColor;
    [self.view.layer addSublayer:cornerShapeLayer];
    
    //光标
    _gradientLayer = [CAGradientLayer layer];
    _gradientLayer.frame = CGRectMake(x+3, y+3, height-6, 1.5);
    _gradientLayer.colors = [self colorWithBasicColor:color];
    _gradientLayer.startPoint = CGPointMake(0, 0.5);
    _gradientLayer.endPoint = CGPointMake(1.0, 0.5);
    [_gradientLayer addAnimation:[self positionBasicAnimate] forKey:nil];
    [self.view.layer addSublayer:_gradientLayer];
}

- (void)initBtn
{
    CGRect bounds = self.view.bounds;
    
    _labTitle = [[UILabel alloc] initWithFrame:CGRectMake(0, UIApplication.sharedApplication.keyWindow.safeAreaInsets.top + 5, CGRectGetWidth(bounds), 20)];
    _labTitle.font = [UIFont systemFontOfSize:18];
    _labTitle.textAlignment = NSTextAlignmentCenter;
    _labTitle.textColor = UIColor.whiteColor;
    _labTitle.text = @"扫码添加设备";
    [self.view addSubview:_labTitle];
    
    _labDesc = [[UILabel alloc] initWithFrame:CGRectMake(CGRectGetMinX(_scanRect), CGRectGetMaxY(_scanRect) + 10, CGRectGetWidth(_scanRect), 20)];
    _labDesc.font = [UIFont systemFontOfSize:12];
    _labDesc.textAlignment = NSTextAlignmentCenter;
    _labDesc.textColor = [UIColor colorWithRed:153/255.0 green:153/255.0 blue:153/255.0 alpha:1.0];
    _labDesc.text = @"请将二维码放置在识别框中";
    [self.view addSubview:_labDesc];
    
    UIImage *backImage = [UIImage imageNamed:@"btnBack"];
    UIButton *btnBack = [[UIButton alloc] initWithFrame:CGRectMake(10, UIApplication.sharedApplication.keyWindow.safeAreaInsets.top, backImage.size.width, backImage.size.width)];
    [btnBack setImage:backImage forState:UIControlStateNormal];
    [btnBack addTarget:self action:@selector(dismissSelf) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btnBack];
    
    UIButton *btnPhoto = [[UIButton alloc] initWithFrame:CGRectMake(CGRectGetMaxX(bounds) - 60 - 60, CGRectGetMaxY(bounds) - 60 - 30, 60, 60)];
//    [btnPhoto setImage:[UIImage imageNamed:@"btnAlbum"] forState:UIControlStateNormal];
    [btnPhoto addTarget:self action:@selector(openAlbum) forControlEvents:UIControlEventTouchUpInside];
    [btnPhoto setTitle:@"相册" forState:UIControlStateNormal];
    [self.view addSubview:btnPhoto];
    
    if (!_device.hasTorch) {
        return;
    }
    _btnLight = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *image = [UIImage imageNamed:@"flashClose"];
    CGSize size = image.size;
    _btnLight.frame = CGRectMake(0, 0, size.width, size.height);
    [_btnLight setImage:image forState:UIControlStateNormal];
    [_btnLight setImage:[UIImage imageNamed:@"flashOpen"] forState:UIControlStateSelected];
    [_btnLight addTarget:self action:@selector(switchFlashLight:) forControlEvents:UIControlEventTouchUpInside];
    _btnLight.center = CGPointMake(CGRectGetWidth(bounds)/2.0, CGRectGetMaxY(_scanRect) - size.height);
    [self.view addSubview:_btnLight];
}

- (void)switchFlashLight:(UIButton *)btn
{
    if (!_device.hasTorch) {
        return;
    }
    NSError *error = nil;
    BOOL locked = [_device lockForConfiguration:&error];
    if (error) {
        NSLog(@"%@", error);
    }
    if (locked) {
        if (_device.torchMode == AVCaptureTorchModeOff) {
            _device.torchMode = AVCaptureTorchModeOn;
            btn.selected = YES;
        } else {
            _device.torchMode = AVCaptureTorchModeOff;
            btn.selected = NO;
        }
        [_device unlockForConfiguration];
    }
}

//动画
- (CABasicAnimation *)positionBasicAnimate
{
    CGFloat x = CGRectGetMinX(_scanRect);
    CGFloat y = CGRectGetMinY(_scanRect);
    CGFloat height = CGRectGetWidth(_scanRect);
    CABasicAnimation *animate = [CABasicAnimation animationWithKeyPath:@"position"];
    animate.removedOnCompletion = NO;
    animate.duration = 3.0;
    animate.fillMode = kCAFillModeRemoved;
    animate.repeatCount = HUGE_VAL;
    animate.fromValue = [NSValue valueWithCGPoint:CGPointMake(x+height*0.5, y+3)];
    animate.toValue = [NSValue valueWithCGPoint:CGPointMake(x+height*0.5, y+height-3)];
//    animate.autoreverses = YES;//来回往返
    return animate;
}

- (NSArray<UIColor *> *)colorWithBasicColor:(UIColor *)basicCoclor
{
    CGFloat R, G, B, amplitude;
    amplitude = 90/255.0;
    NSInteger numComponents = CGColorGetNumberOfComponents(basicCoclor.CGColor);
    NSArray *colors;
    if (numComponents == 4) {
        const CGFloat *components = CGColorGetComponents(basicCoclor.CGColor);
        R = components[0];
        G = components[1];
        B = components[2];
        colors = @[(id)[UIColor colorWithWhite:0.667 alpha:0.2].CGColor,
                   (id)basicCoclor.CGColor,
                   (id)[UIColor colorWithRed:R+amplitude > 1.0 ? 1.0:R+amplitude
                                        green:G+amplitude > 1.0 ? 1.0:G+amplitude
                                        blue:B+amplitude > 1.0 ? 1.0:B+amplitude alpha:1.0].CGColor,
                   (id)[UIColor colorWithRed:R+amplitude > 1.0 ? 1.0:R+amplitude*2
                                        green:G+amplitude > 1.0 ? 1.0:G+amplitude*2
                                        blue:B+amplitude > 1.0 ? 1.0:B+amplitude*2 alpha:1.0].CGColor,
                   (id)[UIColor colorWithRed:R+amplitude > 1.0 ? 1.0:R+amplitude
                                        green:G+amplitude > 1.0 ? 1.0:G+amplitude
                                        blue:B+amplitude > 1.0 ? 1.0:B+amplitude alpha:1.0].CGColor,
                   (id)basicCoclor.CGColor,
                   (id)[UIColor colorWithWhite:0.667 alpha:0.2].CGColor,];
    } else {
        colors = @[(id)basicCoclor.CGColor,
                   (id)basicCoclor.CGColor,];
    }
    return colors;
}

- (void)dismissSelf
{
    if (_cancel) {
        _cancel(nil);
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)openAlbum
{
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {//判断相机
        return;
    }
    
//    PHPickerViewController *pvc = [PHPickerViewController new];//新框架
    UIImagePickerController *ipc = [UIImagePickerController new];
    ipc.modalPresentationStyle = UIModalPresentationFullScreen;
    ipc.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    ipc.delegate = self;
    [self presentViewController:ipc animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info
{
    [picker dismissViewControllerAnimated:YES completion:nil];
//    [_gradientLayer removeAllAnimations];
    [self scanImageQRCode:info[UIImagePickerControllerOriginalImage]];
}

//识别图片中的二维码
- (void)scanImageQRCode:(UIImage *)imageCode
{
    CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeQRCode
              context:nil
              options:@{CIDetectorAccuracy:CIDetectorAccuracyHigh}];
    NSArray<CIFeature *> *features = [detector featuresInImage:[CIImage imageWithCGImage:imageCode.CGImage]];
    if (features.count >= 1) {
        CIQRCodeFeature *feature = (CIQRCodeFeature *)features.firstObject;
        if (_completion) {
            _completion(feature.messageString);
        }
        NSLog(@"已识别：%@", feature.messageString);
    } else {
        NSLog(@"无法识别图中二维码");
        if (_completion) {
            _completion(nil);
        }
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - AVCaptureMetadataOutputObjectsDelegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputMetadataObjects:(NSArray<__kindof AVMetadataObject *> *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{
    if (metadataObjects.count == 0) return;
    //要提高用户体验，这里可以播放“滴”的声音
    AVMetadataMachineReadableCodeObject *metadata = metadataObjects.firstObject;
    if (_completion) {
        _completion(metadata.stringValue);
    }
    [_gradientLayer removeAllAnimations];
    NSLog(@"扫到了: %@", metadata.stringValue);
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    // 判断设备是否有闪光灯，闪光灯是否开启
    if (!_device.hasTorch || _device.torchMode == AVCaptureTorchModeOn) {
        return;
    }
    
    CFDictionaryRef metaDictionary = CMCopyDictionaryOfAttachments(NULL, sampleBuffer,  kCMAttachmentMode_ShouldPropagate);
    CFDictionaryRef exifDictionary = CFDictionaryGetValue(metaDictionary, kCGImagePropertyExifDictionary);
    CFRelease(metaDictionary);
    CFNumberRef brightnessValue = CFDictionaryGetValue(exifDictionary, kCGImagePropertyExifBrightnessValue);
//    CFRelease(brightnessValue);//释放后，后面会停止更新
//    CFRelease(exifDictionary);//直接崩溃
    float brightness;
    CFNumberGetValue(brightnessValue, kCFNumberFloatType, &brightness);
    
    // 根据brightness的值来判断是否需要显示按钮
    if (brightness < 0) {// 环境太暗，可以打开闪光灯了
        _btnLight.hidden = NO;
    } else if (brightness) {// 环境亮度可以
        _btnLight.hidden = YES;
    }
    
//    NSLog(@"亮：%f", brightness);
}

@end
