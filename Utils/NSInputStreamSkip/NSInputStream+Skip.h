//
//  NSInputStream+Skip.h
//  SourceTest
//
//  Created by min on 2019/10/20.
//  Copyright © 2019 min. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSInputStream (Skip)

- (void)skip:(NSUInteger)byteCount;

@end

NS_ASSUME_NONNULL_END
