//
//  TransferCell.m
//  
//
//  Created by mxm on 2018/4/24.
//  Copyright © 2018年 mxm. All rights reserved.
//

#import "TransferCell.h"
#import "FileTask.h"
#import "MarqueeLabel.h"
#import "UIImage+Format.h"
#import "UIFont+TMCustomFont.h"

static CGFloat const ByteLabelW = 70;

@implementation TransferCell
{
    MarqueeLabel *_labMar;//跑马灯控件
//    UIButton *_btn;
    UIImageView *_imgView;
    FileTask *_task;
}

+ (instancetype)dequeueReusableCellWithTableView:(UITableView *)tableView
{
    static NSString *const identifier = @"TransferCellIdentifier";
    TransferCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[TransferCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
        cell.textLabel.font = [UIFont systemFontOfSize:16];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:14];
        cell.byteLabel.font = [UIFont systemFontOfSize:14];
        cell.byteLabel.textAlignment = NSTextAlignmentRight;
    }
    return cell;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        _byteLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, ByteLabelW, 20)];
        [self.contentView addSubview:_byteLabel];
        
        _labMar = [MarqueeLabel new];
        _labMar.font = [UIFont systemFontOfSize:16];
        [self.contentView addSubview:_labMar];
        
        _imgView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"translate_all_stop.png"]];
    }
    return self;
}

- (void)btnAction
{
    
}

- (void)layoutSubviews
{
    //利用super计算textLabel，_labMar使用textLabel的frame
    self.textLabel.hidden = NO;
    _labMar.text = self.textLabel.text;
    [super layoutSubviews];
    _labMar.frame = self.textLabel.frame;
    self.textLabel.hidden = YES;
    
    CGRect frame;
    CGFloat space = 15;//_byteLabel右边的空隙
    if (nil != self.accessoryView) {
//        frame = self.accessoryView.frame;
//        frame.origin.x += 10;
//        self.accessoryView.frame = frame;
        
        space = 5;
    }
    CGFloat w = CGRectGetWidth(self.contentView.bounds);
    frame = self.detailTextLabel.frame;
    frame.origin.x = w - ByteLabelW - space;
    frame.size.width = ByteLabelW;
    _byteLabel.frame = frame;
}

- (void)setFileTask:(FileTask *)task
{
    _task = task;
    self.textLabel.text = task.fileName;
    
    switch (task.state) {
            //这几个是非传输状态
        case FileTaskStatusCompleted:
        case FileTaskStatusError:
        case FileTaskStatusDeleted:
            self.detailTextLabel.text = task.createTimeFormatString;//时间
            self.byteLabel.text = task.sizeFormatString;//大小
            self.accessoryView = nil;
            break;
            
        default://剩下的是传输状态
        {
            self.detailTextLabel.text = [NSString stringWithFormat:@"%@/%@", task.completedSizeFormatString, task.sizeFormatString];//大小
            if (FileTaskTypeUpload == task.type) {
                self.accessoryView = nil;//上传是不能暂停的，所以不需要图片
            } else {
                self.accessoryView = _imgView;
            }
            
            switch (task.state) {
                case FileTaskStatusPause:
                    _byteLabel.text = nil;
                    if (FileTaskTypeDownload == task.type) {
                        _imgView.image = [UIImage imageNamed:@"translate_all_begin.png"];//下载图片
                    }//else //上传图片
                    break;
                    
                case FileTaskStatusInProgress:
                    _byteLabel.text = task.speedFormatString;//速度
                    _imgView.image = [UIImage imageNamed:@"translate_all_stop.png"];//暂停图片
                    break;
                    
                default://剩下的三种Waiting，Exporting，Exported
                    _byteLabel.text = @"waiting";//@"等待中...";
                    _imgView.image = [UIImage imageNamed:@"translate_all_stop.png"];//暂停图片
                    break;
            }
        }//default
            break;
    }
}

- (void)setPausedStatus:(BOOL)isPaused
{
    if (FileTaskTypeUpload == _task.type) {
        self.accessoryView = nil;//上传是不能暂停的，所以不需要图片
    } else {
        self.accessoryView = _imgView;
    }
    if (isPaused) {
        _byteLabel.text = nil;
        if (FileTaskTypeDownload == _task.type) {
            _imgView.image = [UIImage imageNamed:@"translate_all_begin.png"];//下载图片
        }//else //上传图片
    } else {
        _imgView.image = [UIImage imageNamed:@"translate_all_stop.png"];//暂停图片
    }
}

- (void)setImageWithFileTask:(FileTask *)task
{
    if (nil == task.fileExt) {
        task.fileExt = [task.fileName pathExtension];
    }
    self.imageView.image = [UIImage imageNamed:task.fileExt];//根据后缀显示不同的图片
}

@end
