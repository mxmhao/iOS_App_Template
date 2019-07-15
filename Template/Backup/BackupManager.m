//
//  BackupManager.m
//  备份导出和上传导出不一样，上传导出可以选择原图或者压缩图，而备份都是原图

/*
 相册备份
 备份机制：wifi下2小时一次，移动网络进去到wifi网络马上备份。
 */

#import "BackupManager.h"
#import <AFNetworking/AFNetworking.h>
#import "User.h"
#import "FileTask.h"
#import "NSTimer+Block.h"
#import "XMLock.h"
#import "UIImage+Format.h"
#import "DeviceNetworkManager.h"
#import "XMPhotosRequestManager.h"
#import "XMPhotosRequestManager+Utils.h"
#import "SVProgressHUD.h"

NSNotificationName const BackupFileCountUpdateNotification = @"nBackupFileCountUpdate";

static NSString *const OutputDir = @"backup";

//电量不够备份了
NS_INLINE
BOOL IsNotBatterySufficientForBackup(float batteryLevel, BOOL stopBackupAlbumWhenLowBattery) {
    return (stopBackupAlbumWhenLowBattery && batteryLevel < LowBatteryValue)//电量低于设置定
    || batteryLevel <= LowBatteryMustStopValue;//快关机了
}

@interface BackupManager () <XMPhotosRequestManagerDelegate>
@end

@implementation BackupManager
{
    User *_user;
    AFHTTPSessionManager *_httpManager;
    
    //系统情况，用户退出监测相关
    BOOL _isStop;   //停止
    BOOL _cannotUseNetwork;
    BOOL _lowBattery;
    NSTimer *_timer;                //定时器，定期检查是否有新文件需要备份
//    NSCondition *_condition;
    DeviceNetworkManager *_dnm;
    AFNetworkReachabilityManager *_nrm;
    UIDevice *_device;
    
    //导出相关
    NSString *_tempDir;             //系统目录
    NSString *_outputAbsolutePath;  //自建缓存目录的绝对路径
    NSMutableArray<NSString *> *_backedupList;  //已备份的文件名，临时存储
    XMPhotosRequestManager *_prm;
    NSMutableDictionary<NSString *, PHAsset *> *_assetDic;//临时存储
    NSMutableArray<PHAsset *> *_assets;//还未导出的
    XMLock _lock_assets;
    
    //上传相关
    NSString *_backupDir;           //远程备份目录
    NSMutableArray<FileTask *> *_fileTasks;//已导出好的任务列表
    XMLock _lock_fileTasks;//锁
    int _existFileCount;//还有多少个文件没上传完
    XMLock _lock_existFileCount;
    FileTask *_currentBackupTask;   //当前正在备份的task
    NSURLSessionDataTask *_dataTask;//正在上传的任务
    NSFileManager *_fm;
}

static BackupManager *manager = nil;
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

static NSTimeInterval const TimeRepeat = 7200.000000;//2小时//1800.000000;//30分钟

- (instancetype)initWithUser:(User *)user
{
    if (!user) {
        return nil;
    }
    self = [super init];
    if (self) {
        _user = user;
        _isInProgress = NO;
        _cannotUseNetwork = NO;
        _lowBattery = NO;
        
        _dnm = [DeviceNetworkManager new];
        _nrm = [AFNetworkReachabilityManager sharedManager];
        
        _tempDir = NSTemporaryDirectory();
        _outputAbsolutePath = [_tempDir stringByAppendingPathComponent:OutputDir];
        _fm = [NSFileManager defaultManager];
        BOOL isDir = NO;
        if (![_fm fileExistsAtPath:_outputAbsolutePath isDirectory:&isDir] || !isDir) {
            [_fm createDirectoryAtPath:_outputAbsolutePath withIntermediateDirectories:YES attributes:nil error:NULL];
        }
        _lock_assets = XM_CreateLock();
        _lock_fileTasks = XM_CreateLock();
        
        PHVideoRequestOptions *voptions = [PHVideoRequestOptions new];
        voptions.deliveryMode = PHVideoRequestOptionsDeliveryModeHighQualityFormat;
        voptions.networkAccessAllowed = YES;
        
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
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(logout) name:UIApplicationWillTerminateNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(logout) name:UserLogoutNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    NSLog(@"BackupManager -- 释放");
}

- (void)logout
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    _dnm = nil;
    _nrm = nil;
    _device = nil;
    [self stopBackup];
    _user = nil;
    _httpManager = nil;
    _prm = nil;
    [_fm removeItemAtPath:_outputAbsolutePath error:NULL];
    onceToken = 0;
    manager = nil;
}

