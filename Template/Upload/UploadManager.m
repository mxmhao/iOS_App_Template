//
//  UploadManager.m
//  备份导出和上传导出不一样，上传导出可以选择原图或者压缩图，而备份都是原图

#import "UploadManager.h"
#import <AFNetworking/AFNetworking.h>
#import "User.h"
#import "FileTask.h"
#import "NSTimer+Block.h"
#import "UIImage+fixOrientation.h"
#import "XMLock.h"
#import "UIImage+Format.h"
#import "DeviceNetworkManager.h"
#import "XMPhotosRequestManager.h"
#import <objc/runtime.h>
#import "XMPhotosRequestManager+Utils.h"

static NSString *const OutputDir = @"upload";

@interface PHAsset (Data)

@property (nonatomic, weak) FileTask *task;//状态

@end

@implementation PHAsset (Data)

- (void)setTask:(FileTask *)task
{
    objc_setAssociatedObject(self, @selector(task), task, OBJC_ASSOCIATION_ASSIGN);
}

- (FileTask *)task
{
    return objc_getAssociatedObject(self, @selector(task));
}

@end

@interface UploadManager () <XMPhotosRequestManagerDelegate>

@end

@implementation UploadManager
{
    User *_user;
    UIDevice *_device;
    AFHTTPSessionManager *_httpManager;
    NSMutableArray<FileTask *> *_fileTasks;     //任务列表
    NSMutableArray<FileTask *> *_successTasks;  //成功任务列表
    NSMutableArray<FileTask *> *_failureTasks;  //失败任务列表
    
    FileTask *_currentUploadTask;   //当前正在上传的task
    NSURLSessionDataTask *_dataTask;//正在上传的任务
    
    XMLock _lock_fileTasks;
//    NSCondition *_condition;//睡眠和唤醒使用
    BOOL _isLowBattery;//低电量
    
    DeviceNetworkManager *_dnm;
    AFNetworkReachabilityManager *_nrm;
    
    //?
    XMPhotosRequestManager *_prm;
    NSUInteger _existFileCount;
    XMLock _lock_existFileCount;
    NSString *_tempDir;
    NSString *_outputAbsolutePath;
    NSFileManager *_fm;
}

- (NSArray<FileTask *> *)uploadingTasks
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

static UploadManager *manager = nil;
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

static NSTimeInterval const TimeRepeat = 1800.000000;//30分钟

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    NSLog(@"UploadManager -- 释放");
}

- (instancetype)initWithUser:(User *)user
{
    if (nil == user) return nil;
    
    self = [super init];
    if (self) {
        _user = user;
        _lock_fileTasks = XM_CreateLock();
        _dnm = [DeviceNetworkManager new];
        _nrm = [AFNetworkReachabilityManager sharedManager];
        
        _tempDir = NSTemporaryDirectory();
//        _tempDir = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
        _outputAbsolutePath = [_tempDir stringByAppendingPathComponent:OutputDir];
        BOOL isDir = NO;
        _fm = [NSFileManager defaultManager];
        if (![_fm fileExistsAtPath:_outputAbsolutePath isDirectory:&isDir] || !isDir) {
            [_fm createDirectoryAtPath:_outputAbsolutePath withIntermediateDirectories:YES attributes:nil error:NULL];
        }
        
        //其它参数用默认的
        PHVideoRequestOptions *voptions = [PHVideoRequestOptions new];
        voptions.deliveryMode = PHVideoRequestOptionsDeliveryModeHighQualityFormat;
        voptions.networkAccessAllowed = YES;
        
        //其它参数用默认的
        PHImageRequestOptions *ioptions = [PHImageRequestOptions new];
        ioptions.resizeMode = PHImageRequestOptionsResizeModeExact;
        ioptions.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
        ioptions.networkAccessAllowed = YES;
        //?
        _prm = [[XMPhotosRequestManager alloc] initWithCacheDir:_outputAbsolutePath];
        _prm.delegate = self;
        _prm.videoOptions = voptions;
        _prm.imageOptions = ioptions;
        _prm.videoExportPreset = AVAssetExportPresetPassthrough;//不压缩，一切按原有的参数
        _lock_existFileCount = XM_CreateLock();
        _existFileCount = 0;
        
        [self initFileTasks];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(logout) name:UIApplicationWillTerminateNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(logout) name:UserLogoutNotification object:nil];
    }
    return self;
}

