//
//  DownloadManager.m

#import "DownloadManager.h"
#import <AFNetworking/AFNetworking.h>
#import "User.h"
#import "FileTask.h"
#import "NSTimer+Block.h"
#import "XMLock.h"
#import "DeviceNetworkManager.h"

static NSString *const DownloadDir = @"Download";//下载目录

@implementation DownloadManager
{
    User *_user;
    UIDevice *_device;
    //下载
    AFHTTPSessionManager *_downloadManager;
    NSMutableArray<FileTask *> *_fileTasks;//已准备好的下载任务列表
    NSMutableArray<FileTask *> *_successTasks;//下载成功的任务
    NSMutableArray<FileTask *> *_failureTasks;//下载失败的任务
    NSURLSessionDownloadTask *_downloadTask;
    FileTask *_currentFileTask;
    NSString *_docDir;  //文档目录
    NSString *_downloadAbsolutePath;//下载目录的绝对路径
    
    XMLock _lock_fileTasks;
    BOOL _isStop;
    BOOL _isLowBattery;//低电量
    
    DeviceNetworkManager *_dnm;
    AFNetworkReachabilityManager *_nrm;
    XMLock _lock_filename;
    NSString *_tmpDir;
    NSFileManager *_fm;
}

static DownloadManager *manager = nil;
static dispatch_once_t onceToken;
+ (instancetype)shareManager
{
    dispatch_once(&onceToken, ^{
        if (nil == manager) {
            manager = [[self alloc] initWithUser:User.currentUser];
        }
    });
    return manager;
}

- (instancetype)initWithUser:(User *)user
{
    if (!user) {
        return nil;
    }
    self = [super init];
    if (self) {
        _user = user;
        _isStop = NO;
        _isLowBattery = NO;
        _lock_fileTasks = XM_CreateLock();
        _lock_filename = XM_CreateLock();
        _tmpDir = NSTemporaryDirectory();
        _docDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        _downloadAbsolutePath = [_docDir stringByAppendingPathComponent:DownloadDir];
        _dnm = [DeviceNetworkManager new];
        _nrm = [AFNetworkReachabilityManager sharedManager];
        [self initFileTasks];
        BOOL isDir = NO;
        _fm = [NSFileManager defaultManager];
        if ([_fm fileExistsAtPath:_downloadAbsolutePath isDirectory:&isDir] || !isDir) {
            [_fm createDirectoryAtPath:_downloadAbsolutePath withIntermediateDirectories:YES attributes:nil error:NULL];
        }
        [self addSkipBackupAttributeToDirectoryAtPath:_downloadAbsolutePath];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(logout) name:UIApplicationWillTerminateNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(logout) name:UserLogoutNotification object:nil];
    }
    return self;
}

- (NSArray<FileTask *> *)downloadingTasks
{
    return _fileTasks;
}

- (NSArray<FileTask *> *)successTasks
{
    return _successTasks;
}

- (NSArray<FileTask *> *)failureTasks
{
    return _failureTasks;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    NSLog(@"DownloadManager -- 释放");
}

#pragma mark 设置不需要备份的目录
- (BOOL)addSkipBackupAttributeToDirectoryAtPath:(NSString *)filePath
{
    assert([_fm fileExistsAtPath:filePath]);
    
    NSURL *URL = [NSURL fileURLWithPath:filePath isDirectory:YES];
    NSError *error = nil;
    BOOL success = [URL setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:&error];
    if(nil != error)
        NSLog(@"Error excluding %@ from backup %@", [filePath lastPathComponent], error);
    
    return success;
}

- (void)initFileTasks
{
    _fileTasks = [NSMutableArray array];
    _successTasks = [NSMutableArray array];
    _failureTasks = [NSMutableArray array];
    [FileTask createTable];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [_fileTasks addObjectsFromArray:[FileTask progressFileTasksForUser:_user taskType:FileTaskTypeDownload]];
        [_successTasks addObjectsFromArray:[FileTask successFileTasksForUser:_user taskType:FileTaskTypeDownload]];
        [_failureTasks addObjectsFromArray:[FileTask failureFileTasksForUser:_user taskType:FileTaskTypeDownload]];
        [_fileTasks enumerateObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(FileTask * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            obj.state = FileTaskStatusWaiting;
        }];
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [self prepareForTask];
            [self startDownloadTask];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityStatusChanged:) name:NetworkUsableDidChangeNotification object:nil];//AFNetworkingReachabilityDidChangeNotification
        });
    });
}

- (void)logout
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    _isStop = YES;
    _user = nil;
    if (_downloadTask) {//暂停当前
        _currentFileTask.state = FileTaskStatusWaiting;
        FileTask *task = _currentFileTask;
        __weak typeof(self) this = self;
        [_downloadTask cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
            //要想resumeData不为nil，响应头中必须有Etag或Last-modified(两者其一，或者都有)
            __strong typeof(this) sself = this;
//            [sself mergeFile:task withResumeData:resumeData];
            [sself saveTask:task withResumeData:resumeData];
        }];
        _currentFileTask = nil;
        _downloadTask = nil;
    }
    XM_Lock(_lock_fileTasks);
    if (_fileTasks && _fileTasks.count > 0) {
        [FileTask updateFileTasks:_fileTasks];
        [_fileTasks removeAllObjects];
    }
    [_successTasks removeAllObjects];
    [_failureTasks removeAllObjects];
    XM_UnLock(_lock_fileTasks);
    
    _fileTasks = nil;
    _successTasks = nil;
    _failureTasks = nil;
    _delegate = nil;
    _user = nil;
    _delegate = nil;
    _device = nil;
    _downloadManager = nil;
    _dnm = nil;
    _nrm = nil;
    onceToken = 0;
    manager = nil;
}