- (void)setCanUseNetwork
{
    _cannotUseNetwork = NO;
}
    
- (void)prepare
{
    if (nil == _device) {
        _device = [UIDevice currentDevice];
    }
    if (nil == _fileTasks) {
        _fileTasks = [NSMutableArray array];
    }
    
    if (!_httpManager) {
#warning 请仔细阅读注释
        /*
         在info.plist中设置后台模式
         设置后台NSURLSessionConfiguration的NSURLSession在App的生命周期内同一个Identifier只能有
         一个，不能new新的，而且Identifier必须唯一，不能和其他App的冲突，后台上传下载都是如此，而且，
         只有对NSURLSessionDownloadTask和NSURLSessionUploadTask才有效，其他的无效
         */
        //[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"min.test.DownloadManager"] 若没有杀死当前app，在第二次new时，这个会导致cancelByProducingResumeData是不会回调completionHandler，我疯了🤣
        _httpManager = [[AFHTTPSessionManager alloc] initWithBaseURL:nil sessionConfiguration:[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"min.test.BackupManager"]];
        //初始化并设置认证
//        _httpManager = [AFHTTPSessionManager manager];
//        _httpManager.completionQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
//        dispatch_queue_create("com.server.backup", DISPATCH_QUEUE_SERIAL);
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityStatusChanged:) name:NetworkUsableDidChangeNotification object:nil];//AFNetworkingReachabilityDidChangeNotification
    }
    //开启电池监听
    if (_user.stopBackupAlbumWhenLowBattery && !_device.batteryMonitoringEnabled) {
        _device.batteryMonitoringEnabled = YES;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(batteryLevelDidChanged) name:UIDeviceBatteryLevelDidChangeNotification object:nil];
    }
    //开启定时器
    if (_user.autoBackupAlbum && nil == _timer) {
        __weak typeof(self) this = self;
        _timer = [NSTimer xm_scheduledTimerWithTimeInterval:TimeRepeat repeats:YES block:^{
            [this backupImmediately];
        }];
    }
}

//自动备份开关
- (void)switchAutoBackup:(BOOL)isAuto
{
    if (nil == _user) return;
    if (isAuto) {
        _isStop = NO;
        [self prepare];
    } else {
        [self stopBackup];
    }
}

#pragma mark - 设备状态监听
- (void)reachabilityStatusChanged:(NSNotification *)noti
{
    if (![noti.userInfo[NetworkUsableItem] boolValue]) {
        _cannotUseNetwork = YES;
        [self pause];
    } else {
        _cannotUseNetwork = NO;
        [self resume];
    }
    return;
    
    if (UsersCannotUseTheNetwork([noti.userInfo[AFNetworkingReachabilityNotificationStatusItem] integerValue], _user.loadOnWiFi)) {
        _cannotUseNetwork = YES;
        [self pause];
    } else {
        __weak typeof(self) this = self;
        [_dnm deviceReachability:^(BOOL isReachable) {
            if (isReachable) {
                [this setCanUseNetwork];
                [this resume];
            }
        }];
    }
}

//电池监听
- (void)batteryLevelDidChanged
{
    if (IsNotBatterySufficientForBackup(_device.batteryLevel, _user.stopBackupAlbumWhenLowBattery)) {//电量过低
        _lowBattery = YES;
        [self pause];
    } else {
        _lowBattery = NO;
        [self resume];
    }
}

//立刻备份
- (void)backupImmediately
{
//    [self prepare];
    if (_isInProgress   //正传输
        || _cannotUseNetwork || _lowBattery
        || nil == _user //没有用户
        || _isStop
        || !_user.autoBackupAlbum
        || IsNotBatterySufficientForBackup(_device.batteryLevel, _user.stopBackupAlbumWhenLowBattery)
        || UsersCannotUseTheNetwork(_nrm.networkReachabilityStatus, _user.loadOnWiFi)
        )//开启了WiFi传输设置，而当前不是WiFi网络
        return;
    
    _isInProgress = YES;
//    _isStop = NO;
    //开始创建备份目录
    [self createBackupFolder];
}

