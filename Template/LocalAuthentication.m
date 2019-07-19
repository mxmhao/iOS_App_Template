//
//  LocalAuthentication.m
//  
//
//  Created by mxm on 2019/2/10.
//  Copyright © 2019 mxm. All rights reserved.
//

#import <LocalAuthentication/LocalAuthentication.h>

- (void)LocalAuthentication
{
    /*
     iOS11在info.plist加入
     <key>NSFaceIDUsageDescription</key>
     <string>面容ID用于保证您的数据安全</string>
     */
    LAContext *context = [LAContext new];
    context.localizedFallbackTitle = @""; // 隐藏左边的按钮(默认是忘记密码的按钮)
    //验证方式
    //LAPolicyDeviceOwnerAuthenticationWithBiometrics（只有指纹/FaceID验证功能）
    //LAPolicyDeviceOwnerAuthentication（包含指纹/FaceID验证和密码验证）
    NSError *error = nil;
    BOOL isSupport = [context canEvaluatePolicy:LAPolicyDeviceOwnerAuthentication error:&error];//
    
    if (!isSupport) {
        NSLog(@"当前设备不支持TouchID");
        return;
    }
    
    //起调身份验证
    [context evaluatePolicy:LAPolicyDeviceOwnerAuthentication localizedReason:@"我们需要验证你的身份" reply:^(BOOL success, NSError * _Nullable error) {
        
        if (success) {
            NSLog(@"身份 验证成功");
            //biometryType在这里才会有值
            switch (context.biometryType) {
                case LABiometryNone:
                    break;
                case LABiometryTypeTouchID:
                    break;
                case LABiometryTypeFaceID:
                    break;
                default:
                    break;
            }
            return;
        }
        if (nil == error) {
            return;
        }
            
        switch (error.code) {
            case LAErrorAuthenticationFailed:
                NSLog(@"身份 验证失败");
                break;
            case LAErrorUserCancel:
                NSLog(@"身份验证 被用户手动取消");
                break;
            case LAErrorUserFallback:
                NSLog(@"用户不使用生物识别, 选择手动输入密码");
                break;
            case LAErrorSystemCancel:
                NSLog(@"生物识别 被系统取消 (如遇到来电,锁屏,按了Home键等)");
                break;
            case LAErrorPasscodeNotSet:
                NSLog(@"生物识别 无法启动,因为用户没有设置密码");
                break;
            case LAErrorAppCancel:
                NSLog(@"当前软件被挂起并取消了授权 (如App进入了后台等)");
                break;
            case LAErrorInvalidContext:
                NSLog(@"当前软件被挂起并取消了授权 (LAContext对象无效)");
                break;
            case LAErrorBiometryNotAvailable:
                NSLog(@"生物识别 无效");
                break;
            case LAErrorBiometryNotEnrolled:
                NSLog(@"生物识别 无法启动,因为用户没有设置 生物识别");
                break;
            case LAErrorBiometryLockout:
                NSLog(@"生物识别 被锁定(连续多次验证TouchID失败,系统需要用户手动输入密码)");
                break;
            case LAErrorNotInteractive:break;
            default:
                break;
        }
    }];
}

