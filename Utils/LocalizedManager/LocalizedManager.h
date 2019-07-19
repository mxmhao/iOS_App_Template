//
//  LocalizedManager.h
//
//  Created by mxm on 2018/5/7.
//  Copyright © 2018 mxm. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#define LMLocalizedString(key, comment) \
[LMCurrentBundle() localizedStringForKey:(key) value:@"" table:nil]
//#define LMLocalizedString(key, comment) \
//NSLocalizedStringFromTableInBundle(key, nil, LMCurrentBundle(), nil)

@interface LocalizedManager : NSObject

+ (NSArray *)supportedLanguages;
+ (void)changeTo:(NSString *)language;
+ (NSUInteger)currentLanguageIndexInSupportedLanguages;

@end

FOUNDATION_EXTERN NSBundle * LMCurrentBundle(void);
FOUNDATION_EXTERN NSNotificationName const ChangeLanguageNotification;
//iOS系统设置语言时用的Change这个单词
NS_ASSUME_NONNULL_END
