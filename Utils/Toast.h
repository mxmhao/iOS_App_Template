//
//  Toast.h
//  RadarModule
//
//  Created by macmini on 2023/9/26.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface Toast : NSObject

- (void)addToastViewTo:(UIView *)view;

- (void)addToastViewOnCenterTo:(UIView *)view;

- (void)removeToastViewFromSuperview;

- (void)show:(NSString *)text;

@end

NS_ASSUME_NONNULL_END
