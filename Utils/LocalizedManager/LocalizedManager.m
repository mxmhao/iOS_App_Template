//
//  LocalizedManager.m
//
//  Created by mxm on 2018/12/7.
//  Copyright © 2018 mxm. All rights reserved.
//

#import "LocalizedManager.h"
#import "Const.h"

static NSString *const LanguageBundleKey = @"k.com.mxm.xxx.LanguageBundle";
static NSString *const CurrentLanguageKey = @"k.com.mxm.xxx.CurrentLanguage";

static NSBundle *currentBundle;
static dispatch_once_t onceToken;
NSBundle * LMCurrentBundle(void) {
    dispatch_once(&onceToken, ^{
        currentBundle = NSBundle.mainBundle;
        NSString *lb = [NSUserDefaults.standardUserDefaults stringForKey:LanguageBundleKey];
        if (nil != lb) {
            NSString *path = [currentBundle pathForResource:lb ofType:@"lproj"];
            if (nil != path) {
                currentBundle = [NSBundle bundleWithPath:path];
            }
        }
    });
    return currentBundle;
}

NSNotificationName const ChangeLanguageNotification = @"n.com.mxm.xxx.ChangeLanguage";

@implementation LocalizedManager

static NSMutableArray *supportedLanguages;
static NSDictionary *dict;

+ (void)initLang
{
    static NSString *directoryKey = @"directory";   //语言目录
    static NSString *languageKey = @"language";     //语言
    
    static dispatch_once_t langOnceToken;
    dispatch_once(&langOnceToken, ^{
        NSDictionary *dt = [NSMutableDictionary dictionaryWithContentsOfFile:[NSBundle.mainBundle pathForResource:@"SupportLanguages.plist" ofType:nil]];
        supportedLanguages = dt[languageKey];
        [supportedLanguages insertObject:NSLocalizedString(@"auto", @"跟随系统") atIndex:0];//测试这里会不会报错?
        dict = dt[directoryKey];
    });
}

+ (NSArray *)supportedLanguages
{
    [self initLang];
    return supportedLanguages;
    /*
    return @[
        NSLocalizedString(@"auto", @"跟随系统"),//注意，这里是NS
        @"English",
        @"简体中文",
        @"繁體中文",
        @"Deutsch",
        @"Español",
        @"Français",
        @"Italiano",
        @"Magyar",
        @"日本語",
        @"한국어"
    ];数组可以放到本地plist文件中*/
}

/**
 切换语言

 @param language in LocalizedManager.supportedLanguages
 */
+ (void)changeTo:(NSString *)language
{
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    if ([language isEqualToString:[ud stringForKey:CurrentLanguageKey]]) {
        return;//未切换成新语言
    }
    /*
    //value是.lproj包的名字
    NSDictionary *dict = @{//这里不需要auto
        @"English" : @"Base",
        @"简体中文" : @"zh-hans",
        @"繁體中文" : @"zh-hant",
        @"Deutsch" : @"de",
        @"Español" : @"es",
        @"Français" : @"fr",
        @"Magyar" : @"hu",  //这个是匈牙利语
        @"Italiano" : @"it",
        @"日本語" : @"ja",
        @"한국어" : @"ko",
    };字典可以放到本地plist文件中*/
    
    [self initLang];
    [ud setObject:dict[language] forKey:LanguageBundleKey];
    [ud setObject:language forKey:CurrentLanguageKey];
    [ud synchronize];
    onceToken = 0;
    currentBundle = nil;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:ChangeLanguageNotification object:nil];
}

+ (NSUInteger)currentLanguageIndexInSupportedLanguages
{
    NSString *lang = [NSUserDefaults.standardUserDefaults stringForKey:CurrentLanguageKey];
    if (nil == lang) return 0;
    
    NSUInteger index = [[self supportedLanguages] indexOfObject:lang];
    if (NSNotFound == index) return 0;
    
    return index;
}

@end