static NSString *const homeDir = @"/home/";
static NSString *const backDir = @"/Mobile backup/";
//创建备份目录
- (void)createBackupFolder
{
    NSLog(@"创建远程备份目录");
//    if (baseURL.length == 0) {
//        baseURL = [UserDefaults objectForKey:@"baseURL"];
//    }
    
    NSString *urlstr = [HttpCreatNewFileUrl stringByReplacingOccurrencesOfString:@"[ip]:[port]" withString:baseURL];
    if (nil == _backupDir) {
        _backupDir = [NSString stringWithFormat:@"%@%@%@%@", homeDir, _user.account, backDir, _device.name];
    }
    NSDictionary *params = @{@"path": _backupDir, @"type": @"folder"};
    __weak typeof(self) this = self;
    [_httpManager POST:urlstr parameters:params progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id _Nullable responseObject) {
        if ([responseObject[@"code"] boolValue]) {
            //开始备份
            [this fetchserverFileList];
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSLog(@"远程备份目录创建失败: \n%@", error);
    }];
}

//1、获取server上已备份文件目录
- (void)fetchserverFileList
{
    _backedupList = [NSMutableArray array];
    NSDictionary *params = @{@"path": _backupDir};
    NSString *urlstr = [HttpFileListUrl stringByReplacingOccurrencesOfString:@"[ip]:[port]" withString:baseURL];
    __weak typeof(self) this = self;
    [_httpManager POST:urlstr parameters:params progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        if (![responseObject[@"code"] boolValue]) return;
        
@autoreleasepool {
        NSDictionary *dataDic = responseObject[@"data"];
        NSArray *arr = dataDic[@"filelist"];
        for (NSUInteger i = 0, count = arr.count; i < count; ++i) {
            [_backedupList addObject:arr[i][@"name"]];
        }
        NSLog(@"获取备份目录列表，当前网盘已备份数量%ld", _backedupList.count);
}//autoreleasepool
        
        [this fetchLocalFileList];
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [SVProgressHUD dismiss];
        _backedupList = nil;
        NSLog(@"获取备份目录文件列表失败");
    }];
}

//2、获取本地文件
- (void)fetchLocalFileList
{
    _assetDic = [NSMutableDictionary dictionary];
    PHFetchResult *result = nil;
@autoreleasepool {
    if (_user.backupPhotos) {
        result = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:nil];//只取图片
        for (PHAsset *asset in result) {
            [_assetDic setObject:asset forKey:[asset valueForKey:@"filename"]];
        }
        result = nil;
    }
}//autoreleasepool
    
@autoreleasepool {
    if (_user.backupVideos) {
        result = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeVideo options:nil];//只取图片
        for (PHAsset *asset in result) {
            [_assetDic setObject:asset forKey:[asset valueForKey:@"filename"]];
        }
        result = nil;
    }
}//autoreleasepool
    
    if (_assetDic.count == 0) {
        _assetDic = nil;
        _user.completedBackup = 0;
        _user.totalBackup = 0;
        [_user updateBackupCount];
        _isInProgress = NO;
        //通知备份数量已更新
        [[NSNotificationCenter defaultCenter] postNotificationName:BackupFileCountUpdateNotification object:nil];
    } else {
        [self exportAsset];
    }
    NSLog(@"本地文件获取完成");
}

//上传没备份的
- (void)exportAsset
{
    NSLog(@"开始导出");
    _user.totalBackup = _assetDic.count;//要备份的总数
    [_assetDic removeObjectsForKeys:_backedupList];//删除已备份的
    _user.completedBackup = _user.totalBackup - _assetDic.count;//已备份的数量
    //没作用了，删除
    [_backedupList removeAllObjects];
    _backedupList = nil;
    
    [_user updateBackupCount];
    //通知备份数量已更新
    [[NSNotificationCenter defaultCenter] postNotificationName:BackupFileCountUpdateNotification object:nil];
    
    if (_assetDic.count == 0) {//当前没有要备份的，就开启定时器
        _assetDic = nil;
        _isInProgress = NO;
        return;
    }
    _assets = [NSMutableArray arrayWithArray:_assetDic.allValues];
    //清除临时文件
    [_assetDic removeAllObjects];
    _assetDic = nil;
    
    [_prm addPHAssets:_assets];
    [_prm startRequest];
}

static uint64_t const UploadFragmentSize = 8388608;//10485760;//10MB
#pragma mark 文件分块
- (void)divideTask:(FileTask *)task
{
    NSDictionary *attrDic = [_fm attributesOfItemAtPath:[_tempDir stringByAppendingPathComponent:task.localPath] error:nil];
    task.size = [attrDic fileSize];
    // 块数
    task.totalFragment = (int)(task.size % UploadFragmentSize == 0? task.size/UploadFragmentSize: task.size/UploadFragmentSize + 1);
    task.currentFragment = 0;
}

