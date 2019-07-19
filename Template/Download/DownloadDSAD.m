//
//  DownloadDSAD.m

#import "DownloadDSAD.h"
#import "DownloadManager.h"
#import "FileTask.h"
#import "TransferCell.h"
#import "User.h"
#import <AFNetworking/AFNetworkReachabilityManager.h>
#import "SVProgressHUD.h"
//#import <YYWebImage/UIImage+YYWebImage.h>

static CGFloat const footViewH = 48.0;

NS_INLINE
BOOL UsersCannotUseTheCellular(AFNetworkReachabilityStatus status, BOOL isLoadOnWiFi)
{
    return isLoadOnWiFi && AFNetworkReachabilityStatusReachableViaWWAN == status;//不符合用户设置
}

@interface DownloadDSAD () <DownloadManagerDelegate>
@end

@implementation DownloadDSAD
{
    DownloadManager *_dm;
    NSMutableArray<NSArray<FileTask *> *> *_taskArr;//分组
    NSMutableArray *_titles;//组标题
    
    UIButton *_btnPauseOrResume;//暂停或下载按钮
    FileTask *temptask;
    __weak UITableView *_tableView;
    AFNetworkReachabilityManager *_nrm;
}

- (void)dealloc
{
    NSLog(@"DownloadDSAD -- 释放");
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _dm = [DownloadManager shareManager];
        _dm.delegate = self;
        temptask = nil;
        _taskArr = [NSMutableArray arrayWithCapacity:3];
        _titles = [NSMutableArray arrayWithCapacity:3];
        _nrm = [AFNetworkReachabilityManager sharedManager];
        [self reloadArr];
    }
    return self;
}

- (void)reloadArr
{
    [_taskArr removeAllObjects];
    [_titles removeAllObjects];
    NSArray *arr = _dm.downloadingTasks;
    if (nil != arr && arr.count > 0) {
        [_taskArr addObject:arr];
        [_titles addObject:@"downloading_header"];//正在下载
        if (nil == _btnPauseOrResume) {
            _btnPauseOrResume = [UIButton buttonWithType:UIButtonTypeCustom];
            [_btnPauseOrResume addTarget:self action:@selector(pauseAllOrResumeAll) forControlEvents:UIControlEventTouchUpInside];
        }
        if ([_dm isAllPaused]) {
            _btnPauseOrResume.tag = ResumeAllTag;
            [_btnPauseOrResume setTitle:@"all_downloads_resumed" forState:UIControlStateNormal];//全部恢复下载
        } else {
            _btnPauseOrResume.tag = PasueAllTag;
            [_btnPauseOrResume setTitle:@"all_downloads_suspended" forState:UIControlStateNormal];//全部暂停下载
        }
    }
    arr = _dm.successTasks;
    if (nil != arr && arr.count > 0) {
        [_taskArr addObject:arr];
        [_titles addObject:@"download_success_header"];//下载成功
    }
    arr = _dm.failureTasks;
    if (nil != arr && arr.count > 0) {
        [_taskArr addObject:arr];
        [_titles addObject:@"download_failure_header"];//下载失败
    }
}

- (void)pauseAllOrResumeAll
{
    _btnPauseOrResume.enabled = NO;
    NSString *byteString = @"waiting";//@"等待中...";
    BOOL isPaused = NO;
    BOOL finished = NO;//NO表示未完成，会有noTasksBeingDownloaded回调
    if (ResumeAllTag == _btnPauseOrResume.tag) {
        finished = [_dm resumeAll];
        isPaused = NO;
    } else {
        finished = [_dm pauseAll];
        isPaused = YES;
        byteString = nil;
    }
    NSArray *cells = [_tableView visibleCells];
    for (TransferCell *cell in cells) {
        if (cell.isProgressCell) {
            cell.byteLabel.text = byteString;
            [cell setPausedStatus:isPaused];
        }
    }
    if (finished) {//完成了，不会有回调
        _btnPauseOrResume.enabled = YES;
        if (isPaused) {
            _btnPauseOrResume.tag = ResumeAllTag;
            [_btnPauseOrResume setTitle:@"all_downloads_resumed" forState:UIControlStateNormal];//全部恢复下载
        } else {
            _btnPauseOrResume.tag = PasueAllTag;
            [_btnPauseOrResume setTitle:@"all_downloads_suspended" forState:UIControlStateNormal];//全部暂停下载
            
            if (UsersCannotUseTheCellular(_nrm.networkReachabilityStatus, User.currentUser.loadOnWiFi)) {
                [SVProgressHUD setMinimumDismissTimeInterval:4];
                [SVProgressHUD showImage:[UIImage new] status:@"need_turn_off_the_upload_only_WiFi_only"];
            }
        }
    }
}

