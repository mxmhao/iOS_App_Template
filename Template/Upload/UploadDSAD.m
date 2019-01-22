//
//  UploadDSAD.m

#import "UploadDSAD.h"
#import "UploadManager.h"
#import "TransferCell.h"
#import "FileTask.h"

static CGFloat const footViewH = 54;

@interface UploadDSAD () <UploadManagerDelegate>
@end

@implementation UploadDSAD
{
    UploadManager *_um;
    NSMutableArray<NSArray<FileTask *> *> *_taskArr;//分组
    NSMutableArray<NSString *> *_titles;//组标题
    __weak UITableView *_tableView;
    FileTask *temptask;
}

- (void)dealloc
{
    NSLog(@"UploadDSAD -- 释放");
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _um = [UploadManager shareManager];
        _um.delegate = self;
        _taskArr = [NSMutableArray arrayWithCapacity:3];
        _titles = [NSMutableArray arrayWithCapacity:3];
        temptask = nil;
        [self reloadArr];
    }
    return self;
}

- (void)reloadArr
{
    [_taskArr removeAllObjects];
    [_titles removeAllObjects];
    NSArray *arr = _um.uploadingTasks;
    if (nil != arr && arr.count > 0) {
        [_taskArr addObject:arr];
        [_titles addObject:[HelperMethod GetLocalizeTextForKey:@"uploading_header"]];//正在上传
    }
    arr = _um.successTasks;
    if (nil != arr && arr.count > 0) {
        [_taskArr addObject:arr];
        [_titles addObject:[HelperMethod GetLocalizeTextForKey:@"upload_success_header"]];//上传成功
    }
    arr = _um.failureTasks;
    if (nil != arr && arr.count > 0) {
        [_taskArr addObject:arr];
        [_titles addObject:[HelperMethod GetLocalizeTextForKey:@"upload_failure_header"]];//上传失败
    }
}

- (BOOL)selectAllTasks
{
    if (_taskArr.count == 0) return NO;
    
    [_um selectAllTasks];
    NSUInteger count = 0;
    for (NSArray<FileTask *> *obj in _taskArr) {
        count += obj.count;
    }
    NSArray<NSIndexPath *> *indxs = _tableView.indexPathsForSelectedRows;
    if (indxs.count == count) return YES;
    
    //用并发
    [_taskArr enumerateObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(NSArray<FileTask *> * _Nonnull obj, NSUInteger idxs, BOOL * _Nonnull stop) {
        [obj enumerateObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(FileTask * _Nonnull obj, NSUInteger idxr, BOOL * _Nonnull stop) {
            NSIndexPath *ip = [NSIndexPath indexPathForRow:idxr inSection:idxs];
            if (![indxs containsObject:ip]) {
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    [_tableView selectRowAtIndexPath:ip animated:NO scrollPosition:UITableViewScrollPositionNone];
                });
            }
        }];
    }];
    
    return YES;
}

- (void)deselectAllTasks:(BOOL)animated
{
    [_um deselectAllTasks];
    if (!animated) [_tableView reloadData];//有取消动画，这个就不用执行了
}

- (void)deleteAllSelected
{
    [_um deleteAllSelected];
    [_tableView beginUpdates];
    [_tableView deleteRowsAtIndexPaths:_tableView.indexPathsForSelectedRows withRowAnimation:UITableViewRowAnimationAutomatic];
    [_tableView endUpdates];
    
    [self reloadArr];
    [_tableView reloadData];
}

#pragma mark - UploadManagerDelegate
- (void)uploadManager:(UploadManager *)manager didAddNewFileTasks:(NSArray<FileTask *> *)fileTasks
{
    if (![_taskArr containsObject:fileTasks]) {
        if (_um.uploadingTasks == fileTasks) {
            [_taskArr insertObject:fileTasks atIndex:0];
            [_titles insertObject:[HelperMethod GetLocalizeTextForKey:@"uploading_header"] atIndex:0];//正在上传
        } else {
            [_taskArr addObject:fileTasks];
            [_titles addObject:[HelperMethod GetLocalizeTextForKey:@"upload_failure_header"]];//上传失败
        }
    }
    
    [_tableView reloadData];//此方法不能被beginUpdates，endUpdates包围
}