#pragma mark - 上传文件
- (void)uploadBackupFileWithTask:(FileTask *)fTask
{
    if (_isStop || _cannotUseNetwork || _lowBattery) return;

    static NSString *const videoMinetype = @"video/quicktime";
    static NSString *const imageMinetype = @"image/png";
    
    _currentBackupTask = fTask;
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
    
    NSString *mimetype = imageMinetype;
    if (fTask.mediaType == PHAssetMediaTypeVideo) {
        mimetype = videoMinetype;
    } else if (fTask.mediaType == PHAssetMediaTypeImage) {
        mimetype = imageMinetype;
    }
    
    fTask.state = FileTaskStatusInProgress;
    __weak typeof(self) this = self;
    
    _dataTask = [_httpManager POST:urlstr parameters:params constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
        NSData *data = nil;
        [fTask.fileHandle seekToFileOffset:fTask.currentFragment * UploadFragmentSize];
        if (fTask.currentFragment < fTask.totalFragment - 1) {//不是最后一个片段了
            data = [fTask.fileHandle readDataOfLength:UploadFragmentSize];
        } else {
            data = [fTask.fileHandle readDataToEndOfFile];
        }
        if (nil != data) {
            [formData appendPartWithFileData:data name:@"file" fileName:fTask.fileName mimeType:mimetype];
        }
        
    } progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        fTask.currentFragment++;
        [this setCurrentTaskNil];
        if (fTask.currentFragment <= fTask.totalFragment - 1) {//还有片段上传
            if (FileTaskStatusPause == fTask.state) return;//系统暂停了
            [this uploadBackupFileWithTask:fTask];//继续下一个片段
        } else {
            fTask.state = FileTaskStatusCompleted;
            [this completedBackupFileTask:fTask];
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [this setCurrentTaskNil];
        if ((error.code == NSURLErrorCancelled || error.code == NSURLErrorNetworkConnectionLost || error.code == NSURLErrorTimedOut) && [NSURLErrorDomain isEqualToString:error.domain]) return;//系统暂停了，或者断网了
        
        if (fTask.canUpload) {//有一次
            fTask.canUpload = NO;
            [this uploadBackupFileWithTask:fTask];
        } else {
            fTask.state = FileTaskStatusError;
            [this completedBackupFileTask:fTask];
        }
    }];
}

- (void)setCurrentTaskNil
{
    _currentBackupTask = nil;
    _dataTask = nil;
}

- (void)completedBackupFileTask:(FileTask *)fTask
{
    [fTask.fileHandle closeFile];
    fTask.fileHandle = nil;
    //上传完成后立刻删除临时文件
    XM_Lock(_lock_existFileCount);
    if (!IsTextEmptyString(fTask.localPath)) {
        [_fm removeItemAtPath:[_tempDir stringByAppendingPathComponent:fTask.localPath] error:NULL];
    }
    --_existFileCount;
    XM_UnLock(_lock_existFileCount);
    XM_OnThreadSafe(_lock_fileTasks, [_fileTasks removeObject:fTask]);
    
    if (FileTaskStatusCompleted == fTask.state) {
        //备份数量更新通知
        _user.completedBackup++;
        [_user updateBackupCount];
        [[NSNotificationCenter defaultCenter] postNotificationName:BackupFileCountUpdateNotification object:nil];
    } else if (FileTaskStatusError == fTask.state) {
        [self clearUpLoadCache:fTask];
    }
    [self startNextFileTaskForBackup];
}

- (void)startNextFileTaskForBackup
{
    if (_isStop || _cannotUseNetwork || _lowBattery || nil != _currentBackupTask || nil != _dataTask) return;
    
    XM_Lock(_lock_fileTasks);
    FileTask *ftask = _fileTasks.firstObject;
    XM_UnLock(_lock_fileTasks);
    if (ftask) {
        [self uploadBackupFileWithTask:_fileTasks.firstObject];
    }
    if (_existFileCount < 3 && _assets.count > 0) {
        [_prm startRequest];
    }
    if (_fileTasks.count + _assets.count == 0) {
        _isInProgress = NO;
    }
}