- (void)initFileTasks
{
    _fileTasks = [NSMutableArray array];
    _successTasks = [NSMutableArray array];
    _failureTasks = [NSMutableArray array];
    [FileTask createTable];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [_fileTasks addObjectsFromArray:[FileTask progressFileTasksForUser:_user taskType:FileTaskTypeUpload]];
        
        NSMutableArray *noPHAssetTasks = [NSMutableArray array];
        //可能会更新FileTask，所以要放在下面两个获取之前
        NSArray *arr = [self fetchAssetsForFileTasks:_fileTasks addNoPHAssetFileTasks:noPHAssetTasks];
        [_fileTasks removeObjectsInArray:noPHAssetTasks];
        
        [_successTasks addObjectsFromArray:[FileTask successFileTasksForUser:_user taskType:FileTaskTypeUpload]];
        [_failureTasks addObjectsFromArray:[FileTask failureFileTasksForUser:_user taskType:FileTaskTypeUpload]];
        
        //?
        [_prm addPHAssets:arr];
        
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            if (_fileTasks.count > 0) {
                [self prepareForTask];
                [self startUploadTask];
            }
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityStatusChanged:) name:NetworkUsableDidChangeNotification object:nil];//AFNetworkingReachabilityDidChangeNotification
        });
    });
}


/**
 获取PHAsset，把没有PHAsset的FileTask的state设置为FileTaskStatusError，<br/>
 并且存放到noPHAssetTasks中

 @param tasks FileTask数组
 @param noPHAssetTasks 存放没有PHAsset的FileTask
 @return PHAsset数组
 */
- (NSArray<PHAsset *> *)fetchAssetsForFileTasks:(nullable NSMutableArray<FileTask *> *)tasks addNoPHAssetFileTasks:(nullable NSMutableArray<FileTask *> *)noPHAssetTasks
{
    NSMutableArray<PHAsset *> *assets = [NSMutableArray arrayWithCapacity:tasks.count];
    PHAsset *asset = nil;
    FileTask *ftask = nil;
    for (NSUInteger i = 0, count = tasks.count; i < count; ++i) {
        ftask = tasks[i];
        switch (ftask.state) {
            case FileTaskStatusWaiting:
            case FileTaskStatusExporting:
            case FileTaskStatusExported:
            case FileTaskStatusInProgress:
            case FileTaskStatusPause:
                if (!IsTextEmptyString(ftask.localPath) && [_fm fileExistsAtPath:[_tempDir stringByAppendingPathComponent:ftask.localPath]]) {
                    ftask.state = FileTaskStatusExported;
                    XM_OnThreadSafe(_lock_existFileCount, ++_existFileCount);
                } else {
                    asset = [PHAsset fetchAssetsWithLocalIdentifiers:@[ftask.assetLocalIdentifier] options:nil].firstObject;
                    if (nil == asset) {
                        ftask.state = FileTaskStatusError;
                        [ftask updateStatusToLocal];
                        if (nil != noPHAssetTasks) [noPHAssetTasks addObject:ftask];
                        continue;
                    }
                    ftask.asset = asset;
                    asset.task = ftask;
                    [assets addObject:asset];
                    ftask.state = FileTaskStatusWaiting;
                }
                break;
                
            default:
                break;
        }
    }
    return assets;
}

//当用户退出登录是要保存
- (void)logout
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (_dataTask) {//暂停当前
        _currentUploadTask.state = FileTaskStatusWaiting;
        [_dataTask cancel];
        [_currentUploadTask.fileHandle closeFile];
        _currentUploadTask.fileHandle = nil;
        _dataTask = nil;
//        [self clearUpLoadCache:_currentUploadTask];
        _currentUploadTask = nil;
    }
    
    XM_Lock(_lock_fileTasks);
    if (_fileTasks && _fileTasks.count > 0) {
        [FileTask updateFileTasks:_fileTasks];
        [_fileTasks removeAllObjects];
    }
    [_successTasks removeAllObjects];
    [_failureTasks removeAllObjects];
    XM_UnLock(_lock_fileTasks);
    
    [_prm stopRequest];//?
//    [_fm removeItemAtPath:_outputAbsolutePath error:NULL];
    
    _delegate = nil;
    _dnm = nil;
    _nrm = nil;
    _prm = nil;
    _user = nil;
    _device = nil;
    _httpManager = nil;
    onceToken = 0;
    manager = nil;//这个放到最后一行
}

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

//网络监听
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
    
    if (UsersCannotUseTheNetwork([noti.userInfo[AFNetworkingReachabilityNotificationStatusItem] integerValue], _user.loadOnWiFi)) {
        [self pauseAllIsAuto:YES];
    } else {
        if (_user.isPauseAllUpload || _device.batteryLevel <= LowBatteryMustStopValue)//用户自己暂停的，或者电量太低
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
    if (//(_user.stopBackupAlbumWhenLowBattery && _device.batteryLevel < LowBatteryValue)
        _device.batteryLevel <= LowBatteryMustStopValue) {//电量过低
        if (_isLowBattery) return;//防止下面的重复执行
        
        _isLowBattery = YES;
        [self pauseAllIsAuto:YES];
    } else {
        if (!_isLowBattery) return;//防止下面的重复执行
        _isLowBattery = NO;
        if (_user.isPauseAllUpload || UsersCannotUseTheNetwork(_nrm.networkReachabilityStatus, _user.loadOnWiFi))//用户自己暂停的，或者不符合传输网络
            return;
        
        [self resumeAllIsAuto:YES];
    }
}

