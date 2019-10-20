//
//  NSInputStream+Skip.m
//  SourceTest
//
//  Created by min on 2019/10/20.
//  Copyright © 2019 min. All rights reserved.
//

#import "NSInputStream+Skip.h"

@implementation NSInputStream (Skip)

- (void)skip:(NSUInteger)byteCount
{
    if (self.streamStatus == NSStreamStatusAtEnd
        || self.streamStatus == NSStreamStatusClosed
        || self.streamStatus == NSStreamStatusError) {
        return;
    }
    if (self.streamStatus == NSStreamStatusNotOpen) {
        [self open];
    }
    NSUInteger const maxLen = MIN(byteCount, 16384);//16k
    uint8_t buffer[maxLen];
    NSInteger size = 0;
    while (byteCount > 0) {
        size = [self read:buffer maxLength:MIN(byteCount, maxLen)];
        if (size < 1) return;
        
        byteCount -= size;
    }
}

@end