//添加下载任务
- (void)downloadFile:(RequestModel *)model fromserverDirectory:(NSString *)serverDirectory
{
    NSString *fileName = model.name;
    NSString *serverPath = [serverDirectory stringByAppendingPathComponent:fileName];
    if ([FileTask isExistsFileTaskForUser:_user serverPath:serverPath fileTaskType:FileTaskTypeDownload]) //当前任务已存在
        return;
    
    FileTask *fileTask = [[FileTask alloc] initForInsert];
    fileTask.type = FileTaskTypeDownload;
    fileTask.fileName = fileName;
    fileTask.fileExt = [fileName pathExtension];
    fileTask.mac = _user.mac;
    fileTask.userId = _user.Id;
    fileTask.state = FileTaskStatusWaiting;
    fileTask.size = model.size.integerValue;
    fileTask.filetype = [FileOperationTools getFileType:fileName];//文件类型
    fileTask.serverPath = serverPath;//[serverDirectory stringByAppendingPathComponent:model.name];
//    fileTask.localPath = localPath;//DownLoadSanboxFilePath//具体保存的时候再去获取
    fileTask.createTime = [NSDate date].timeIntervalSince1970;
    [fileTask updateToLocal];
    XM_OnThreadSafe(_lock_fileTasks, [_fileTasks addObject:fileTask]);
    if (_delegate && [_delegate respondsToSelector:@selector(downloadManager:didAddNewFileTasks:)]) {
        XM_OnThreadSafe(_lock_fileTasks, [_delegate downloadManager:self didAddNewFileTasks:_fileTasks]);
    }
    [self prepareForTask];
    [self startDownloadTask];
}

//为下载做准备
- (void)prepareForTask
{
    if (nil == _user) return;
    
    if (!_device) {
        _device = [UIDevice currentDevice];
        //开启电池监听
        _device.batteryMonitoringEnabled = YES;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(batteryLevelDidChanged) name:UIDeviceBatteryLevelDidChangeNotification object:nil];
    }
}

#pragma mark 网络监听
- (void)reachabilityStatusChanged:(NSNotification *)noti
{
    if (![noti.userInfo[NetworkUsableItem] boolValue]) {
        [self pauseAllIsAuto:YES];
    } else {
        if (_user.isPauseAllDownload || _device.batteryLevel <= LowBatteryMustStopValue)//用户自己暂停的，或者电量过低
            return;
        
        [self resumeAllIsAuto:YES];
    }
    return;
    
    if (UsersCannotUseTheNetwork([noti.userInfo[AFNetworkingReachabilityNotificationStatusItem] integerValue], _user.loadOnWiFi)) {//用户不能使用网络
        [self pauseAllIsAuto:YES];
        NSLog(@"网络断开暂停");
    } else {
        if (_user.isPauseAllDownload || _device.batteryLevel <= LowBatteryMustStopValue)//用户自己暂停的，或者电量过低
            return;
        
        __weak typeof(self) this = self;
        [_dnm deviceReachability:^(BOOL isReachable) {
            if (isReachable) {
                [this resumeAllIsAuto:YES];
            }
        }];
    }
}

//电池监听
- (void)batteryLevelDidChanged
{
    if (//(_user.stopBackupAlbumWhenLowBattery && _device.batteryLevel < LowBatteryValue) ||
        _device.batteryLevel <= LowBatteryMustStopValue) {//电量过低
        if (_isLowBattery) return;//防止下面的重复执行
        
        _isLowBattery = YES;
        [self pauseAllIsAuto:YES];
    } else {
        if (!_isLowBattery) return;//防止下面的重复执行
        _isLowBattery = NO;
        
        if (_user.isPauseAllDownload || UsersCannotUseTheNetwork(_nrm.networkReachabilityStatus, _user.loadOnWiFi)) return;//用户不能使用网络
        
        [self resumeAllIsAuto:YES];
    }
}

//开始下载, _downloadManager初始化
- (void)startDownloadTask
{
    if (_device.batteryLevel < LowBatteryMustStopValue//快关机了
        || UsersCannotUseTheNetwork(_nrm.networkReachabilityStatus, _user.loadOnWiFi))//用户不能使用网络
        return;
    
    if (nil == _downloadManager) {
#warning 请仔细阅读注释
        /*
         在info.plist中设置后台模式
         设置后台NSURLSessionConfiguration的NSURLSession在App的生命周期内同一个Identifier只能有
         一个，不能new新的，而且Identifier必须唯一，不能和其他App的冲突，后台上传下载都是如此，而且，
         只有对NSURLSessionDownloadTask和NSURLSessionUploadTask才有效，其他的无效
         */
        //[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"min.test.DownloadManager"] 若没有杀死当前app，在第二次new时，这个会导致cancelByProducingResumeData是不会回调completionHandler，我疯了🤣
        _downloadManager = [[AFHTTPSessionManager alloc] initWithBaseURL:nil sessionConfiguration:[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"min.test.DownloadManager"]];
//        _downloadManager = [AFHTTPSessionManager manager];
//        _downloadManager.completionQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    }
    
    if (nil == _currentFileTask) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self startNextDownloadTask];
        });
    }
}

#pragma mark 下载文件
- (NSString *)fetchLocalPathForFileName:(NSString *)fileName
{
    if (nil == fileName || fileName.length == 0) return nil;
    
    XM_Lock(_lock_filename);
    //检查本地否存在同名文件，要是有就在名字后面追加数字
    BOOL isDir = YES;
    BOOL isExist = [_fm fileExistsAtPath:[_downloadAbsolutePath stringByAppendingPathComponent:fileName] isDirectory:&isDir];
    XM_UnLock(_lock_filename);
    if (!isExist || (isExist && isDir))
        return [DownloadDir stringByAppendingPathComponent:fileName];
    
    XM_Lock(_lock_filename);
    NSString *name = [fileName stringByDeletingPathExtension];//获得文件名(不带后缀)
    NSString *suffix = [fileName pathExtension];//获得文件的后缀名(不带'.')
    NSString *format = nil;
    if (nil == suffix || suffix.length == 0) {
        format = [name stringByAppendingString:@"(%lu)"];
    } else {
        format = [name stringByAppendingFormat:@"(%@).%@", @"%lu", suffix];
    }//format = "name(%lu)" or "name(%lu).suffix"
    NSString *localPath = nil;
    NSString *absolutePath = nil;
    NSString *newName = nil;
    for (NSUInteger i = 1; i <= NSUIntegerMax; ++i) {
        newName = [NSString stringWithFormat:format, (unsigned long)i];
        absolutePath = [_downloadAbsolutePath stringByAppendingPathComponent:newName];
        isExist = [_fm fileExistsAtPath:absolutePath isDirectory:&isDir];
        if (!isExist || (isExist && isDir)) {//不存在，或者是文件夹
            localPath = [DownloadDir stringByAppendingPathComponent:newName];
            break;
        }
    }
    XM_UnLock(_lock_filename);
    
    return localPath;
}