#pragma mark - 导出
- (BOOL)uploadPHAsset:(NSArray<PHAsset *> *)assets toserverDirectory:(NSString *)directory;
{
    if (nil == assets || assets.count == 0 || nil == directory || directory.length == 0) return NO;
    
@autoreleasepool {
    NSInteger maxId = [FileTask fileTaskMaxId];
    //先组装FileTask
    NSMutableArray<FileTask *> *tasks = [NSMutableArray arrayWithCapacity:assets.count];
    FileTask *ftask = nil;
    for (PHAsset *ast in assets) {
        ftask = [[FileTask alloc] initForInsert];
        ftask.fileName = [ast valueForKey:@"filename"];
        ftask.fileExt = [ftask.fileName pathExtension];
        ftask.mediaType = ast.mediaType;
        ftask.createTime = ast.modificationDate.timeIntervalSince1970;
        ftask.assetLocalIdentifier = ast.localIdentifier;
        ftask.filetype = ast.mediaType == PHAssetMediaTypeImage? FileType_Photo : FileType_Video;
        
        ftask.mac = _user.mac;
        ftask.userId = _user.Id;
        ftask.serverPath = [directory stringByAppendingPathComponent:ftask.fileName];
        ftask.state = FileTaskStatusWaiting;
        ftask.type = FileTaskTypeUpload;
        [tasks addObject:ftask];
    }
    if (![FileTask addFileTasks:tasks]) {//保存到数据库
        NSLog(@"添加失败");
        return NO;
    }
    NSLog(@"添加成功");
//    NSArray *arr1 = [FileTask progressFileTasksForUser:_user taskType:FileTaskTypeUpload offset:_fileTasks.count];//这个offset有问题
    //另一种解决方案
    NSMutableArray *arr = (NSMutableArray *)[FileTask progressFileTasksForUser:_user taskType:FileTaskTypeUpload idGreaterThan:maxId];
    NSMutableArray *noPHAssetTasks = [NSMutableArray array];
    NSArray *asts = [self fetchAssetsForFileTasks:arr addNoPHAssetFileTasks:noPHAssetTasks];//?
    if (noPHAssetTasks.count > 0) {
        XM_Lock(_lock_fileTasks);
        [_failureTasks replaceObjectsInRange:NSMakeRange(0, 0) withObjectsFromArray:noPHAssetTasks];//放在最上面
        if (_delegate && [_delegate respondsToSelector:@selector(uploadManager:didAddNewFileTasks:)]) {
            [_delegate uploadManager:self didAddNewFileTasks:_failureTasks];
        }
        XM_UnLock(_lock_fileTasks);
        [arr removeObjectsInArray:noPHAssetTasks];
    }
    if (asts.count == 0) return YES;
    
//    NSLog(@"-->%lu", (unsigned long)arr.count);
    XM_OnThreadSafe(_lock_fileTasks, [_fileTasks addObjectsFromArray:arr]);
    
    if (_delegate && [_delegate respondsToSelector:@selector(uploadManager:didAddNewFileTasks:)]) {
        XM_OnThreadSafe(_lock_fileTasks, [_delegate uploadManager:self didAddNewFileTasks:_fileTasks]);
    }
    
    [_prm addPHAssets:asts];
    [self prepareForTask];
    [self startUploadTask];
}//autoreleasepool
    return YES;
}

