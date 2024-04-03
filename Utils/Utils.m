//
//  Utils.m
//  iOS_App_Template
//
//  Created by mxm on 2021/7/12.
//  Copyright © 2021 mxm. All rights reserved.
//

#import "Utils.h"
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonCrypto.h>
#import <UIKit/UIImage.h>
#import <sys/mount.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>

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

static size_t trimedBytesLength(Byte *const bytes, size_t const dataLen)
{
    size_t i = dataLen - 1;
    for (; i >= 0; --i) {
        if (0x00 != bytes[i]) {
            return i + 1;
        }
    }
    
    if (16 == dataLen) {
        return 1;
    }
    
    return dataLen;
}

static const Byte iv[] = {8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 6, 6, 6, 6, 6, 6};

+ (NSData *)encryptUseAES128CBC:(NSData *)data key:(Byte *)key
{
    if (!data) return nil;
    
    NSUInteger len = data.length;
    //AES/ECB/ZeroPadding 是16个byte为一组加密，最后一组不足16个byte要补0
    int diff = kCCKeySizeAES128 - (len % kCCKeySizeAES128);
    NSUInteger newLen = len;
    if (diff > 0) {
        newLen = len + diff;
    }
    Byte newData[newLen];
    memcpy(newData, data.bytes, len);
    memset(newData+len, 0, diff);
//    for (NSUInteger i = len; i < newLen; i++) {
//        newData[i] = 0x00;
//    }
    
    NSLog(@"-- newLen: %lu", (unsigned long)newLen);
    size_t bufferLen = newLen + kCCBlockSizeAES128;
    NSLog(@"-- bufferLen: %zu", bufferLen);
//    void *buffer = malloc(buffersize);
    Byte buffer[bufferLen];
    memset(buffer, 0, bufferLen);
    size_t numBytesEncrypted = 0;
    CCCryptorStatus cryptStatus = CCCrypt(
        kCCEncrypt,
        kCCAlgorithmAES128,
        kNilOptions,
        key,
        kCCBlockSizeAES128,
        iv,
        newData,
        newLen,
        buffer,     //缓存结果
        bufferLen,  //缓存的最大长度
        &numBytesEncrypted  //加密过的
    );
    if (cryptStatus == kCCSuccess) return [NSData dataWithBytes:buffer length:numBytesEncrypted];
    
    return nil;
}

+ (NSData *)decryptUseAES128CBC:(NSData *)data key:(Byte *)key
{
    if (!data) return nil;
    
    size_t bufferLen = data.length + kCCBlockSizeAES128;
    NSLog(@"-- bufferLen: %zu", bufferLen);
//    void *buffer = malloc(buffersize);
    Byte buffer[bufferLen];
    memset(buffer, 0, bufferLen);
    size_t numBytesEncrypted = 0;
    CCCryptorStatus cryptStatus = CCCrypt(
        kCCDecrypt,
        kCCAlgorithmAES128,
        kNilOptions,
        key,
        kCCBlockSizeAES128,
        iv,
        data.bytes,
        data.length,
        buffer,     //缓存结果
        bufferLen,  //缓存的最大长度
        &numBytesEncrypted  //加密过的
    );
    if (cryptStatus == kCCSuccess) return [NSData dataWithBytes:buffer length:trimedBytesLength(buffer, numBytesEncrypted)];
    
    return nil;
}

+ (NSData *)encryptUseAES128ECB:(NSData *)data key:(Byte *)key
{
    if (!data) return nil;
    
    NSUInteger len = data.length;
    //AES/ECB/ZeroPadding 是16个byte为一组加密，最后一组不足16个byte要补0
    int diff = kCCKeySizeAES128 - (len % kCCKeySizeAES128);
    NSUInteger newLen = len;
    if (diff > 0) {
        newLen = len + diff;
    }
    Byte newData[newLen];
    memcpy(newData, data.bytes, len);
    memset(newData+len, 0, diff);
//    for (NSUInteger i = len; i < newLen; i++) {
//        newData[i] = 0x00;
//    }
    
    NSLog(@"-- newLen: %lu", (unsigned long)newLen);
    size_t bufferLen = newLen + kCCBlockSizeAES128;
    NSLog(@"-- bufferLen: %zu", bufferLen);
//    void *buffer = malloc(buffersize);
    Byte buffer[bufferLen];
    memset(buffer, 0, bufferLen);
    size_t numBytesEncrypted = 0;
    CCCryptorStatus cryptStatus = CCCrypt(
        kCCEncrypt,
        kCCAlgorithmAES,
        kCCOptionECBMode,
        key,
        kCCBlockSizeAES128,
        NULL,
        newData,
        newLen,
        buffer,     //缓存结果
        bufferLen,  //缓存的最大长度
        &numBytesEncrypted  //加密过的
    );
    if (cryptStatus == kCCSuccess) return [NSData dataWithBytes:buffer length:numBytesEncrypted];
    
    return nil;
}