- (BOOL)selectAllTasks
{
    if (_taskArr.count == 0) return NO;
    
    [_dm selectAllTasks];
    NSUInteger count = 0;
    for (NSArray<FileTask *> *obj in _taskArr) {
        count += obj.count;
    }
    NSArray<NSIndexPath *> *indxs = _tableView.indexPathsForSelectedRows;
    if (indxs.count == count) return YES;
    
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
    [_dm deselectAllTasks];
    if (!animated) [_tableView reloadData];//有取消动画，这个就不用执行了
}

- (void)deleteAllSelected
{
    [_dm deleteAllSelected];
    [_tableView beginUpdates];
    [_tableView deleteRowsAtIndexPaths:_tableView.indexPathsForSelectedRows withRowAnimation:UITableViewRowAnimationAutomatic];
    [_tableView endUpdates];
    
    [self reloadArr];
    [_tableView reloadData];
}

#pragma mark - DownloadManagerDelegate
- (void)downloadManager:(DownloadManager *)manager didAddNewFileTasks:(NSArray<FileTask *> *)fileTasks
{
    if (![_taskArr containsObject:fileTasks]) {
        [_taskArr insertObject:fileTasks atIndex:0];
        [_titles insertObject:@"downloading_header" atIndex:0];//正在下载
    }
    
    if (_btnPauseOrResume.enabled) {
        _btnPauseOrResume.tag = PasueAllTag;
        [_btnPauseOrResume setTitle:@"all_downloads_suspended" forState:UIControlStateNormal];//全部暂停下载
    }
    [_tableView reloadData];//此方法不能被beginUpdates，endUpdates包围
}

- (void)downloadManager:(DownloadManager *)manager didChangeFileTask:(FileTask *)fileTask
{
    if (_taskArr.firstObject != _dm.downloadingTasks) return;
    NSUInteger index = [_taskArr.firstObject indexOfObject:fileTask];
    TransferCell *cell = [_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
    if (nil == cell) return;//不存在，或者没有不是显示状态
    
    if (FileTaskStatusPause == fileTask.state) {
        [cell setPausedStatus:YES];
    } else {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@/%@", fileTask.completedSizeFormatString, fileTask.sizeFormatString];
        if (FileTaskStatusWaiting == fileTask.state) {
            cell.byteLabel.text = @"waiting";
        } else {
            cell.byteLabel.text = fileTask.speedFormatString;
        }
        [cell setPausedStatus:NO];
    }
}

- (void)downloadManager:(DownloadManager *)manager willMoveFileTaskToArr:(NSArray *)toArr
{
    NSUInteger tsection = [_taskArr indexOfObject:toArr];
    if (NSNotFound != tsection) return;//数组已存在，就不用插入了
    
    //没有目标数组，先给tableview添加一个section
    NSInteger indx = 0;
    if (toArr == _dm.downloadingTasks) {
        [_titles insertObject:@"downloading_header" atIndex:0];//正在下载
    } else if (toArr == _dm.successTasks) {
        if (_taskArr.firstObject == _dm.downloadingTasks) indx = 1;//含有正在下载数组
        else indx = 0;
        [_titles insertObject:@"download_success_header" atIndex:indx];//下载成功
    } else {
        indx = _taskArr.count;
        [_titles addObject:@"download_failure_header"];//下载失败
    }
    //提前插入
    [_taskArr insertObject:toArr atIndex:indx];
    [_tableView beginUpdates];
    [_tableView insertSections:[NSIndexSet indexSetWithIndex:indx] withRowAnimation:UITableViewRowAnimationAutomatic];
    [_tableView endUpdates];
}

- (void)downloadManager:(DownloadManager *)manager didMoveFileTask:(FileTask *)fileTask fromArr:(NSArray *)fromArr fromIndex:(NSUInteger)fromIdx toArr:(NSArray *)toArr toIdx:(NSUInteger)toIdx
{
    NSUInteger fsection = [_taskArr indexOfObject:fromArr];
    NSUInteger tsection = [_taskArr indexOfObject:toArr];
    
    [_tableView beginUpdates];
    [_tableView moveRowAtIndexPath:[NSIndexPath indexPathForRow:fromIdx inSection:fsection] toIndexPath:[NSIndexPath indexPathForRow:toIdx inSection:tsection]];
    [_tableView endUpdates];
    
    if (fromArr.count == 0) {//移动完后删除空section
//        [_tableView beginUpdates];UITableViewRowAnimationNone可以不用这个
        [_taskArr removeObjectAtIndex:fsection];
        [_titles removeObjectAtIndex:fsection];
        [_tableView deleteSections:[NSIndexSet indexSetWithIndex:fsection] withRowAnimation:UITableViewRowAnimationNone];
//        [_tableView endUpdates];
    }
    
    //cell不会reload，所以这步是必须的
    tsection = [_taskArr indexOfObject:toArr];
    TransferCell *cell = [_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:toIdx inSection:tsection]];
    if (nil != cell) {
        [cell setFileTask:fileTask];
        cell.progressCell = FileTaskStatusWaiting == fileTask.state || FileTaskStatusInProgress == fileTask.state || FileTaskStatusPause == fileTask.state;
    }
}