//开始上传
- (void)startUploadTask
{
    if (_device.batteryLevel < LowBatteryMustStopValue//快关机了
        || UsersCannotUseTheNetwork(_nrm.networkReachabilityStatus, _user.loadOnWiFi))//开启了WiFi传输设置，而当前不是WiFi网络
        return;
    
    if (nil == _httpManager) {
#warning 请仔细阅读注释
        /*
         在info.plist中设置后台模式
         设置后台NSURLSessionConfiguration的NSURLSession在App的生命周期内同一个Identifier只能有
         一个，不能new新的，而且Identifier必须唯一，不能和其他App的冲突，后台上传下载都是如此，而且，
         只有对NSURLSessionDownloadTask和NSURLSessionUploadTask才有效，其他的无效
         */
        //[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"min.test.DownloadManager"] 若没有杀死当前app，在第二次new时，这个会导致cancelByProducingResumeData是不会回调completionHandler，我疯了🤣
        _httpManager = [[AFHTTPSessionManager alloc] initWithBaseURL:nil sessionConfiguration:[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"min.test.UploadManager"]];
        
        //初始化并设置认证
//        _httpManager = [AFHTTPSessionManager manager];
//        _httpManager.completionQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    }
    
    if (_existFileCount > 0) {
        [self startNextUploadTask];
    } else {
        [_prm startRequest];
    }
}

static uint64_t const UploadFragmentSize = 67108864;//64MB//8388608;//8MB//10485760;//10MB
#pragma mark 文件分块
- (void)divideTask:(FileTask *)task
{
    NSDictionary *attrDic = [_fm attributesOfItemAtPath:[_tempDir stringByAppendingPathComponent:task.localPath] error:nil];
    task.size = [attrDic fileSize];
    task.completedSize = 0;
    // 块数
    task.totalFragment = (int)(task.size % UploadFragmentSize == 0? task.size/UploadFragmentSize: task.size/UploadFragmentSize + 1);
    task.currentFragment = 0;
}

#pragma mark - 上传文件
- (void)uploadFileWithTask:(FileTask *)fTask
{
    static NSString *const videoMinetype = @"video/quicktime";
    static NSString *const imageMinetype = @"image/png";
    
    if (FileTaskStatusInProgress != fTask.state && FileTaskStatusExported != fTask.state) {//不能上传
        [self startNextUploadTask];
        return;
    }
    
    if (IsTextEmptyString(fTask.localPath) || ![_fm fileExistsAtPath:[_tempDir stringByAppendingPathComponent:fTask.localPath]]) {
        NSLog(@"文件不存在");
        fTask.state = FileTaskStatusError;
        [self completedUploadFileTask:fTask];
        return;
    }
    _currentUploadTask = fTask;
    if (nil == fTask.fileHandle) {
        fTask.fileHandle = [NSFileHandle fileHandleForReadingAtPath:[_tempDir stringByAppendingPathComponent:fTask.localPath]];
    }
    NSString *urlstr = [HttpUpLoadFileUrl stringByReplacingOccurrencesOfString:@"[ip]:[port]" withString:baseURL];
    NSDictionary * params = @{
        @"chunk": @(fTask.currentFragment),//当前是第几个片段, 从0开始
        @"chunks": @(fTask.totalFragment),//一共多少个片段
        @"saveTo": fTask.serverPath,//保存到哪里
        @"date": [NSString stringWithFormat:@"%.0f", fTask.createTime*1000],//文件创建日期
    };
    
    NSString *mimetype = nil;
    if (fTask.mediaType == PHAssetMediaTypeVideo) {
        mimetype = videoMinetype;
    } else if (fTask.mediaType == PHAssetMediaTypeImage) {
        mimetype = imageMinetype;
    }
    fTask.state = FileTaskStatusInProgress;
    
    __weak typeof(self) this = self;
    __block uint64_t lastCompleted = 0;
    __block uint64_t lastBytes = 0;
    __block NSTimeInterval lastTime = CACurrentMediaTime();
    _dataTask = [_httpManager POST:urlstr parameters:params constructingBodyWithBlock:^(id<AFMultipartFormData> _Nonnull formData) {//数据加载
        NSData *data = nil;
        if (fTask.totalFragment > 1) {
            fTask.completedSize = fTask.currentFragment * UploadFragmentSize;
        } else {
            fTask.completedSize = 0;
        }
        [fTask.fileHandle seekToFileOffset:fTask.completedSize];
        if (fTask.currentFragment < fTask.totalFragment - 1) {//不是最后一个片段了
            data = [fTask.fileHandle readDataOfLength:UploadFragmentSize];
        } else {
            data = [fTask.fileHandle readDataToEndOfFile];
        }
        
        [formData appendPartWithFileData:data name:@"file" fileName:fTask.fileName mimeType:mimetype];
        
    } progress:^(NSProgress * _Nonnull uploadProgress) {
        fTask.completedSize += uploadProgress.completedUnitCount - lastCompleted;//获取增量
        lastCompleted = uploadProgress.completedUnitCount;
        NSTimeInterval spaceTime = CACurrentMediaTime() - lastTime;
        if (spaceTime < 0.950000) return;//时间太短
        if (spaceTime > 1.100000) {//精确处理
            fTask.transmissionSpeed = (lastCompleted - lastBytes)/spaceTime;
        } else {//粗略处理
            fTask.transmissionSpeed = lastCompleted - lastBytes;
        }
        [this notifyChangedForFileTask:fTask];
        lastBytes = lastCompleted;
        lastTime = CACurrentMediaTime();
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        NSTimeInterval spaceTime = CACurrentMediaTime() - lastTime;
        fTask.currentFragment++;
        [this setCurrentUploadTaskNil];
        if (fTask.currentFragment <= fTask.totalFragment - 1) {//还有片段上传
            if (FileTaskStatusPause == fTask.state) {//当前暂停了
                [this startNextUploadTask];
                return;
            }
            fTask.transmissionSpeed = (lastCompleted - lastBytes)/spaceTime;
            [this notifyChangedForFileTask:fTask];
            [this uploadFileWithTask:fTask];//上传下一个片段
        } else {
            fTask.state = FileTaskStatusCompleted;
            [this completedUploadFileTask:fTask];
        }
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [this setCurrentUploadTaskNil];
        if ([NSURLErrorDomain isEqualToString:error.domain]) {
            if (error.code == NSURLErrorNetworkConnectionLost || error.code == NSURLErrorTimedOut) {//断网了
                fTask.state = FileTaskStatusPause;
                [fTask updateStatusToLocal];
                [this notifyChangedForFileTask:fTask];
//                [this clearUpLoadCache:fTask];//网断了，此行调用无效
                return;
            }
            if (error.code == NSURLErrorCancelled && (FileTaskStatusDeleted == fTask.state || FileTaskStatusPause == fTask.state)) {//自己取消引发的错误
                [this startNextUploadTask];
                return;
            }
        }
        if (fTask.canUpload) {//还有一次机会
            fTask.canUpload = NO;
            [this uploadFileWithTask:fTask];
        } else {
            fTask.state = FileTaskStatusError;
            [this completedUploadFileTask:fTask];
        }
    }];
}

- (void)setCurrentUploadTaskNil
{
    _dataTask = nil;
    _currentUploadTask = nil;
}

- (void)completedUploadFileTask:(FileTask *)fTask
{
    [fTask.fileHandle closeFile];
    fTask.fileHandle = nil;
    //完成后立刻删除临时文件
    if (!IsTextEmptyString(fTask.localPath)) {
        XM_Lock(_lock_existFileCount);
        if ([_fm removeItemAtPath:[_tempDir stringByAppendingPathComponent:fTask.localPath] error:NULL]) --_existFileCount;
        XM_UnLock(_lock_existFileCount);
    }
    
    NSMutableArray *fromArr = nil;
    NSMutableArray *toArr = nil;
    
    if (FileTaskStatusCompleted == fTask.state) {
        NSLog(@"上传成功一个");
        fromArr = _fileTasks;
        toArr = _successTasks;
    } else if (FileTaskStatusError == fTask.state) {
        [self clearUpLoadCache:fTask];//有错误就清除缓存
        fromArr = _fileTasks;
        toArr = _failureTasks;
    }
//    if (FileTaskStatusDeleted != fTask.state)
    [fTask updateStatusToLocal];//保存到数据库
    
    if (nil != fromArr && nil != toArr) {
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            XM_Lock(_lock_fileTasks);
            if (_delegate && [_delegate respondsToSelector:@selector(uploadManager:willMoveFileTaskToArr:)]) {
                [_delegate uploadManager:self willMoveFileTaskToArr:toArr];
            }
            NSUInteger fromIdx = [fromArr indexOfObject:fTask];
            NSUInteger toIdx = 0;
            [toArr insertObject:fTask atIndex:toIdx];
            [fromArr removeObject:fTask];
            if (_delegate && [_delegate respondsToSelector:@selector(uploadManager:didMoveFileTask:fromArr:fromIndex:toArr:toIdx:)]) {
                [_delegate uploadManager:self didMoveFileTask:fTask fromArr:fromArr fromIndex:fromIdx toArr:toArr toIdx:toIdx];
            }
            XM_UnLock(_lock_fileTasks);
        });
    }
    [self startNextUploadTask];
}

