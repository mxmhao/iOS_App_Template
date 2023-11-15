//
//  InputLimiter.m
//

#import "InputLimiter.h"
#import <objc/runtime.h>

@interface _NumberInputUpperLimiter : InputLimiter

- (instancetype)initWithTextField:(UITextField *)textField upperLimit:(int)upperLimit;

@end

@implementation _NumberInputUpperLimiter
{
    int _upperLimit;
    NSCharacterSet *_set;
}

- (instancetype)initWithTextField:(UITextField *)textField upperLimit:(int)upperLimit
{
    self = [super init];
    if (self) {
        _set = [NSCharacterSet characterSetWithCharactersInString:@"0123456789"];
        _upperLimit = upperLimit;
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.delegate = self;
//        [textField addTarget:self action:@selector(valueChanged:) forControlEvents:UIControlEventEditingChanged];
    }
    return self;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
//    NSLog(string);
    if (![_set isSupersetOfSet:[NSCharacterSet characterSetWithCharactersInString:string]]) return NO;
    
    NSString *currentText = textField.text;
    if (nil == currentText) {
        currentText = @"";
    }
    currentText = [currentText stringByReplacingCharactersInRange:range withString:string];
    return currentText.intValue <= _upperLimit;
}

@end

@interface _HexadecimalNumberInputUpperLimiter : InputLimiter

- (instancetype)initWithTextField:(UITextField *)textField upperLimit:(int)upperLimit;

@end

@implementation _HexadecimalNumberInputUpperLimiter
{
    int _upperLimit;
    NSCharacterSet *_set;
}