- (void)downloadFileWithTask:(FileTask *)fileTask
{
    if (FileTaskStatusWaiting != fileTask.state) {
        [self startNextDownloadTask];
        return;
    }
    
    uint64_t rangeStart = 0;
    
    __weak typeof(self) this = self;
    __block int64_t lastBytes = 0;
    __block NSTimeInterval lastTime = CACurrentMediaTime();
    id downloadProgress = ^(NSProgress * _Nonnull downloadProgress) {
        fileTask.completedSize = rangeStart + downloadProgress.completedUnitCount;
        NSTimeInterval spaceTime = CACurrentMediaTime() - lastTime;
        //spaceTime是不是可以做一个保留2位小数的处理？
        if (spaceTime < 0.950000) return;//时间太短
        //间隔时间超过1s就测试一次速度
        if (spaceTime > 1.100000) {//间隔太大还是要精确处理
            fileTask.transmissionSpeed = (downloadProgress.completedUnitCount - lastBytes)/spaceTime;//这个是精确的速度
        } else {//下面的速度是粗略处理，不需要那么精确
            fileTask.transmissionSpeed = downloadProgress.completedUnitCount - lastBytes;
        }
        lastBytes = downloadProgress.completedUnitCount;
        [this notifyChangedForFileTask:fileTask];
        lastTime = CACurrentMediaTime();
    };
    
    id completionHandler = ^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
        //当手动退出账号后再次登录时，使用cancelByProducingResumeData时，这里不会调用，why😅
        __strong typeof(this) sself = this;
        [sself setDownloadTaskNil];
        if (nil == error) {
            fileTask.state = FileTaskStatusCompleted;
            //完成了，合并文件，
            [sself mergeFile:fileTask tempFilePath:filePath tempFileSize:0];
        } else {
            if ([NSURLErrorDomain isEqualToString:error.domain]) {
                if (error.code == NSURLErrorNetworkConnectionLost || error.code == NSURLErrorTimedOut) {//网络断开
                    fileTask.state = FileTaskStatusPause;
                    static dispatch_once_t onceToken;
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        [sself mergeFile:fileTask withResumeData:error.userInfo[NSURLSessionDownloadTaskResumeData]];
                    });
                    [sself notifyChangedForFileTask:fileTask];
                    return;
                }
                if (error.code == NSURLErrorCancelled) {//NSURLErrorDomain
                    //当前task.state设置成了FileTaskStatusWaiting
                    if ([sself isStop]) return;
                    if (FileTaskStatusPause == fileTask.state || FileTaskStatusDeleted == fileTask.state) {
                        //取消的哪项，被暂停或删除了，就要继续下一个
                        [sself startNextDownloadTask];
                        return;
                    }
                }
                
            } else {
                fileTask.state = FileTaskStatusError;
                [sself mergeFile:fileTask withResumeData:error.userInfo[NSURLSessionDownloadTaskResumeData]];
            }
        }
        [sself completedDownloadFileTask:fileTask];
    };
    
    NSString *url = [fileTask.serverPath getDownLoadPath];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    NSString *absolutePath = [_docDir stringByAppendingPathComponent:fileTask.localPath];
    //查看文件是否已存在，要是存在就接着下载
    if (!IsTextEmptyString(fileTask.localPath) && [_fm fileExistsAtPath:absolutePath]) {
        NSDictionary *dic = [_fm attributesOfItemAtPath:absolutePath error:NULL];
        rangeStart = [dic fileSize];
        if (rangeStart == fileTask.size) {//已经存在并且下载完了
            fileTask.completedSize = rangeStart;
            fileTask.state = FileTaskStatusCompleted;
            [fileTask updateStatusToLocal];
            [self completedDownloadFileTask:fileTask];
            return;
        }
        [request setValue:[NSString stringWithFormat:@"bytes=%llu-", rangeStart] forHTTPHeaderField:@"Range"];//继续下载没下完的部分
        fileTask.completedSize = rangeStart;
        //此断点续传有bug，当server上的此文件被其它的文件覆盖了，继续下载就是错误的文件
    }
    fileTask.state = FileTaskStatusInProgress;
    _currentFileTask = fileTask;
    
    _downloadTask = [_downloadManager downloadTaskWithRequest:request progress:downloadProgress destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
        return [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:response.suggestedFilename]];
    } completionHandler:completionHandler];
    [_downloadTask resume];
}