- (void)startNextUploadTask
{
    if (nil != _dataTask || nil != _currentUploadTask) return;
    
    XM_Lock(_lock_fileTasks);
    FileTask *ftask = nil;
    for (NSUInteger i = 0, count = _fileTasks.count; i < count; ++i) {
        ftask = _fileTasks[i];
        if (FileTaskStatusExported == ftask.state) {//挑一个在已导出的
            break;
        }
        ftask = nil;
    }
    XM_UnLock(_lock_fileTasks);
    if (nil != ftask) {
        [self uploadFileWithTask:ftask];
    } else {//没有需要上传的，就继续导出
        if (_existFileCount < 2) {
            [_prm startRequest];
        }
    }
}

//清除server上的上传缓存
- (void)clearUpLoadCache:(FileTask *)ftask
{
    ftask.completedSize = 0;
    ftask.currentFragment = 0;
    NSDictionary *params = @{@"saveTo": ftask.serverPath};
    NSString *url = [HttpClearUpLoadCache stringByReplacingOccurrencesOfString:@"[ip]:[port]" withString:baseURL];
    [_httpManager POST:url parameters:params progress:nil success:nil failure:nil];
}

#pragma mark - 通知任务的传输进度变化
- (void)notifyChangedForFileTask:(FileTask *)fileTask
{
//    NSLog(@"isMain %d", [NSThread isMainThread]);
    if (_delegate && [_delegate respondsToSelector:@selector(uploadManager:didChangeFileTask:)]) {
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            XM_OnThreadSafe(_lock_fileTasks, [_delegate uploadManager:self didChangeFileTask:fileTask]);
        });
    }
}