- (void)downloadManager:(DownloadManager *)manager noTasksBeingDownloaded:(BOOL)isNo
{
    _btnPauseOrResume.enabled = YES;
    if (isNo) {
        _btnPauseOrResume.tag = ResumeAllTag;
        [_btnPauseOrResume setTitle:@"all_downloads_resumed" forState:UIControlStateNormal];//全部恢复下载
    } else {
        _btnPauseOrResume.tag = PasueAllTag;
        [_btnPauseOrResume setTitle:@"all_downloads_suspended" forState:UIControlStateNormal];//全部暂停下载
    }
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

#pragma mark Cell内容设置
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    temptask = _taskArr[indexPath.section][indexPath.row];
    TransferCell *cell = [TransferCell dequeueReusableCellWithTableView:tableView];
    [cell setImageWithFileTask:temptask];
    [cell setFileTask:temptask];
    cell.progressCell = FileTaskStatusWaiting == temptask.state || FileTaskStatusInProgress == temptask.state || FileTaskStatusPause == temptask.state;
    
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return _titles[section];
}

#pragma mark - Delegate
- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    if (0 == section && _dm.downloadingTasks == _taskArr.firstObject) return footViewH;
    return 0.01;
}

static int const PasueAllTag = 0;
static int const ResumeAllTag = 1;
- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    if (0 != section || _dm.downloadingTasks != _taskArr.firstObject) return nil;
    
    static NSString *const identifier = @"footIdentifier";
    UITableViewHeaderFooterView *view = [tableView dequeueReusableHeaderFooterViewWithIdentifier:identifier];
    if (!view) {
        view = [[UITableViewHeaderFooterView alloc] initWithReuseIdentifier:identifier];
        view.contentView.backgroundColor = [UIColor whiteColor];
        CGFloat w = tableView.frame.size.width;
        if (nil == _btnPauseOrResume) {
            _btnPauseOrResume = [UIButton buttonWithType:UIButtonTypeCustom];
            _btnPauseOrResume.tag = PasueAllTag;
            [_btnPauseOrResume setTitle:@"all_downloads_suspended" forState:UIControlStateNormal];//全部暂停下载
            [_btnPauseOrResume addTarget:self action:@selector(pauseAllOrResumeAll) forControlEvents:UIControlEventTouchUpInside];
        }
        static CGFloat const btnH = 40.0;
        _btnPauseOrResume.frame = CGRectMake(10, (footViewH - btnH)/2, w - 10 * 2, btnH);
        _btnPauseOrResume.layer.borderWidth = 1.0f;
        _btnPauseOrResume.layer.cornerRadius = 4;
        _btnPauseOrResume.layer.borderColor = [UIColor lightGrayColor].CGColor;
        [_btnPauseOrResume setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
//        [_btnPauseOrResume setBackgroundImage:[UIImage yy_imageWithColor:[UIColor whiteColor]] forState:UIControlStateNormal];
        [view addSubview:_btnPauseOrResume];
    }
    return view;
}

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
            if (tableView.indexPathsForSelectedRows.count == 1 && _delegate && [_delegate respondsToSelector:@selector(noneSelected:)]) {//用==1来判断是为了减少调用次数
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
        switch (task.state) {
            case FileTaskStatusCompleted:
                if (_delegate && [_delegate respondsToSelector:@selector(openFile:fileTasks:)]) {
                    [_delegate openFile:task fileTasks:_taskArr[indexPath.section]];//打开文件
                }
                [tableView deselectRowAtIndexPath:indexPath animated:YES];
                break;
                
            case FileTaskStatusError://重试
                [self showRetry:task sourceView:[tableView cellForRowAtIndexPath:indexPath]];
                break;
                
            case FileTaskStatusDeleted:break;
            default:
                [tableView deselectRowAtIndexPath:indexPath animated:YES];
                if (!_btnPauseOrResume.enabled) return;
                
                if (FileTaskStatusWaiting == task.state || FileTaskStatusInProgress == task.state) {
                    [_dm pauseFileTask:task];
                } else if (FileTaskStatusPause == task.state) {
                    [_dm resumeFileTask:task];
                }
                break;
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
                if (tableView.indexPathsForSelectedRows.count == count - 1) {//用== count - 1来判断是为了减少调用次数
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
    [_dm deleteFileTask:arr[indexPath.row]];
    [tableView beginUpdates];
    if (0 == arr.count) {
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
    [ac addAction:[UIAlertAction actionWithTitle:@"cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        [this retryDownload:nil];
    }]];
    [ac addAction:[UIAlertAction actionWithTitle:@"redownload" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {//重新下载
        [this retryDownload:task];
    }]];
    
    ac.popoverPresentationController.sourceView = sourceView;
    ac.popoverPresentationController.sourceRect = sourceView.bounds;
    [_delegate showAlertController:ac];
}

- (void)retryDownload:(FileTask *)task
{
    [_tableView deselectRowAtIndexPath:_tableView.indexPathForSelectedRow animated:YES];
    if (nil != task) [_dm redownload:task];
}

@end