+ (NSData *)decryptUseAES128ECB:(NSData *)data key:(Byte *)key
{
    if (!data) return nil;
    
    size_t bufferLen = data.length + kCCBlockSizeAES128;
    NSLog(@"-- bufferLen: %zu", bufferLen);
//    void *buffer = malloc(buffersize);
    Byte buffer[bufferLen];
    memset(buffer, 0, bufferLen);
    size_t numBytesEncrypted = 0;
    CCCryptorStatus cryptStatus = CCCrypt(
        kCCDecrypt,
        kCCAlgorithmAES,
        kCCOptionECBMode,
        key,
        kCCBlockSizeAES128,
        NULL,
        data.bytes,
        data.length,
        buffer,     //缓存结果
        bufferLen,  //缓存的最大长度
        &numBytesEncrypted  //加密过的
    );
    if (cryptStatus == kCCSuccess) return [NSData dataWithBytes:buffer length:trimedBytesLength(buffer, numBytesEncrypted)];
    
    return nil;
}

+ (NSData *)encryptUseAES128CBCPKCS7:(NSData *)data key:(Byte *)key
{
    if (!data) return nil;
    
    NSUInteger len = data.length;
    
    NSLog(@"-- Len: %lu", (unsigned long)len);
    size_t bufferLen = len + kCCBlockSizeAES128;
    NSLog(@"-- bufferLen: %zu", bufferLen);
//    void *buffer = malloc(buffersize);
    Byte buffer[bufferLen];
    memset(buffer, 0, bufferLen);
    size_t numBytesEncrypted = 0;
    CCCryptorStatus cryptStatus = CCCrypt(
        kCCEncrypt,
        kCCAlgorithmAES128,
        kCCOptionPKCS7Padding,
        key,
        kCCBlockSizeAES128,
        iv,
        data.bytes,
        len,
        buffer,     //缓存结果
        bufferLen,  //缓存的最大长度
        &numBytesEncrypted  //加密过的
    );
    if (cryptStatus == kCCSuccess) return [NSData dataWithBytes:buffer length:numBytesEncrypted];
    
    return nil;
}

+ (NSData *)decryptUseAES128CBCPKCS7:(NSData *)data key:(Byte *)key
{
    if (!data) return nil;
    
    size_t bufferLen = data.length;
    NSLog(@"-- bufferLen: %zu", bufferLen);
//    void *buffer = malloc(buffersize);
    Byte buffer[bufferLen];
    memset(buffer, 0, bufferLen);
    size_t numBytesEncrypted = 0;
    CCCryptorStatus cryptStatus = CCCrypt(
        kCCDecrypt,
        kCCAlgorithmAES128,
        kCCOptionPKCS7Padding,
        key,
        kCCBlockSizeAES128,
        iv,
        data.bytes,
        data.length,
        buffer,     //缓存结果
        bufferLen,  //缓存的最大长度
        &numBytesEncrypted  //加密过的
    );
    if (cryptStatus == kCCSuccess) return [NSData dataWithBytes:buffer length:numBytesEncrypted];
    
    return nil;
}

NSString * byte2HexString(Byte buf[], size_t len) {
    const char hex [] = {
        '0', '1', '2', '3', '4', '5', '6', '7',
        '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'
    };

    char chs[len * 2];
    int index = 0;
    Byte b;
    for (int i = 0; i < len; ++i) {
        b = buf[i];
        chs[index] = hex[(b >> 4) & 0x0F];
        ++index;
        chs[index] = hex[b & 0x0F];
        ++index;
    }
    return [[NSString alloc] initWithBytes:chs length:len * 2 encoding:NSUTF8StringEncoding];
}

/**
 #import <AVFoundation/AVFoundation.h>
 获取视频的第一帧
 @param url  视频文件的链接，可以是远程的，也可以是本地的
 @param filePath 缩略图的存放地址
 */
+ (void)createVideoThumbnail:(NSString *)url saveToPath:(NSString *)filePath
{
    if ([NSFileManager.defaultManager fileExistsAtPath:filePath]) {
        [NSFileManager.defaultManager removeItemAtPath:filePath error:NULL];
    }
    
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:[NSURL URLWithString:url] options:nil];
    AVAssetImageGenerator *gen = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    gen.apertureMode = AVAssetImageGeneratorApertureModeEncodedPixels;
    gen.appliesPreferredTrackTransform = YES;
    // 如果我们要精确时间，那么只需要