#pragma mark 恢复
//这个是给用户触屏操作调用
- (void)resumeAll
{
    [self resumeAllIsAuto:NO];
}

- (void)resumeAllIsAuto:(BOOL)isAuto
{
    XM_Lock(_lock_fileTasks);
    BOOL isDir = YES;
    FileTask *ftask = nil;
    for (FileTask *ftask in _fileTasks) {
        if (FileTaskStatusPause == ftask.state) {
            if (ftask != _currentUploadTask) {
                ftask.state = FileTaskStatusWaiting;
            }
            if (!IsTextEmptyString(ftask.localPath) && [_fm fileExistsAtPath:[_tempDir stringByAppendingPathComponent:ftask.localPath] isDirectory:&isDir] && !isDir) {
                ftask.state = FileTaskStatusExported;
                [self divideTask:ftask];
            }
        }
    }
    XM_UnLock(_lock_fileTasks);
    if (!isAuto) {
        [FileTask updateFileTasks:_fileTasks];
    }
    
    if (//(_user.stopBackupAlbumWhenLowBattery && _device.batteryLevel < LowBatteryValue)
        _device.batteryLevel < LowBatteryMustStopValue//快关机了
        || UsersCannotUseTheNetwork(_nrm.networkReachabilityStatus, _user.loadOnWiFi))
        return;
    
    [_prm resumeAll];//?
    if (nil == _dataTask) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self startNextUploadTask];
        });
    }
}

- (void)resumeFileTask:(FileTask *)ftask
{//这里要不要考虑wifi和电量问题
    if (FileTaskStatusPause != ftask.state) return;
    [_prm resume:ftask.asset];//?
    
    BOOL isDir = YES;
    if (!IsTextEmptyString(ftask.localPath) && [_fm fileExistsAtPath:[_tempDir stringByAppendingPathComponent:ftask.localPath] isDirectory:&isDir] && !isDir) {
        ftask.state = FileTaskStatusExported;
        [self divideTask:ftask];
    } else {
        ftask.state = FileTaskStatusWaiting;
    }
    [ftask updateStatusToLocal];
    [self notifyChangedForFileTask:ftask];
    if (nil == _dataTask) {//当前没有正在上传的
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self startNextUploadTask];
        });
    }//有就不用管了
}

#pragma mark 暂停
//这个是给用户触屏操作调用
- (void)pauseAll
{
    [self pauseAllIsAuto:NO];
}

- (void)pauseAllIsAuto:(BOOL)isAuto
{
    if (_dataTask) {//暂停当前
        _currentUploadTask.state = FileTaskStatusPause;
        [_dataTask cancel];
        [_currentUploadTask.fileHandle closeFile];
        _currentUploadTask.fileHandle = nil;
        _dataTask = nil;
//        [self clearUpLoadCache:_currentUploadTask];
        if (isAuto) {
            //来到这里，说明_dataTask还没错误回调，就必须自己发送通知
            [self notifyChangedForFileTask:_currentUploadTask];
        }
        _currentUploadTask = nil;
    }
    
    XM_Lock(_lock_fileTasks);
    for (FileTask *ftask in _fileTasks) {
        switch (ftask.state) {
            case FileTaskStatusWaiting:
            case FileTaskStatusExporting:
            case FileTaskStatusExported:
            case FileTaskStatusInProgress:
                ftask.state = FileTaskStatusPause;
                break;
                
            default:
                break;
        }
    }
    XM_UnLock(_lock_fileTasks);
    [_prm pauseAll];//?
    
    if (!isAuto) {//非自动暂停
        [FileTask updateFileTasks:_fileTasks];
    }
}

- (void)pauseFileTask:(FileTask *)ftask
{
    switch (ftask.state) {
        case FileTaskStatusPause:
        case FileTaskStatusCompleted:
        case FileTaskStatusError:
        case FileTaskStatusDeleted:
            return;//不能暂停
            break;
            
        default:
            break;
    }
    
    [_prm pause:ftask.asset];//?
    ftask.state = FileTaskStatusPause;
    if (ftask == _currentUploadTask) {//若是当前任务
        [_dataTask cancel];//block回调会开始下一个任务
        [_currentUploadTask.fileHandle closeFile];
        _currentUploadTask.fileHandle = nil;
        _dataTask = nil;
        _currentUploadTask = nil;
//        [self clearUpLoadCache:ftask];
        [self notifyChangedForFileTask:ftask];
    }
    if (!IsTextEmptyString(ftask.localPath)) {
//        XM_Lock(_lock_existFileCount);
//        if ([_fm removeItemAtPath:[_tempDir stringByAppendingPathComponent:ftask.localPath] error:NULL]) --_existFileCount;
//        XM_UnLock(_lock_existFileCount);
    }
    
    [ftask updateStatusToLocal];
    [self notifyChangedForFileTask:ftask];
}

