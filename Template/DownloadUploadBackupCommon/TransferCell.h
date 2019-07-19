//
//  TransferCell.h
//  
//
//  Created by mxm on 2018/4/24.
//  Copyright © 2018年 mxm. All rights reserved.
//

#import <UIKit/UIKit.h>

@class FileTask;

@interface TransferCell : UITableViewCell

/** 显示文件大小，或者传输速度 */
@property (nonatomic, strong) UILabel *byteLabel;
/** 是否为正在传输cell */
@property (nonatomic, assign, getter=isProgressCell) BOOL progressCell;

+ (instancetype)dequeueReusableCellWithTableView:(UITableView *)tableView;

- (void)setImageWithFileTask:(FileTask *)task;

- (void)setFileTask:(FileTask *)task;

- (void)setPausedStatus:(BOOL)isPaused;

@end