static NSString *const ResumeDataObjects = @"$objects";//iOS12中的URL和临时文件名存放的位置
- (void)downloadFileWithResume:(FileTask *)fileTask
{
    if (FileTaskStatusWaiting != fileTask.state) {
        [self startNextDownloadTask];
        return;
    }
    
    __weak typeof(self) this = self;
    __block uint64_t lastBytes = fileTask.completedSize;
    __block NSTimeInterval lastTime = CACurrentMediaTime();
    id downloadProgress = ^(NSProgress * _Nonnull downloadProgress) {
        fileTask.completedSize = downloadProgress.completedUnitCount;
        NSTimeInterval spaceTime = CACurrentMediaTime() - lastTime;
        //spaceTime是不是可以做一个保留2位小数的处理？
        if (spaceTime < 0.950000) return;//时间太短
        //间隔时间超过1s就测试一次速度
        if (spaceTime > 1.100000) {//间隔太大还是要精确处理
            fileTask.transmissionSpeed = (downloadProgress.completedUnitCount - lastBytes)/spaceTime;//这个是精确的速度
        } else {//下面的速度是粗略处理，不需要那么精确
            fileTask.transmissionSpeed = downloadProgress.completedUnitCount - lastBytes;
        }
//        NSLog(@"%lld -- %lld", downloadProgress.completedUnitCount, downloadProgress.totalUnitCount);
        lastBytes = downloadProgress.completedUnitCount;
        [this notifyChangedForFileTask:fileTask];
        lastTime = CACurrentMediaTime();
    };
    
    id completionHandler = ^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
        if (nil != error) {
            NSLog(@"%@\n%@", filePath, error);
        }
        //当手动退出账号后再次登录时，使用cancelByProducingResumeData时，这里不会调用，why😅
        __strong typeof(this) sself = this;
        [sself setDownloadTaskNil];
        if (nil == error) {
            fileTask.state = FileTaskStatusCompleted;
            [self moveFilePath:filePath forTask:fileTask];
        } else if ([NSURLErrorDomain isEqualToString:error.domain]) {
            if (error.code == NSURLErrorNetworkConnectionLost || error.code == NSURLErrorTimedOut) {//网络断开
                fileTask.state = FileTaskStatusPause;
                [sself saveTask:fileTask withResumeData:error.userInfo[NSURLSessionDownloadTaskResumeData]];
                __strong typeof(this) self = this;
                if (self->_device.batteryLevel < LowBatteryMustStopValue//快关机了
                    || UsersCannotUseTheNetwork(self->_nrm.networkReachabilityStatus, self->_user.loadOnWiFi)) {//检查是不是iOS的BUG，自动中断
                    [sself notifyChangedForFileTask:fileTask];//不是
                } else {//是
                    fileTask.state = FileTaskStatusWaiting;
                    [sself downloadFileWithResume:fileTask];
                }
                return;//不用继续下一个下载
            } else if (error.code == NSURLErrorCancelled) {
                //取消分两种情况，在取消的地方已经处理了fileTask的状态保存工作，这里不用自己处理
                //当前task.state设置成了FileTaskStatusWaiting
                if ([sself isStop]) return;
                if (FileTaskStatusPause == fileTask.state || FileTaskStatusDeleted == fileTask.state) {
                    //取消的哪项，被暂停或删除了，就要继续下一个
                    [sself startNextDownloadTask];
                    return;
                }
            }
            fileTask.state = FileTaskStatusError;
            [sself saveTask:fileTask withResumeData:error.userInfo[NSURLSessionDownloadTaskResumeData]];
        } else {
            fileTask.state = FileTaskStatusError;
            [sself saveTask:fileTask withResumeData:error.userInfo[NSURLSessionDownloadTaskResumeData]];
        }
        //处理UI通知，继续下一个下载
        [sself completedDownloadFileTask:fileTask];
    };
    
    id destination = ^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
        return [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:response.suggestedFilename]];
    };
    
    NSString *url = [fileTask.serverPath getDownLoadPath];
    
    fileTask.state = FileTaskStatusInProgress;
    _currentFileTask = fileTask;
    
    NSString *absolutePath = [_tmpDir stringByAppendingPathComponent:fileTask.resumeDataName];
    //查看文件是否已存在，要是存在就接着下载
    if (!IsTextEmptyString(fileTask.resumeDataName) && [_fm fileExistsAtPath:absolutePath]) {
        
        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:absolutePath];
        if (@available(iOS 12, *)) {
            static int const URLIndex = 13;
//            dict[ResumeDataObjects][URLIndex] = url;
            NSMutableArray *arr = dict[ResumeDataObjects];
            NSString *item;
            for (int i = 0, count = arr.count; i < count; ++i) {
                item = arr[i];
                if ([item isKindOfClass:NSString.class] && [item hasPrefix:@"http"]) {
                    arr[i] = url;
                    break;
                }
            }
        } else {
static NSString *const NSURLSessionDownloadURLKey = @"NSURLSessionDownloadURL";
            dict[NSURLSessionDownloadURLKey] = url;
        }
        _downloadTask = [_downloadManager downloadTaskWithResumeData:[DownloadManager dataWithContentsOfNSDictionary:dict] progress:downloadProgress destination:destination completionHandler:completionHandler];
        [_downloadTask resume];
    } else {
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
//        [request addValue:@"keep-alive" forHTTPHeaderField:@"Connection"];
        _downloadTask = [_downloadManager downloadTaskWithRequest:request progress:downloadProgress destination:destination completionHandler:completionHandler];
        [_downloadTask resume];
    }
}

- (BOOL)isStop
{
    return _isStop;
}

- (void)setDownloadTaskNil
{
    _currentFileTask = nil;
    _downloadTask = nil;
}

- (void)saveTask:(FileTask *)task withResumeData:(NSData *)resumeData
{
    if (nil == resumeData || nil == task) return;
    
    NSDictionary *dic = [DownloadManager dictionaryWithContentsOfData:resumeData];
    if (@available(iOS 12, *)) {//  13,14
        static int const filenameIndex = 14;//下标无法固定，只能用循环比较了
//        task.resumeDataName = [dic[ResumeDataObjects][filenameIndex] stringByAppendingPathExtension:@"plist"];
        NSArray *arr = dic[ResumeDataObjects];
//        NSLog(@"%@", arr[filenameIndex-1]);
//        NSLog(@"%@", arr[filenameIndex]);
        for (NSString *item in arr) {
            if ([item isKindOfClass:NSString.class] && [item hasSuffix:@".tmp"]) {
                task.resumeDataName = [item stringByAppendingPathExtension:@"plist"];
                break;
            }
        }
    } else {
static NSString *const NSURLSessionResumeInfoTempFileName = @"NSURLSessionResumeInfoTempFileName";
static NSString *const NSURLSessionResumeBytesReceived = @"NSURLSessionResumeBytesReceived";
        task.resumeDataName = [[dic objectForKey:NSURLSessionResumeInfoTempFileName] stringByAppendingPathExtension:@"plist"];
    }
    [resumeData writeToFile:[_tmpDir stringByAppendingPathComponent:task.resumeDataName] atomically:YES];
    [task updateStatusToLocal];
}

