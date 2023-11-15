//
//  InputLimiter.h
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface InputLimiter : NSObject <UITextFieldDelegate>

/**
 限制数字
 @param upperLimit 数字上限
 */
+ (instancetype)limiterNumberTextField:(UITextField *)textField upperLimit:(int)upperLimit;

/**
 限制16进制数字
 @param upperLimit 数字上限
 */
+ (instancetype)limiterHexadecimalNumberTextField:(UITextField *)textField upperLimit:(int)upperLimit;

/**
 限制整数
 @param upperLimit 限制正数上限
 @param lowerLimit 限制负数下限
 */
+ (instancetype)limiterIntegerTextField:(UITextField *)textField positiveUpperLimit:(int)upperLimit negativeLowerLimit:(int)lowerLimit;

/**
 限制正小数
 @param digits 限制小数位数
 @param upperLimit 限制正小数上限
 */
+ (instancetype)limiterFloatTextField:(UITextField *)textField fractionDigits:(UInt8)digits upperLimit:(float)upperLimit;

/**
 限制有理数
 @param digits 限制小数位数
 @param upperLimit 限制正数上限
 @param lowerLimit 限制负数下限
 */
+ (instancetype)limiterRationalNumberTextField:(UITextField *)textField fractionDigits:(UInt8)digits positiveUpperLimit:(float)upperLimit negativeLowerLimit:(float)lowerLimit;

@end

@interface UITextField (InputLimiterProperty)

@property (nonatomic, strong) InputLimiter *inputLimiter;

@end

NS_ASSUME_NONNULL_END