- (instancetype)initWithTextField:(UITextField *)textField upperLimit:(int)upperLimit
{
    self = [super init];
    if (self) {
        _set = [NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEFabcdef"];
        _upperLimit = upperLimit;
        textField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
        textField.delegate = self;
//        [textField addTarget:self action:@selector(valueChanged:) forControlEvents:UIControlEventEditingChanged];
    }
    return self;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
//    NSLog(string);
    if (![_set isSupersetOfSet:[NSCharacterSet characterSetWithCharactersInString:string]]) return NO;
    
    NSString *currentText = textField.text;
    if (nil == currentText) {
        currentText = @"";
    }
    currentText = [currentText stringByReplacingCharactersInRange:range withString:string];
    const char *ch = [currentText cStringUsingEncoding:NSUTF8StringEncoding];
    int value;
    sscanf(ch, "%x", &value);
    return value <= _upperLimit;
}

@end

@interface _IntegerInputUpperLimiter : InputLimiter

- (instancetype)initWithTextField:(UITextField *)textField positiveUpperLimit:(int)upperLimit negativeLowerLimit:(int)lowerLimit;

@end

@implementation _IntegerInputUpperLimiter
{
    int _upperLimit;
    int _lowerLimit;
    NSCharacterSet *_set;
}

- (instancetype)initWithTextField:(UITextField *)textField positiveUpperLimit:(int)upperLimit negativeLowerLimit:(int)lowerLimit
{
    self = [super init];
    if (self) {
        _set = [NSCharacterSet characterSetWithCharactersInString:@"0123456789-"];
        _upperLimit = upperLimit;
        textField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
        textField.delegate = self;
    }
    return self;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if (![_set isSupersetOfSet:[NSCharacterSet characterSetWithCharactersInString:string]]) return NO;
    // 不是正符号或者数组开头
    if (range.location != 0 && [string containsString:@"-"]) return NO;
    
    NSString *text = textField.text;
    if (nil == text) {
        text = @"";
    }
    text = [text stringByReplacingCharactersInRange:range withString:string];
    
    int value = text.intValue;
    return 0 >= value ? value <= _upperLimit : value >= _lowerLimit;
}

@end

@interface _FloatInputFractionDigitsUpperLimiter : InputLimiter

- (instancetype)initWithTextField:(UITextField *)textField fractionDigits:(UInt8)digits upperLimit:(float)upperLimit;

@end

@implementation _FloatInputFractionDigitsUpperLimiter
{
    float _upperLimit;
    UInt8 _fractionDigits;
    NSCharacterSet *_set;
}

- (instancetype)initWithTextField:(UITextField *)textField fractionDigits:(UInt8)digits upperLimit:(float)upperLimit
{
    self = [super init];
    if (self) {
        _set = [NSCharacterSet characterSetWithCharactersInString:@"0123456789."];
        _upperLimit = upperLimit;
        _fractionDigits = digits;
        textField.keyboardType = UIKeyboardTypeDecimalPad;
        textField.delegate = self;
        [textField addTarget:self action:@selector(textFieldEditingChanged:) forControlEvents:UIControlEventEditingChanged];
    }
    return self;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
//    NSLog(string);
    if (![_set isSupersetOfSet:[NSCharacterSet characterSetWithCharactersInString:string]]) return NO;
    
    NSString *text = textField.text;
    if ([text rangeOfString:@"." options:kNilOptions].length != 0 && [@"." isEqualToString:string]) return NO;
    
    if (nil == text) {
        text = string;
    } else {
        text = [text stringByReplacingCharactersInRange:range withString:string];
    }
    return text.floatValue <= _upperLimit;
}

- (void)textFieldEditingChanged:(UITextField *)textField
{
    NSString *text = textField.text;
    NSRange ptRange = [text rangeOfString:@"." options:kNilOptions];
//    NSLog(@"location: %lu -- %lu", ptRange.location, text.length - 1 - ptRange.location);
    if (ptRange.length != 0 && text.length - 1 - ptRange.location > _fractionDigits) {
        textField.text = [text substringToIndex:ptRange.location + 1 + _fractionDigits];
    }
}

@end

@interface _RationalNumberInputFractionDigitsUpperLimiter : InputLimiter

- (instancetype)initWithTextField:(UITextField *)textField fractionDigits:(UInt8)digits positiveUpperLimit:(float)upperLimit negativeLowerLimit:(float)lowerLimit;

@end

@implementation _RationalNumberInputFractionDigitsUpperLimiter
{
    float _upperLimit;
    float _lowerLimit;
    UInt8 _fractionDigits;
    NSCharacterSet *_set;
}

- (instancetype)initWithTextField:(UITextField *)textField fractionDigits:(UInt8)digits positiveUpperLimit:(float)upperLimit negativeLowerLimit:(float)lowerLimit
{
    self = [super init];
    if (self) {
        _set = [NSCharacterSet characterSetWithCharactersInString:@"0123456789.-"];
        _upperLimit = upperLimit;
        _lowerLimit = lowerLimit;
        _fractionDigits = digits;
        textField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
        textField.delegate = self;
        [textField addTarget:self action:@selector(textFieldEditingChanged:) forControlEvents:UIControlEventEditingChanged];
    }
    return self;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
//    NSLog(string);
    if (![_set isSupersetOfSet:[NSCharacterSet characterSetWithCharactersInString:string]]) return NO;
    
    if (range.location != 0 && [string containsString:@"-"]) return NO;
    
    NSString *text = textField.text;
    if ([text rangeOfString:@"." options:kNilOptions].length != 0 && [@"." isEqualToString:string]) return NO;
    
    if (nil == text) {
        text = string;
    } else {
        text = [text stringByReplacingCharactersInRange:range withString:string];
    }
    float value = text.floatValue;
    return 0 >= value ? value <= _upperLimit : value >= _lowerLimit;
}

//- (void)textFieldDidChangeSelection:(UITextField *)textField
//{
//    NSString *text = textField.text;
//    NSRange ptRange = [text rangeOfString:@"." options:kNilOptions];
////    NSLog(@"location: %lu -- %lu", ptRange.location, text.length - 1 - ptRange.location);
//    if (ptRange.length != 0 && text.length - 1 - ptRange.location > _fractionDigits) {
//        textField.text = [text substringToIndex:ptRange.location + 1 + _fractionDigits];
//    }
//}

- (void)textFieldEditingChanged:(UITextField *)textField
{
    NSString *text = textField.text;
    NSRange ptRange = [text rangeOfString:@"." options:kNilOptions];
//    NSLog(@"location: %lu -- %lu", ptRange.location, text.length - 1 - ptRange.location);
    if (ptRange.length != 0 && text.length - 1 - ptRange.location > _fractionDigits) {
        textField.text = [text substringToIndex:ptRange.location + 1 + _fractionDigits];
    }
}

@end

@implementation InputLimiter

+ (nonnull instancetype)limiterNumberTextField:(UITextField *)textField upperLimit:(int)upperLimit
{
    return [[_NumberInputUpperLimiter alloc] initWithTextField:textField upperLimit:upperLimit];
}

+ (instancetype)limiterHexadecimalNumberTextField:(UITextField *)textField upperLimit:(int)upperLimit
{
    return [[_HexadecimalNumberInputUpperLimiter alloc] initWithTextField:textField upperLimit:upperLimit];
}

+ (nonnull instancetype)limiterIntegerTextField:(UITextField *)textField positiveUpperLimit:(int)upperLimit negativeLowerLimit:(int)lowerLimit
{
    return [[_IntegerInputUpperLimiter alloc] initWithTextField:textField positiveUpperLimit:upperLimit negativeLowerLimit:lowerLimit];
}

+ (nonnull instancetype)limiterFloatTextField:(UITextField *)textField fractionDigits:(UInt8)digits upperLimit:(float)upperLimit
{
    return [[_FloatInputFractionDigitsUpperLimiter alloc] initWithTextField:textField fractionDigits:digits upperLimit:upperLimit];
}

+ (nonnull instancetype)limiterRationalNumberTextField:(UITextField *)textField fractionDigits:(UInt8)digits positiveUpperLimit:(float)upperLimit negativeLowerLimit:(float)lowerLimit
{
    return [[_RationalNumberInputFractionDigitsUpperLimiter alloc] initWithTextField:textField fractionDigits:digits positiveUpperLimit:upperLimit negativeLowerLimit:lowerLimit];
}

- (void)dealloc
{
    NSLog(@"%@ dealloc", NSStringFromClass([self class]));
}

@end

@implementation UITextField (InputLimiterProperty)

- (void)setInputLimiter:(InputLimiter *)inputLimiter
{
    objc_setAssociatedObject(self, @selector(inputLimiter), inputLimiter, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (InputLimiter *)inputLimiter
{
    return objc_getAssociatedObject(self, _cmd);
}

@end
