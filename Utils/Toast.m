//
//  Toast.m
//  RadarModule
//
//  Created by macmini on 2023/9/26.
//

#import "Toast.h"

@implementation Toast
{
    UIButton *_lab;
    NSArray *_cons;
    NSMutableArray<NSString *> *_titles;
    BOOL _isShow;
    dispatch_semaphore_t _semaphore;
}

- (void)addToastViewTo:(UIView *)view
{
    [self addToastViewTo:view toastLocation:0];
}

- (void)addToastViewOnCenterTo:(UIView *)view
{
    [self addToastViewTo:view toastLocation:1];
}

- (void)addToastViewTo:(UIView *)view toastLocation:(int)location
{
    if (nil != _lab) return;
    
    _semaphore = dispatch_semaphore_create(1);
    
    _lab = [UIButton buttonWithType:UIButtonTypeCustom];
    _lab.userInteractionEnabled = NO;
    _lab.contentEdgeInsets = UIEdgeInsetsMake(10, 10, 10, 10);
    _lab.backgroundColor = [UIColor colorWithWhite:0 alpha:0.9];
    _lab.titleLabel.font = [UIFont systemFontOfSize:16];
    _lab.titleLabel.numberOfLines = 0;
    _lab.layer.cornerRadius = 4;
    _lab.alpha = 0.9;
    _lab.hidden = YES;
    [view addSubview:_lab];
    
    [_lab setTranslatesAutoresizingMaskIntoConstraints:NO];
    NSLayoutConstraint *lc1 = [NSLayoutConstraint constraintWithItem:_lab attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:view attribute:NSLayoutAttributeCenterX multiplier:1 constant:0];
    NSLayoutConstraint *lc2;
    if (0 == location) {
        lc2 = [NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeBottomMargin relatedBy:NSLayoutRelationEqual toItem:_lab attribute:NSLayoutAttributeBottom multiplier:1 constant:50];
    } else {
        lc2 = [NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:_lab attribute:NSLayoutAttributeCenterY multiplier:1 constant:0];
    }
    NSLayoutConstraint *lc3 = [NSLayoutConstraint constraintWithItem:_lab attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:view attribute:NSLayoutAttributeLeadingMargin multiplier:1 constant:20];
    NSLayoutConstraint *lc4 = [NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeTrailingMargin relatedBy:NSLayoutRelationGreaterThanOrEqual toItem:_lab attribute:NSLayoutAttributeTrailing multiplier:1 constant:20];
    _cons = @[lc1, lc2, lc3, lc4];
    [view addConstraints:_cons];
}

- (void)removeToastViewFromSuperview
{
    if (nil != _titles) [_titles removeAllObjects];
    if (nil == _lab) return;
    
    [_lab.superview removeConstraints:_cons];
    [_lab removeFromSuperview];
    _lab = nil;
    _cons = nil;
}

- (void)show:(NSString *)text
{
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    if (nil == _titles) {
        _titles = [NSMutableArray arrayWithCapacity:5];
    }
    [_titles addObject:text];
    dispatch_semaphore_signal(_semaphore);
    if (_isShow) return;
    
    [self showToast];
}

- (void)showToast
{
    if (_titles.count == 0 || nil == _lab) return;// || nil == _lab.superview.window
    
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    NSString *text = _titles.firstObject;
    [_titles removeObjectAtIndex:0];
    dispatch_semaphore_signal(_semaphore);
    
    _isShow = YES;
    _lab.hidden = !_isShow;
    _lab.alpha = 0;
    [_lab setTitle:text forState:UIControlStateNormal];
    [_lab.superview bringSubviewToFront:_lab];
    UIButton *lab = _lab;
    [UIView animateWithDuration:.3 animations:^{
        self->_lab.alpha = .9;
    } completion:^(BOOL finished) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self dismissToast:lab];
        });
    }];
}

- (void)dismissToast:(UIButton *)lab
{
    [UIView animateWithDuration:.3 animations:^{
        lab.alpha = 0;
    } completion:^(BOOL finished) {
        self->_isShow = NO;
        lab.hidden = !self->_isShow;
        [self showToast];
    }];
}

@end