#pragma mark 删除
- (void)deleteAll
{
    if (_dataTask) {
        _currentUploadTask.state = FileTaskStatusDeleted;
        [_dataTask cancel];
        _dataTask = nil;
        [_currentUploadTask.fileHandle closeFile];
        _currentUploadTask.fileHandle = nil;
        [self clearUpLoadCache:_currentUploadTask];
        _currentUploadTask = nil;
    }
    
    [_prm stopRequest];//?
    //删除任务
    XM_Lock(_lock_fileTasks);
    [_fileTasks removeAllObjects];
    [_successTasks removeAllObjects];
    [_failureTasks removeAllObjects];
    XM_UnLock(_lock_fileTasks);
    
    XM_Lock(_lock_existFileCount);
    //删除整个文件夹，然后重建
    [_fm removeItemAtPath:_outputAbsolutePath error:NULL];
    [_fm createDirectoryAtPath:_outputAbsolutePath withIntermediateDirectories:YES attributes:nil error:NULL];
    _existFileCount = 0;
    XM_UnLock(_lock_existFileCount);
    
    [FileTask deleteAllFileTasksForUser:_user forType:FileTaskTypeUpload];
}

- (void)deleteFileTask:(FileTask *)ftask
{
    if (ftask == _currentUploadTask) {
        ftask.state = FileTaskStatusDeleted;
        [_dataTask cancel];//block回调会继续调用上传下一个任务
        _dataTask = nil;
        [_currentUploadTask.fileHandle closeFile];
        _currentUploadTask = nil;
        [self clearUpLoadCache:ftask];
    }
    XM_Lock(_lock_fileTasks);
    if (nil != ftask.asset && [_fileTasks containsObject:ftask]) [_prm deletePHAssets:@[ftask.asset]];//?
    [_fileTasks removeObject:ftask];
    [_successTasks removeObject:ftask];
    [_failureTasks removeObject:ftask];
    XM_UnLock(_lock_fileTasks);
    
    [FileTask deleteFileTask:ftask];
    
    if (!IsTextEmptyString(ftask.localPath)) {
        XM_Lock(_lock_existFileCount);
        if ([_fm removeItemAtPath:[_tempDir stringByAppendingPathComponent:ftask.localPath] error:NULL]) --_existFileCount;
        XM_UnLock(_lock_existFileCount);
    }
}

- (void)deleteAllSelected
{
    if (_currentUploadTask.isSelected) {
        _currentUploadTask.state = FileTaskStatusDeleted;
        [_dataTask cancel];
        _dataTask = nil;
        [_currentUploadTask.fileHandle closeFile];
        _currentUploadTask.fileHandle = nil;
        [self clearUpLoadCache:_currentUploadTask];
        _currentUploadTask = nil;
    }
    
    //删除将要导出的
    NSMutableIndexSet *mis = [NSMutableIndexSet indexSet];
    //删除任务
    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableArray<PHAsset *> *assets = [NSMutableArray arrayWithCapacity:_fileTasks.count];
    NSMutableArray<NSNumber *> *ids = [NSMutableArray array];
    XM_Lock(_lock_fileTasks);
    //要上传的
    [_fileTasks enumerateObjectsUsingBlock:^(FileTask * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (!obj.isSelected) return;
        [ids addObject:@(obj.Id)];
        if (!IsTextEmptyString(obj.localPath)) {
            XM_Lock(_lock_existFileCount);
            if ([fm removeItemAtPath:[_tempDir stringByAppendingPathComponent:obj.localPath] error:NULL]) --_existFileCount;
            XM_UnLock(_lock_existFileCount);
        }
        [mis addIndex:idx];
        [assets addObject:obj.asset];
    }];
    [_fileTasks removeObjectsAtIndexes:mis];
    [mis removeAllIndexes];
    [_prm deletePHAssets:assets];//?
    
    //上传成功的
    [_successTasks enumerateObjectsUsingBlock:^(FileTask * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.isSelected) {
            [ids addObject:@(obj.Id)];
            [mis addIndex:idx];
        }
    }];
    [_successTasks removeObjectsAtIndexes:mis];
    [mis removeAllIndexes];
    
    //上传失败的
    [_failureTasks enumerateObjectsUsingBlock:^(FileTask * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.isSelected) {
            [ids addObject:@(obj.Id)];
            [mis addIndex:idx];
        }
    }];
    [_failureTasks removeObjectsAtIndexes:mis];
    [mis removeAllIndexes];
    XM_UnLock(_lock_fileTasks);
    
    [FileTask deleteFileTaskWithIDs:ids];
}

