//
//  Utils.m
//  iOS_App_Template
//
//  Created by mxm on 2021/7/12.
//  Copyright © 2021 mxm. All rights reserved.
//

#import "Utils.h"
#import <CommonCrypto/CommonDigest.h>

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

@end
