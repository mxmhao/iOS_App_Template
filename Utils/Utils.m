//
//  Utils.m
//  iOS_App_Template
//
//  Created by mxm on 2021/7/12.
//  Copyright © 2021 mxm. All rights reserved.
//

#import "Utils.h"
#import <CommonCrypto/CommonDigest.h>
#import <UIKit/UIImage.h>
#import <sys/mount.h>

@implementation Utils

+ (NSString *)md5OfFileAtPath:(NSString *)filePath
{
    NSInputStream *is = [NSInputStream inputStreamWithFileAtPath:filePath];
    if (nil == is) {
        return nil;
    }
    [is open];
    NSUInteger const maxLen = 16384;//16k
    uint8_t buffer[maxLen];
    NSInteger size = [is read:buffer maxLength:maxLen];
    CC_MD5_CTX md5;
    CC_MD5_Init(&md5);
    while (size > 0) {
        CC_MD5_Update(&md5, buffer, (CC_LONG)size);
        size = [is read:buffer maxLength:maxLen];
    }
    [is close];
    unsigned char digest[CC_MD5_DIGEST_LENGTH] = {0};
    CC_MD5_Final(digest, &md5);
    return [NSString stringWithFormat:
            @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
            digest[0], digest[1], digest[2], digest[3],
            digest[4], digest[5], digest[6], digest[7],
            digest[8], digest[9], digest[10], digest[11],
            digest[12], digest[13], digest[14], digest[15]];
}

//微信用到的
+ (UIImage *)IOCompressImage:(NSData *)data size:(CGSize)size
{
    CFDataRef cfdata = CFBridgingRetain(data);
    CFStringRef optionKeys[1];
    CFTypeRef optionValues[4];
    optionKeys[0] = kCGImageSourceShouldCache;
    optionValues[0] = (CFTypeRef)kCFBooleanFalse;
    CFDictionaryRef sourceOption = CFDictionaryCreate(kCFAllocatorDefault, (const void **)optionKeys, (const void **)optionValues, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
//    CGImageSourceRef imageSource = CGImageSourceCreateWithURL(cfurl, sourceOption);
    CGImageSourceRef imageSource = CGImageSourceCreateWithData(cfdata, sourceOption);
    CFRelease(sourceOption);
    if (!imageSource) {
        NSLog(@"imageSource is Null!");
        return nil;
    }
    //获取原图片属性
//    CFDictionaryRef property = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil);
//    NSDictionary *propertys = CFBridgingRelease(property);
//    CGFloat height = [propertys[@"PixelHeight"] integerValue]; //图像k宽高，12000
//    CGFloat width = [propertys[@"PixelWidth"] integerValue];
    //以较大的边为基准
    int imageSize = (int)MAX(size.width, size.height);
    CFStringRef keys[5];
    CFTypeRef values[5];
    //创建缩略图等比缩放大小，会根据长宽值比较大的作为imageSize进行缩放
    //kCGImageSourceThumbnailMaxPixelSize为生成缩略图的大小。当设置为800，如果图片本身大于800*600，则生成后图片大小为800*600，如果源图片为700*500，则生成图片为800*500
    keys[0] = kCGImageSourceThumbnailMaxPixelSize;
    CFNumberRef thumbnailSize = CFNumberCreate(NULL, kCFNumberIntType, &imageSize);
    values[0] = (CFTypeRef)thumbnailSize;
    keys[1] = kCGImageSourceCreateThumbnailFromImageAlways;
    values[1] = (CFTypeRef)kCFBooleanTrue;
    keys[2] = kCGImageSourceCreateThumbnailWithTransform;
    values[2] = (CFTypeRef)kCFBooleanTrue;
    keys[3] = kCGImageSourceCreateThumbnailFromImageIfAbsent;
    values[3] = (CFTypeRef)kCFBooleanTrue;
    keys[4] = kCGImageSourceShouldCacheImmediately;
    values[4] = (CFTypeRef)kCFBooleanTrue;
    
    CFDictionaryRef options = CFDictionaryCreate(kCFAllocatorDefault, (const void **)keys, (const void **)values, 4, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CGImageRef thumbnailImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options);
    UIImage *resultImg = [UIImage imageWithCGImage:thumbnailImage];
    
    CFRelease(cfdata);
    CFRelease(thumbnailSize);
    CFRelease(options);
    CFRelease(imageSource);
    CFRelease(thumbnailImage);
    
    return resultImg;
}

// 获取文件夹大小
+ (unsigned long long)fetchDirSize:(NSString *)dirPath
{
    NSFileManager *fm = NSFileManager.defaultManager;
    // 应该比 subpathsAtPath 方法节省内存
    NSDirectoryEnumerator *de = [fm enumeratorAtPath:dirPath];
    unsigned long long size = 0;
    for (NSString *subpath in de) {
//        NSLog(@"%@", subpath);
        size += [fm attributesOfItemAtPath:[dirPath stringByAppendingPathComponent:subpath] error:NULL].fileSize;
    }
    // 格式化方式：[NSByteCountFormatter stringFromByteCount:size countStyle:NSByteCountFormatterCountStyleFile]
    return size;
}

// 获取可用存储空间大小
+ (uint64_t)availableSpace
{
    uint64_t totalSpace;
    uint64_t totalFreeSpace;
    uint64_t totalUsedSpace;
    
    // 以下两种方式都可获取
    NSError *error = nil;
    NSDictionary *dictionary = [NSFileManager.defaultManager attributesOfFileSystemForPath:NSHomeDirectory() error:&error];
    if (error) {
        NSLog(@"availableSpace: %@", error);
        return 0;
    }
    if (dictionary) {
        totalFreeSpace = [dictionary[NSFileSystemFreeSize] unsignedLongLongValue];
        totalSpace = [dictionary[NSFileSystemSize] unsignedLongLongValue];
        totalUsedSpace = totalSpace - totalFreeSpace;
        NSLog(@"total: %@, free: %@, used: %@", [NSByteCountFormatter stringFromByteCount:totalSpace countStyle:NSByteCountFormatterCountStyleFile], [NSByteCountFormatter stringFromByteCount:totalFreeSpace countStyle:NSByteCountFormatterCountStyleFile], [NSByteCountFormatter stringFromByteCount:totalUsedSpace countStyle:NSByteCountFormatterCountStyleFile]);
        return totalFreeSpace;
    }
    
    return 0;
//    struct statfs buf;
//    if (statfs("/", &buf) >= 0) {
//        // f_bavail 普通应用程序可用空间，f_bfree 包括保留块（普通应用程序无法使用）在内的可用空间
//        totalFreeSpace = buf.f_bsize * buf.f_bavail;
//        totalSpace = buf.f_bsize * buf.f_blocks;
//        totalUsedSpace = totalSpace - totalFreeSpace;
//    }
//    NSLog(@"total: %@, free: %@, used: %@", [NSByteCountFormatter stringFromByteCount:totalSpace countStyle:NSByteCountFormatterCountStyleFile], [NSByteCountFormatter stringFromByteCount:totalFreeSpace countStyle:NSByteCountFormatterCountStyleFile], [NSByteCountFormatter stringFromByteCount:totalUsedSpace countStyle:NSByteCountFormatterCountStyleFile]);
    // 以上两种方式的结果一样
}

@end