#pragma mark - select
- (void)selectAllTasks
{
    XM_Lock(_lock_fileTasks);
    NSArray<NSArray<FileTask *> *> *arr = @[_fileTasks, _successTasks, _failureTasks];
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

- (BOOL)reupload:(FileTask *)fTask
{//这个应该在主线程中调用
    if (FileTaskStatusError != fTask.state) return NO;
    NSArray *arr = [self fetchAssetsForFileTasks:[NSMutableArray arrayWithObject:fTask] addNoPHAssetFileTasks:nil];
    if (arr.count == 0) return NO;
    
    NSMutableArray *fromArr = _failureTasks;
    NSMutableArray *toArr = _fileTasks;
    fTask.completedSize = 0;
    fTask.currentFragment = 0;
    fTask.canUpload = YES;
    
//    dispatch_async(dispatch_get_main_queue(), ^(void) {
        XM_Lock(_lock_fileTasks);
        if (_delegate && [_delegate respondsToSelector:@selector(uploadManager:willMoveFileTaskToArr:)]) {
            [_delegate uploadManager:self willMoveFileTaskToArr:toArr];
        }
        NSUInteger fromIdx = [fromArr indexOfObject:fTask];
        NSUInteger toIdx = toArr.count;
        [fromArr removeObject:fTask];
        fTask.state = FileTaskStatusWaiting;
        [fTask updateStatusToLocal];//保存到数据库
        [toArr addObject:fTask];
        [_prm addPHAssets:arr];
        if (_delegate && [_delegate respondsToSelector:@selector(uploadManager:didMoveFileTask:fromArr:fromIndex:toArr:toIdx:)]) {
            [_delegate uploadManager:self didMoveFileTask:fTask fromArr:fromArr fromIndex:fromIdx toArr:toArr toIdx:toIdx];
        }
        XM_UnLock(_lock_fileTasks);
//    });
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self startNextUploadTask];
    });
    return YES;
}

#pragma mark - XMPhotosRequestManager delegate
- (void)manager:(XMPhotosRequestManager *)manager willRequest:(PHAsset *)asset
{
    if (FileTaskStatusWaiting == asset.task.state)
        asset.task.state = FileTaskStatusExporting;
}

- (void)manager:(XMPhotosRequestManager *)manager customPropertyForExportSession:(AVAssetExportSession *)exportSession
{
    exportSession.outputFileType = AVFileTypeMPEG4;
    exportSession.shouldOptimizeForNetworkUse = YES;
    //AVAssetExportPresetPassthrough设置后，以下设置无效
//    AVMutableVideoComposition *videoComposition = [XMPhotosRequestManager fixedCompositionWithAsset:exportSession.asset];
//    if (videoComposition.renderSize.width) {// 修正视频转向
//        exportSession.videoComposition = videoComposition;
//    }
}

- (nullable NSData *)manager:(XMPhotosRequestManager *)manager editImageData:(NSData *)imageData asset:(PHAsset *)asset dataUTI:(NSString *)dataUTI orientation:(UIImageOrientation)orientation
{
    NSData *data = imageData;
    if ([UIImage isHEIF:asset]) {//如果是HEIF格式需要转码
        CIImage *ciImage = [CIImage imageWithData:imageData];
        CIContext *context = [CIContext context];
        data = [context JPEGRepresentationOfImage:ciImage colorSpace:ciImage.colorSpace options:@{}];
//        imageData = [context PNGRepresentationOfImage:ciImage format:kCIFormatRGBA8 colorSpace:ciImage.colorSpace options:@{}];
    }
    //不要旋转了，旋转会造成图片元数据的损失
//    if (UIImageOrientationUp != orientation && UIImageOrientationUpMirrored != orientation) {//把旋转过的照片调整成未旋转过的
//        data = UIImageJPEGRepresentation([[UIImage imageWithData:data scale:0] normalizedImage], 1);
//    }
    return data;
}

- (void)manager:(XMPhotosRequestManager *)manager exportCompleted:(PHAsset *)asset cachePath:(NSString *)cachePath
{
    FileTask *task = asset.task;
    if (FileTaskStatusPause != task.state) {//没有暂停
        task.state = FileTaskStatusExported;
    }
    XM_OnThreadSafe(_lock_existFileCount, ++_existFileCount);
    task.localPath = [OutputDir stringByAppendingPathComponent:[cachePath lastPathComponent]];//使用相对路径，相对于_tempDir
    
    [self divideTask:task];
    task.sizeFormatString = nil;
    [task updateStatusToLocal];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self startNextUploadTask];
    });
    
    if (manager.isAutoPaused && _existFileCount < 2) {
        [manager startRequest];
    }
}

- (void)manager:(XMPhotosRequestManager *)manager exportFailed:(PHAsset *)asset error:(NSError *)error
{
    asset.task.state = FileTaskStatusError;
    [self completedUploadFileTask:asset.task];
}

@end