- (void)moveFilePath:(NSURL *)filePath forTask:(FileTask *)task
{
    if (!IsTextEmptyString(task.resumeDataName)) {
        [_fm removeItemAtPath:[_tmpDir stringByAppendingPathComponent:task.resumeDataName] error:NULL];
        task.resumeDataName = nil;
    }
    task.localPath = [self fetchLocalPathForFileName:task.fileName];
    [task updateToLocal];
    [_fm moveItemAtURL:filePath toURL:[NSURL fileURLWithPath:[_docDir stringByAppendingPathComponent:task.localPath]] error:NULL];
}

- (void)mergeFile:(FileTask *)task withResumeData:(NSData *)resumeData
{
    static NSString *const NSURLSessionResumeInfoTempFileName = @"NSURLSessionResumeInfoTempFileName";
    static NSString *const NSURLSessionResumeBytesReceived = @"NSURLSessionResumeBytesReceived";
    //NSURLSessionResumeByteRange
    if (nil == resumeData || nil == task) return;
    //要想resumeData不为nil，响应头中必须有Etag或Last-modified(两者其一，或者都有)
    
    NSDictionary *dic = [DownloadManager dictionaryWithContentsOfData:resumeData];
    NSString *tempFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[dic objectForKey:NSURLSessionResumeInfoTempFileName]];
    [self mergeFile:task tempFilePath:[NSURL fileURLWithPath:tempFilePath] tempFileSize:[[dic objectForKey:NSURLSessionResumeBytesReceived] unsignedLongLongValue]];
}

+ (NSDictionary *)dictionaryWithContentsOfData:(NSData *)data
{
//    CFPropertyListFormat format;
    CFPropertyListRef list = CFPropertyListCreateWithData(kCFAllocatorDefault, (__bridge CFDataRef)data, kCFPropertyListImmutable, /*&format*/NULL, NULL);
    
    if (NULL == list) return nil;
    if (CFGetTypeID(list) == CFDictionaryGetTypeID()) {
        return (__bridge NSDictionary *)list;
    } else {
        CFRelease(list);
        return nil;
    }
}

+ (NSData *)dataWithContentsOfNSDictionary:(NSDictionary *)dict
{
    if (nil == dict || dict.count == 0) return nil;
    return (__bridge NSData *)(CFPropertyListCreateData(kCFAllocatorDefault, (__bridge CFPropertyListRef)(dict), kCFPropertyListXMLFormat_v1_0, kCFPropertyListImmutable, NULL));
}

//合并文件，为了可以断点续传，当filesize=0时，表示需要自己计算
- (void)mergeFile:(FileTask *)task tempFilePath:(NSURL *)filePath tempFileSize:(uint64_t)filesize
{   //NSLog(@"合并文件 二");
    if (nil == filePath || nil == task) return;
    
    if (nil == task.localPath) {//文件不存在，移动临时文件
        task.localPath = [self fetchLocalPathForFileName:task.fileName];
        [task updateToLocal];
        NSError *err = nil;
        [_fm moveItemAtURL:filePath toURL:[NSURL fileURLWithPath:[_docDir stringByAppendingPathComponent:task.localPath]] error:&err];
        NSLog(@"move item error: %@", err);
        return;
    }
    //文件存在，合并临时文件
    //当前文件写操作
    NSFileHandle *fwriter = [NSFileHandle fileHandleForWritingAtPath:[_docDir stringByAppendingPathComponent:task.localPath]];
    uint64_t hasComp = [fwriter seekToEndOfFile];
    //临时文件读操作
    NSFileHandle *freader = [NSFileHandle fileHandleForReadingFromURL:filePath error:NULL];
    
    static int const bufferLenght = 33554432;//32MB,每次读取的长度
    //临时文件的大小
    uint64_t tempFileSize = filesize;
    if (0 == tempFileSize) {
        tempFileSize = [freader seekToEndOfFile];//获取文件大小
        [freader seekToFileOffset:0];
    }
    
    task.completedSize = hasComp + tempFileSize;//重新计算一下已下载的文件大小
    
    static XMLock mergeLock;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mergeLock = XM_CreateLock();
    });
    XM_Lock(mergeLock);
    [fwriter seekToEndOfFile];//防止多线程有错误，这里再执行一次
//    NSTimeInterval time = CACurrentMediaTime();
    uint64_t offset = 0;
    while (offset + bufferLenght <= tempFileSize) {
        @autoreleasepool{
            [fwriter writeData:[freader readDataOfLength:bufferLenght]];//会有内存暴增，所以要自动释放池
        }
        offset += bufferLenght;
    }
    
    [fwriter writeData:[freader readDataToEndOfFile]];
    [fwriter closeFile];
    [freader closeFile];
//    NSLog(@"合并用时%f, -- %f", CACurrentMediaTime() - time, tempFileSize/1024.0/1024.0);
    XM_UnLock(mergeLock);
    
    [_fm removeItemAtURL:filePath error:NULL];
    [task updateStatusToLocal];
    
    //当afn不使用backgroundSessionConfigurationWithIdentifier时，下面的可以注释
//    if (_isStop) return;
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//        if (nil == _currentFileTask) {
//            //有可能不走completionHandler回调，所以这里启动一下
//            [self startNextDownloadTask];
//        }
//    });
}

