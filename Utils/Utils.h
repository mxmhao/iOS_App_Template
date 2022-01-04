//
//  Utils.h
//  iOS_App_Template
//
//  Created by mxm on 2021/7/12.
//  Copyright © 2021 mxm. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Utils : NSObject

+ (NSString *)md5OfFileAtPath:(NSString *)filePath;
//图片缩略图
+ (UIImage *)IOCompressImage:(NSData *)data size:(CGSize)size;

@end

NS_ASSUME_NONNULL_END
