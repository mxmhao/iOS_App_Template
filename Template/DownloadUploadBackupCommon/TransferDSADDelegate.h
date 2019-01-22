//
//  TransferDSADDelegate.h

#import <Foundation/Foundation.h>

@class FileTask, UIAlertController;

@protocol TransferDSADDelegate <NSObject>
@optional
//全选
- (void)didSelectAll:(BOOL)isAllSelected;
//没有选中的
- (void)noneSelected:(BOOL)isNone;
//打开文件
- (void)openFile:(FileTask *)task fileTasks:(NSArray<FileTask *> *)filetasks;
//显示弹出框
- (void)showAlertController:(UIAlertController *)ac;

@end