- (void)completedDownloadFileTask:(FileTask *)fTask
{
//    [fTask updateStatusToLocal];
    
    NSMutableArray *fromArr;
    NSMutableArray *toArr;
    if (FileTaskStatusCompleted == fTask.state) {
        //如果是照片和视频就要保存到相册
        [self saveFileTask:fTask];
        fromArr = _fileTasks;
        toArr = _successTasks;
    } else if (FileTaskStatusError == fTask.state) {
        fromArr = _fileTasks;
        toArr = _failureTasks;
    }
    
    if (nil != fromArr && nil != toArr) {
        NSLog(@"完成下载一个");
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            NSLog(@"开始移动");
            XM_Lock(_lock_fileTasks);
            if (_delegate && [_delegate respondsToSelector:@selector(downloadManager:willMoveFileTaskToArr:)]) {
                [_delegate downloadManager:self willMoveFileTaskToArr:toArr];
            }
            NSUInteger fromIdx = [fromArr indexOfObject:fTask];
            NSUInteger toIdx = 0;
            [fromArr removeObject:fTask];
            [toArr insertObject:fTask atIndex:toIdx];
            if (_delegate && [_delegate respondsToSelector:@selector(downloadManager:didMoveFileTask:fromArr:fromIndex:toArr:toIdx:)]) {
                [_delegate downloadManager:self didMoveFileTask:fTask fromArr:fromArr fromIndex:fromIdx toArr:toArr toIdx:toIdx];
            }
            XM_UnLock(_lock_fileTasks);
        });
    }
    [self startNextDownloadTask];
}

- (void)startNextDownloadTask
{
    if (_isStop || nil != _downloadTask || nil != _currentFileTask) return;//还有任务正在下载
    
    XM_Lock(_lock_fileTasks);
    FileTask *ftask = nil;
    for (NSUInteger i = 0, count = _fileTasks.count; i < count; ++i) {
        ftask = _fileTasks[i];
        if (FileTaskStatusWaiting == ftask.state) {//挑一个在等待中的
            break;
        }
        ftask = nil;
    }
    XM_UnLock(_lock_fileTasks);
    BOOL isNO = YES;
    if (nil != ftask) {//有任务
//        [self downloadFileWithTask:ftask];
        [self downloadFileWithResume:ftask];
        isNO = NO;
    } else {
        isNO = _fileTasks.count > 0;//“>0”表示还有暂停的任务
    }
    if (_delegate && [_delegate respondsToSelector:@selector(downloadManager:noTasksBeingDownloaded:)]) {//没有可以下载的任务了
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [_delegate downloadManager:self noTasksBeingDownloaded:isNO];
        });
    }
}

#pragma mark - 通知任务的传输进度变化
- (void)notifyChangedForFileTask:(FileTask *)fileTask
{
    //_downloadManager中是非主线程调用
    if (_delegate && [_delegate respondsToSelector:@selector(downloadManager:didChangeFileTask:)]) {
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            XM_OnThreadSafe(_lock_fileTasks, [_delegate downloadManager:self didChangeFileTask:fileTask]);
        });
    }
}

#pragma mark - 把图片视频写入相册
- (void)saveFileTask:(FileTask *)ftask
{
    FileType type = ftask.filetype;//文件类型
    //如果不是图片或者视频就不要保存了
    if (FileType_Photo != type && FileType_Video != type) return;
    
    __weak FileTask *task = ftask;
    //1.
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        if (FileType_Photo == type) {
            PHAssetChangeRequest *request = [PHAssetCreationRequest creationRequestForAssetFromImageAtFileURL:[NSURL fileURLWithPath:[_docDir stringByAppendingPathComponent:task.localPath]]];
//            request.creationDate = //设置时间
//            request.location = //设置GPS坐标
            task.assetLocalIdentifier = request.placeholderForCreatedAsset.localIdentifier;
        } else {
            task.assetLocalIdentifier = [PHAssetCreationRequest creationRequestForAssetFromVideoAtFileURL:[NSURL fileURLWithPath:[_docDir stringByAppendingPathComponent:task.localPath]]].placeholderForCreatedAsset.localIdentifier;
        }
    } completionHandler:^(BOOL success, NSError * _Nullable error) {
        if (success) {
            if (!IsTextEmptyString(task.localPath)) {
                NSError *err = nil;
                [[NSFileManager defaultManager] removeItemAtPath:[_docDir stringByAppendingPathComponent:task.localPath] error:&err];
                task.localPath = nil;
                NSLog(@"媒体已保存到相册 -- %@", err);
            }
        } else {
            task.assetLocalIdentifier = nil;
            NSLog(@"媒体保存到相册失败, %@ -- %@", error, error.userInfo);
        }
        if (FileTaskStatusDeleted != task.state) {
            [task updateToLocal];
        }
        if (!success) return;
        
        // 2.获得相簿
        PHAssetCollection *myAssetCollection = [self fetchAssetCollection];
        if (myAssetCollection == nil) {
            NSLog(@"创建相簿失败!");
            return;
        }
        
        // 3.将刚刚添加到"相机胶卷"中的文件到"自己创建相簿"中
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            
            PHAsset *asset = [PHAsset fetchAssetsWithLocalIdentifiers:@[task.assetLocalIdentifier] options:nil].firstObject;//获得文件
            //添加图片到相簿中的请求
            PHAssetCollectionChangeRequest *request = [PHAssetCollectionChangeRequest changeRequestForAssetCollection:myAssetCollection];
            [request addAssets:@[asset]];//添加图片到相簿
            
        } completionHandler:^(BOOL success, NSError * _Nullable error) {
            if (success) {
                NSLog(@"保存图片到创建的相簿成功");
            } else {
                NSLog(@"保存图片到创建的相簿失败: %@", error);
            }
        }];
    }];
}

