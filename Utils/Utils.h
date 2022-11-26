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

// 计算文件MD5
+ (NSString *)md5OfFileAtPath:(NSString *)filePath;
// 图片缩略图
+ (UIImage *)IOCompressImage:(NSData *)data size:(CGSize)size;
// 获取文件夹大小
+ (unsigned long long)fetchDirSize:(NSString *)dirPath;
// 获取可用存储空间大小
+ (uint64_t)availableSpace

+ (NSData *)encryptUseAES128CBC:(NSData *)data key:(Byte *)key;

+ (NSData *)decryptUseAES128CBC:(NSData *)data key:(Byte *)key;

+ (NSData *)encryptUseAES128ECB:(NSData *)data key:(Byte *)key;

+ (NSData *)decryptUseAES128ECB:(NSData *)data key:(Byte *)key;

+ (NSData *)encryptUseAES128CBCPKCS7:(NSData *)data key:(Byte *)key;

+ (NSData *)decryptUseAES128CBCPKCS7:(NSData *)data key:(Byte *)key;

@end

NS_ASSUME_NONNULL_END