//    assetGen.requestedTimeToleranceBefore = kCMTimeZero;
//    assetGen.requestedTimeToleranceAfter = kCMTimeZero;
    CMTime time = CMTimeMakeWithSeconds(0, 600);
    if (@available(iOS 16.0, *)) {
        [gen generateCGImageAsynchronouslyForTime:time completionHandler:^(CGImageRef _Nullable image, CMTime actualTime, NSError * _Nullable error) {
            if (NULL == image) {
                return;
            }
            UIImage *videoImage = [[UIImage alloc] initWithCGImage:image];
            NSData *data = UIImageJPEGRepresentation(videoImage, 0.9);
            [data writeToFile:filePath atomically:YES];
        }];
    } else {
        NSError *error = nil;
//        CMTime actualTime;
        CGImageRef image = [gen copyCGImageAtTime:time actualTime:NULL error:&error];
        if (NULL == image) {
            return;
        }
        UIImage *videoImage = [[UIImage alloc] initWithCGImage:image];
        CGImageRelease(image);
        NSData *data = UIImageJPEGRepresentation(videoImage, 0.9);
        [data writeToFile:filePath atomically:YES];
    }
}

+ (void)disableRemoteCommand
{
    MPRemoteCommandCenter *rcc = [MPRemoteCommandCenter sharedCommandCenter];
    
    rcc.pauseCommand.enabled = NO;
    rcc.playCommand.enabled = NO;
    rcc.stopCommand.enabled = NO;
    rcc.togglePlayPauseCommand.enabled = NO;
    rcc.enableLanguageOptionCommand.enabled = NO;
    rcc.disableLanguageOptionCommand.enabled = NO;
    rcc.changePlaybackRateCommand.enabled = NO;
    rcc.changeRepeatModeCommand.enabled = NO;
    rcc.changeShuffleModeCommand.enabled = NO;
    
    rcc.nextTrackCommand.enabled = NO;
    rcc.previousTrackCommand.enabled = NO;
    
    rcc.skipForwardCommand.enabled = NO;
    rcc.skipBackwardCommand.enabled = NO;
    
    rcc.seekForwardCommand.enabled = NO;
    rcc.seekBackwardCommand.enabled = NO;
    rcc.changePlaybackPositionCommand.enabled = NO;
    
    rcc.ratingCommand.enabled = NO;
    
    rcc.likeCommand.enabled = NO;
    rcc.dislikeCommand.enabled = NO;
    rcc.bookmarkCommand.enabled = NO;
    
    [rcc.pauseCommand addTarget:self action:@selector(remoteCommandDoNothing:)];
    [rcc.playCommand addTarget:self action:@selector(remoteCommandDoNothing:)];
    [rcc.stopCommand addTarget:self action:@selector(remoteCommandDoNothing:)];
    [rcc.togglePlayPauseCommand addTarget:self action:@selector(remoteCommandDoNothing:)];
    [rcc.enableLanguageOptionCommand addTarget:self action:@selector(remoteCommandDoNothing:)];
    [rcc.disableLanguageOptionCommand addTarget:self action:@selector(remoteCommandDoNothing:)];
    [rcc.changePlaybackRateCommand addTarget:self action:@selector(remoteCommandDoNothing:)];
    [rcc.changeRepeatModeCommand addTarget:self action:@selector(remoteCommandDoNothing:)];
    [rcc.changeShuffleModeCommand addTarget:self action:@selector(remoteCommandDoNothing:)];
    
    [rcc.nextTrackCommand addTarget:self action:@selector(remoteCommandDoNothing:)];
    [rcc.previousTrackCommand addTarget:self action:@selector(remoteCommandDoNothing:)];
    
    [rcc.skipForwardCommand addTarget:self action:@selector(remoteCommandDoNothing:)];
    [rcc.skipBackwardCommand addTarget:self action:@selector(remoteCommandDoNothing:)];
    
    [rcc.seekForwardCommand addTarget:self action:@selector(remoteCommandDoNothing:)];
    [rcc.seekBackwardCommand addTarget:self action:@selector(remoteCommandDoNothing:)];
    [rcc.changePlaybackPositionCommand addTarget:self action:@selector(remoteCommandDoNothing:)];
    
    [rcc.ratingCommand addTarget:self action:@selector(remoteCommandDoNothing:)];
    
    [rcc.likeCommand addTarget:self action:@selector(remoteCommandDoNothing:)];
    [rcc.dislikeCommand addTarget:self action:@selector(remoteCommandDoNothing:)];
    [rcc.bookmarkCommand addTarget:self action:@selector(remoteCommandDoNothing:)];
    
    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = nil;
}

+ (MPRemoteCommandHandlerStatus)remoteCommandDoNothing:(MPRemoteCommandEvent *)event
{
//    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = nil;
    return MPRemoteCommandHandlerStatusCommandFailed;
}

@end