- (PHAssetCollection *)fetchAssetCollection
{
    //自定义相册名称
    static NSString *const customPHAssetCollectionName = @"server mobile";
    //判断是否已存在
    PHFetchResult<PHAssetCollection *> *assetCollections = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum subtype:PHAssetCollectionSubtypeAlbumRegular options:nil];
    for (PHAssetCollection * assetCollection in assetCollections) {
        if ([assetCollection.localizedTitle isEqualToString:customPHAssetCollectionName]) {
            //说明已经有哪对象了
            return assetCollection;
        }
    }
    
    //创建新的相簿
    __block NSString *assetCollectionLocalIdentifier = nil;
    NSError *error = nil;
    [[PHPhotoLibrary sharedPhotoLibrary] performChangesAndWait:^{//同步方法
        // 创建相簿的请求
        assetCollectionLocalIdentifier = [PHAssetCollectionChangeRequest creationRequestForAssetCollectionWithTitle:customPHAssetCollectionName].placeholderForCreatedAssetCollection.localIdentifier;
    } error:&error];
    
    if (error)return nil;
    
    return [PHAssetCollection fetchAssetCollectionsWithLocalIdentifiers:@[assetCollectionLocalIdentifier] options:nil].firstObject;
}

#pragma mark 恢复
//这个是给用户触屏操作调用
- (BOOL)resumeAll
{
    return [self resumeAllIsAuto:NO];
}

- (BOOL)resumeAllIsAuto:(BOOL)isAuto
{
    //改变状态
    XM_Lock(_lock_fileTasks);
    [_fileTasks enumerateObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(FileTask * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (FileTaskStatusPause == obj.state) obj.state = FileTaskStatusWaiting;
    }];
    XM_UnLock(_lock_fileTasks);
    if (!isAuto) {
        [FileTask updateFileTasks:_fileTasks];
    }
    //不一定执行下载
    if (//(_user.stopBackupAlbumWhenLowBattery && _device.batteryLevel < LowBatteryValue)
        _device.batteryLevel < LowBatteryMustStopValue//快关机了
        || UsersCannotUseTheNetwork(_nrm.networkReachabilityStatus, _user.loadOnWiFi))//用户不能使用网络
        return YES;//YES表示执行完毕，不会有回调
        
    if (nil == _currentFileTask) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self startNextDownloadTask];
        });
    }
    return NO;
}

//恢复
- (void)resumeFileTask:(FileTask *)ftask
{
    if (FileTaskStatusPause != ftask.state) return;
    ftask.state = FileTaskStatusWaiting;
    [ftask updateStatusToLocal];
    [self notifyChangedForFileTask:ftask];
    
    //不一定执行下载
    if (//(_user.stopBackupAlbumWhenLowBattery && _device.batteryLevel < LowBatteryValue)
        _device.batteryLevel < LowBatteryMustStopValue//快关机了
        || UsersCannotUseTheNetwork(_nrm.networkReachabilityStatus, _user.loadOnWiFi))//用户不能使用网络
        return;
        
    if (nil == _currentFileTask) {//当前没有下载
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self startNextDownloadTask];//启动一个新任务
        });
    }
}

#pragma mark 暂停
//这个是给用户触屏操作调用
- (BOOL)pauseAll
{
    BOOL hasNoCallBack = NO;
    if (nil == _downloadTask) {
        hasNoCallBack = YES;//不会有_downloadTask cancel回调，也就不会回调noTasksBeingDownloaded
    }
    [self pauseAllIsAuto:NO];
    
    return hasNoCallBack;
}

- (void)pauseAllIsAuto:(BOOL)isAuto
{
    if (_downloadTask) {//暂停当前
        _currentFileTask.state = FileTaskStatusPause;
        FileTask *task = _currentFileTask;
        __weak typeof(self) this = self;
        [_downloadTask cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
            //要想resumeData不为nil，响应头中必须有Etag或Last-modified(两者其一，或者都有)
//            [this mergeFile:task withResumeData:resumeData];
            [this saveTask:task withResumeData:resumeData];
        }];
        _downloadTask = nil;
        if (isAuto) {
            //能来这里说明_downloadTask的completionHandler还没回调，必须自己通知
            [self notifyChangedForFileTask:_currentFileTask];
        }
        _currentFileTask = nil;
    }
    XM_Lock(_lock_fileTasks);
    [_fileTasks enumerateObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(FileTask * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (FileTaskStatusWaiting == obj.state || FileTaskStatusInProgress == obj.state ) obj.state = FileTaskStatusPause;
    }];
    XM_UnLock(_lock_fileTasks);
    if (!isAuto) {
        [FileTask updateFileTasks:_fileTasks];
    }
}

//暂停
- (void)pauseFileTask:(FileTask *)ftask
{
    if (FileTaskStatusWaiting != ftask.state && FileTaskStatusInProgress != ftask.state) return;//既不是等待状态，也不是传输状态
    
    ftask.state = FileTaskStatusPause;
    [ftask updateStatusToLocal];
    if (ftask == _currentFileTask) {
        __weak typeof(self) this = self;
        [_downloadTask cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
            //要想resumeData不为nil，响应头中必须有Etag或Last-modified(两者其一，或者都有)
//            [this mergeFile:ftask withResumeData:resumeData];
            [this saveTask:ftask withResumeData:resumeData];
        }];//_downloadManager回调会有启动下一个任务
        _downloadTask = nil;
        _currentFileTask = nil;
    }
    [self notifyChangedForFileTask:ftask];
}

#pragma mark 删除
- (void)deleteAll
{
    if (_downloadTask) {//停止当前
        _currentFileTask.state = FileTaskStatusDeleted;
        [_downloadTask cancel];
        _currentFileTask = nil;
        _downloadTask = nil;
    }
    XM_Lock(_lock_fileTasks);
    NSFileManager *fm = [NSFileManager defaultManager];
    [FileTask deleteAllFileTasksForUser:_user forType:FileTaskTypeDownload];
    NSArray<NSArray<FileTask *> *> *arr = @[_fileTasks, _successTasks, _failureTasks];
    [arr enumerateObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(NSArray * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [obj enumerateObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(FileTask * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (!IsTextEmptyString(obj.localPath)) {
                [fm removeItemAtPath:[_docDir stringByAppendingPathComponent:obj.localPath] error:NULL];
            }
            if (!IsTextEmptyString(obj.resumeDataName)) {
                [fm removeItemAtPath:[self->_tmpDir stringByAppendingPathComponent:obj.resumeDataName] error:NULL];
            }
        }];
    }];
    [_fileTasks removeAllObjects];
    [_successTasks removeAllObjects];
    [_failureTasks removeAllObjects];
    XM_UnLock(_lock_fileTasks);
}