- (void)uploadManager:(UploadManager *)manager didChangeFileTask:(FileTask *)fileTask
{
    if (_taskArr.firstObject != _um.uploadingTasks) return;
    NSUInteger index = [_taskArr.firstObject indexOfObject:fileTask];
    TransferCell *cell = [_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
    if (nil == cell) return;//不存在，或者没有不是显示状态
    
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@/%@", fileTask.completedSizeFormatString, fileTask.sizeFormatString];
//    NSLog(@"%@ -- speed: %@ -- %lld", cell.detailTextLabel.text, fileTask.speedFormatString, fileTask.size);
    if (FileTaskStatusPause == fileTask.state) {
        cell.byteLabel.text = nil;
    } else {
        cell.byteLabel.text = fileTask.speedFormatString;
    }
}

//将要移动
- (void)uploadManager:(UploadManager *)manager willMoveFileTaskToArr:(NSArray *)toArr
{
    NSUInteger tsection = [_taskArr indexOfObject:toArr];
    if (NSNotFound != tsection) return;
    
    //没有目标数组，先给tableview添加一个section
    NSInteger indx = 0;
    if (toArr == _um.uploadingTasks) {
        indx = 0;
        [_titles insertObject:[HelperMethod GetLocalizeTextForKey:@"uploading_header"] atIndex:0];//正在上传
    } else if (toArr == _um.successTasks) {
        if (_taskArr.firstObject == _um.uploadingTasks) indx = 1;//含有有正在下载的
        else indx = 0;
        [_titles insertObject:[HelperMethod GetLocalizeTextForKey:@"upload_success_header"] atIndex:indx];//上传成功
    } else {
        indx = _taskArr.count;
        [_titles addObject:[HelperMethod GetLocalizeTextForKey:@"upload_failure_header"]];//上传失败
    }
    //先提前插入数组
    [_taskArr insertObject:toArr atIndex:indx];
    [_tableView beginUpdates];
    [_tableView insertSections:[NSIndexSet indexSetWithIndex:indx] withRowAnimation:UITableViewRowAnimationAutomatic];
    [_tableView endUpdates];
}

//移动了
- (void)uploadManager:(UploadManager *)manager didMoveFileTask:(FileTask *)fileTask fromArr:(NSArray *)fromArr fromIndex:(NSUInteger)fromIdx toArr:(NSArray *)toArr toIdx:(NSUInteger)toIdx
{
    NSUInteger tsection = [_taskArr indexOfObject:toArr];
    NSUInteger fsection = [_taskArr indexOfObject:fromArr];
    [_tableView beginUpdates];
    [_tableView moveRowAtIndexPath:[NSIndexPath indexPathForRow:fromIdx inSection:fsection] toIndexPath:[NSIndexPath indexPathForRow:toIdx inSection:tsection]];
    [_tableView endUpdates];
    
    if (fromArr.count == 0) {//移动完后删除空section
//        [_tableView beginUpdates];
        [_taskArr removeObjectAtIndex:fsection];
        [_titles removeObjectAtIndex:fsection];
        [_tableView deleteSections:[NSIndexSet indexSetWithIndex:fsection] withRowAnimation:UITableViewRowAnimationNone];//这里用动画貌似不太好看
//        [_tableView endUpdates];
    }
    
    tsection = [_taskArr indexOfObject:toArr];
    TransferCell *cell = [_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:toIdx inSection:tsection]];
    if (nil != cell) [cell setFileTask:fileTask];
}

#pragma mark - DataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    _tableView = tableView;
    return _taskArr.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _taskArr[section].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    temptask = _taskArr[indexPath.section][indexPath.row];
    TransferCell *cell = [TransferCell dequeueReusableCellWithTableView:tableView];
    [cell setImageWithFileTask:temptask];
    [cell setFileTask:temptask];
    
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return _titles[section];
}

#pragma mark - Delegate
#pragma mark 选中
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView.editing) {
        @try {
            _taskArr[indexPath.section][indexPath.row].selected = YES;
            if (_delegate && [_delegate respondsToSelector:@selector(didSelectAll:)]) {
                NSUInteger count = 0;
                for (NSArray *arr in _taskArr) {
                    count += arr.count;
                }
                if (tableView.indexPathsForSelectedRows.count == count) {
                    [_delegate didSelectAll:YES];
                }
            }
            if (tableView.indexPathsForSelectedRows.count == 1 && _delegate && [_delegate respondsToSelector:@selector(noneSelected:)]) {
                [_delegate noneSelected:NO];
            }
        } @catch (NSException *exception) {
            NSLog(@"exception: %@", exception);
            return;
        }
        return;
    }
    
    @try {
        FileTask *task = _taskArr[indexPath.section][indexPath.row];
        if (FileTaskStatusError == task.state) {
            [self showRetry:task sourceView:[tableView cellForRowAtIndexPath:indexPath]];
        } else {
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
        }
    } @catch (NSException *exception) {//出错说明已不在正在下载中
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        NSLog(@"exception: %@", exception);
        return;
    }
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (tableView.editing) {
        @try {
            _taskArr[indexPath.section][indexPath.row].selected = NO;
            if (_delegate && [_delegate respondsToSelector:@selector(didSelectAll:)]) {
                NSUInteger count = 0;
                for (NSArray *arr in _taskArr) {
                    count += arr.count;
                }
                if (tableView.indexPathsForSelectedRows.count == count - 1) {
                    [_delegate didSelectAll:NO];
                }
            }
            if (tableView.indexPathsForSelectedRows.count == 0 && _delegate && [_delegate respondsToSelector:@selector(noneSelected:)]) {
                [_delegate noneSelected:YES];
            }
        } @catch (NSException *exception) {
            NSLog(@"exception: %@", exception);
            return;
        }
        return;
    }
}

#pragma mark - 侧滑删除
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

//编辑类型
- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleDelete;
}

#pragma mark 删除
//编辑完成
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSArray *arr = _taskArr[indexPath.section];
    [_um deleteFileTask:arr[indexPath.row]];
    [tableView beginUpdates];
    if (arr.count == 0) {
        [_taskArr removeObject:arr];
        [_titles removeObjectAtIndex:indexPath.section];
        [tableView deleteSections:[NSIndexSet indexSetWithIndex:indexPath.section] withRowAnimation:UITableViewRowAnimationTop];
    } else {
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
    [tableView endUpdates];
}

#pragma mark - 重试
- (void)showRetry:(FileTask *)task sourceView:(UIView *)sourceView
{
    if (nil == _delegate || ![_delegate respondsToSelector:@selector(showAlertController:)]) return;
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) this = self;
    [ac addAction:[UIAlertAction actionWithTitle:[HelperMethod GetLocalizeTextForKey:@"cancel"] style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        [this retryUpload:nil];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:[HelperMethod GetLocalizeTextForKey:@"reupload"] style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {//重新上传
        [this retryUpload:task];
    }]];
    
    ac.popoverPresentationController.sourceView = sourceView;
    ac.popoverPresentationController.sourceRect = sourceView.bounds;
    [_delegate showAlertController:ac];
}

- (void)retryUpload:(FileTask *)task
{
    [_tableView deselectRowAtIndexPath:_tableView.indexPathForSelectedRow animated:YES];
    if (nil != task) [_um reupload:task];
}

@end