- (void)stopBackup
{
    _isStop = YES;
    _existFileCount = 0;
    if (_timer) {
        [_timer invalidate];
        _timer = nil;
    }
    //停止所有的网络传输
    if (_dataTask) {
        _currentBackupTask.state = FileTaskStatusPause;
        [_dataTask cancel];
        _dataTask = nil;
        [self clearUpLoadCache:_currentBackupTask];
        _currentBackupTask = nil;
    }
    [_prm stopRequest];
    XM_OnThreadSafe(_lock_fileTasks, [_fileTasks removeAllObjects]);
    XM_OnThreadSafe(_lock_assets, [_assets removeAllObjects]);
    _isInProgress = NO;
    [_fm removeItemAtPath:_outputAbsolutePath error:NULL];
    [_fm createDirectoryAtPath:_outputAbsolutePath withIntermediateDirectories:YES attributes:nil error:NULL];
}

//暂停备份
- (void)pause
{
    if (!_isInProgress) return;//没有上传任务
    
    if (_dataTask) {
        _currentBackupTask.state = FileTaskStatusPause;
        [_dataTask cancel];
        _dataTask = nil;
        [self clearUpLoadCache:_currentBackupTask];
        _currentBackupTask = nil;
    }
    
    [_prm pauseAll];
}

//恢复备份
- (void)resume
{
    if (!_isInProgress
        || IsNotBatterySufficientForBackup(_device.batteryLevel, _user.stopBackupAlbumWhenLowBattery)
        || UsersCannotUseTheNetwork(_nrm.networkReachabilityStatus, _user.loadOnWiFi)
        ) {
        return;
    }
    [_prm resumeAll];
    if (nil == _dataTask) {
        [self startNextFileTaskForBackup];
    }
}

//清除server上的上传缓存
- (void)clearUpLoadCache:(FileTask *)task
{
    task.completedSize = 0;
    task.currentFragment = 0;
    NSDictionary *params = @{@"saveTo": task.serverPath};
    NSString *url = [HttpClearUpLoadCache stringByReplacingOccurrencesOfString:@"[ip]:[port]" withString:baseURL];
    [_httpManager POST:url parameters:params progress:nil success:nil failure:nil];
}

- (void)addBackupTaskWith:(PHAsset *)asset cachePath:(NSString *)cachePath
{
    FileTask *task = [FileTask new];
    task.fileName = [asset valueForKey:@"filename"];
    task.createTime = [asset.modificationDate timeIntervalSince1970];
    task.mediaType = asset.mediaType;
    task.serverPath = [_backupDir stringByAppendingPathComponent:task.fileName];
    task.localPath = [OutputDir stringByAppendingPathComponent:[cachePath lastPathComponent]];//使用相对路径，相对于_tempDir
    [self divideTask:task];
    
    XM_Lock(_lock_existFileCount);
    XM_Lock(_lock_fileTasks);
    ++_existFileCount;
    [_fileTasks addObject:task];
    XM_UnLock(_lock_fileTasks);
    XM_UnLock(_lock_existFileCount);
    if (nil == _dataTask) {
        [self startNextFileTaskForBackup];
    }
}

#pragma mark - XMPhotosRequestManagerDelegate
- (void)manager:(XMPhotosRequestManager *)manager customPropertyForExportSession:(AVAssetExportSession *)exportSession
{
    exportSession.outputFileType = AVFileTypeMPEG4;
    exportSession.shouldOptimizeForNetworkUse = YES;
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
//    if (UIImageOrientationUp != orientation && UIImageOrientationUpMirrored != orientation) {//把旋转过的照片调整成未旋转过的
//        data = UIImageJPEGRepresentation([[UIImage imageWithData:data scale:0] normalizedImage], 1);
//    }
    return data;
}

- (void)manager:(XMPhotosRequestManager *)manager exportCompleted:(PHAsset *)asset cachePath:(NSString *)cachePath
{
    if (_isStop) {
        [_fm removeItemAtPath:cachePath error:NULL];
        return;
    }
    
    XM_OnThreadSafe(_lock_assets, [_assets removeObject:asset]);
    [self addBackupTaskWith:asset cachePath:cachePath];
    
    if (manager.isAutoPaused && _existFileCount < 3) {
        [manager startRequest];
    }
}

- (void)manager:(XMPhotosRequestManager *)manager exportFailed:(PHAsset *)asset error:(NSError *)error
{
    XM_OnThreadSafe(_lock_assets, [_assets removeObject:asset]);
}

@end

// 确定可以使用的文件类型, 这两种方法都行
//        NSLog(@"5 = %@", exportSession.supportedFileTypes);
//        [exportSession determineCompatibleFileTypesWithCompletionHandler:^(NSArray<AVFileType> * _Nonnull compatibleFileTypes) {
//            NSLog(@"6 = %@", compatibleFileTypes);
//        }];