//删除
- (void)deleteFileTask:(FileTask *)ftask
{
    if (ftask == _currentFileTask) {
        _currentFileTask.state = FileTaskStatusDeleted;
        [_downloadTask cancel];
        _currentFileTask = nil;
        _downloadTask = nil;
    }
    XM_Lock(_lock_fileTasks);
    [_fileTasks removeObject:ftask];
    [_successTasks removeObject:ftask];
    [_failureTasks removeObject:ftask];
    XM_UnLock(_lock_fileTasks);
    
    [FileTask deleteFileTask:ftask];
    if (!IsTextEmptyString(ftask.localPath)) {
        [_fm removeItemAtPath:[_docDir stringByAppendingPathComponent:ftask.localPath] error:NULL];//这个会不会有其它的问题
    }
    if (!IsTextEmptyString(ftask.resumeDataName)) {
        [_fm removeItemAtPath:[_tmpDir stringByAppendingPathComponent:ftask.resumeDataName] error:NULL];
    }
}

- (void)deleteAllSelected
{
    if (_currentFileTask.isSelected) {
        _currentFileTask.state = FileTaskStatusDeleted;
        [_downloadTask cancel];
        _currentFileTask = nil;
        _downloadTask = nil;
    }
    XM_Lock(_lock_fileTasks);
    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableIndexSet *mis = [NSMutableIndexSet indexSet];
    NSMutableArray<NSNumber *> *ids = [NSMutableArray array];
    //使用2层数组循环，但不并发
    NSArray<NSMutableArray<FileTask *> *> *arr = @[_fileTasks, _successTasks, _failureTasks];
    for (NSMutableArray *obj in arr) {
        [obj enumerateObjectsUsingBlock:^(FileTask * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (!obj.isSelected) return;
            obj.state = FileTaskStatusDeleted;
            [mis addIndex:idx];
            [ids addObject:@(obj.Id)];//这里没办法用并发
            if (!IsTextEmptyString(obj.localPath)) {
                [fm removeItemAtPath:[_docDir stringByAppendingPathComponent:obj.localPath] error:NULL];
            }
            if (!IsTextEmptyString(obj.resumeDataName)) {
                [fm removeItemAtPath:[_tmpDir stringByAppendingPathComponent:obj.resumeDataName] error:NULL];
            }
        }];
        [obj removeObjectsAtIndexes:mis];
        [mis removeAllIndexes];
    }
    XM_UnLock(_lock_fileTasks);
    [FileTask deleteFileTaskWithIDs:ids];
}

#pragma mark - select
- (void)selectAllTasks
{
    NSArray<NSArray<FileTask *> *> *arr = @[_fileTasks, _successTasks, _failureTasks];
    XM_Lock(_lock_fileTasks);
    [arr enumerateObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(NSArray<FileTask *> * _Nonnull obj, NSUInteger idxs, BOOL * _Nonnull stop) {
        [obj enumerateObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(FileTask * _Nonnull task, NSUInteger idxr, BOOL * _Nonnull stop) {
            if (!task.isSelected) {
                task.selected = YES;
            }
        }];
    }];
    XM_UnLock(_lock_fileTasks);
}

- (void)deselectAllTasks
{
    XM_Lock(_lock_fileTasks);
    NSArray<NSArray<FileTask *> *> *arr = @[_fileTasks, _successTasks, _failureTasks];
    [arr enumerateObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(NSArray<FileTask *> * _Nonnull obj, NSUInteger idxs, BOOL * _Nonnull stop) {
        [obj enumerateObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(FileTask * _Nonnull task, NSUInteger idxr, BOOL * _Nonnull stop) {
            task.selected = NO;
        }];
    }];
    XM_UnLock(_lock_fileTasks);
}

- (BOOL)isAllPaused
{
    __block BOOL isAllPaused = YES;
    XM_Lock(_lock_fileTasks);
    [_fileTasks enumerateObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(FileTask * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (FileTaskStatusPause != obj.state) {
            isAllPaused = NO;
            *stop = YES;
        }
    }];
    XM_UnLock(_lock_fileTasks);
    return isAllPaused && _fileTasks.count > 0;
}

- (void)redownload:(FileTask *)fTask
{//这个应该是在主线程中调用
    if (FileTaskStatusError != fTask.state) return;
    NSMutableArray *fromArr = _failureTasks;
    NSMutableArray *toArr = _fileTasks;
    
    NSLog(@"开始移动");
    XM_Lock(_lock_fileTasks);
    if (_delegate && [_delegate respondsToSelector:@selector(downloadManager:willMoveFileTaskToArr:)]) {
        [_delegate downloadManager:self willMoveFileTaskToArr:toArr];
    }
    
    NSUInteger fromIdx = [fromArr indexOfObject:fTask];
    NSUInteger toIdx = toArr.count;
    [fromArr removeObject:fTask];
    fTask.state = FileTaskStatusWaiting;
    [fTask updateStatusToLocal];
    [toArr addObject:fTask];
    
    if (_delegate && [_delegate respondsToSelector:@selector(downloadManager:didMoveFileTask:fromArr:fromIndex:toArr:toIdx:)]) {
        [_delegate downloadManager:self didMoveFileTask:fTask fromArr:fromArr fromIndex:fromIdx toArr:toArr toIdx:toIdx];
    }
    XM_UnLock(_lock_fileTasks);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self startNextDownloadTask];
    });
}

@end
