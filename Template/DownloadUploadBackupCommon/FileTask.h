//
//  FileTask.h
//  使用的是WCDB框架

#import <Foundation/Foundation.h>
#import <Photos/Photos.h>

//此类的成员的顺序千万不要改变，因为判断时用到了'<''>'做比较
typedef NS_ENUM(NSInteger, FileTaskStatus) {
    FileTaskStatusWaiting = 0,      //等待
    FileTaskStatusExporting,    //导出中
    FileTaskStatusExported,     //已导出
    FileTaskStatusInProgress,   //传输进行中
    FileTaskStatusPause,        //暂停
    FileTaskStatusCompleted,    //完成
    FileTaskStatusError,        //出错
//    FileTaskStatusCanceled,     //取消
    FileTaskStatusDeleted
};

typedef NS_ENUM(NSInteger, FileTaskType) {
    FileTaskTypeUpload,  //上传
    FileTaskTypeDownload,//下载
};

@class User;

@interface FileTask : NSObject
/** 主键，自增 */
@property (nonatomic, assign, readonly) NSUInteger Id;
/** 主机mac地址 */
@property (nonatomic, copy) NSString *mac;
/** 用户id */
@property (nonatomic, assign) int userId;
/** 文件名称 */
@property (nonatomic, copy) NSString *fileName;
/** 文件后缀, extension name */
@property (nonatomic, copy) NSString *fileExt;
/** 文件类型，图片或视频 */
@property (nonatomic, assign) PHAssetMediaType mediaType;
/** 传输状态 */
@property (nonatomic, assign) FileTaskStatus state;//成功，失败，完成，暂停
/** 文件大小，单位byte */
@property (nonatomic, assign) uint64_t size;
/** 已传输文件大小 */
@property (nonatomic, assign) uint64_t completedSize;
/** 传输类型 */
@property (nonatomic, assign) FileTaskType type;//上传下载
/** 在NAS上的路径，也是上传目标路径 */
@property (nonatomic, copy) NSString *nasPath;
/** 文件创建时间 */
@property (nonatomic, assign) NSTimeInterval createTime;
/** 本地沙盒缓存相对路径，若是FileTaskTypeDownload则相对于NSDocumentDirectory */
@property (nonatomic, copy) NSString *localPath;
/** 当前传输的片段，从0开始 */
@property (nonatomic, assign) uint32_t currentFragment;
/** 总片段 */
@property (nonatomic, assign) uint32_t totalFragment;
/** 文件处理 */
@property (nonatomic, strong) NSFileHandle *fileHandle;
/** 可以重试一次上传 */
@property (nonatomic, assign) BOOL canUpload;
/** PHAsset.localIdentifier */
@property (nonatomic, copy) NSString *assetLocalIdentifier;
/** 文件类型 */
@property (nonatomic, assign) TMFileType filetype;

//------------------这几个不用保存到数据库-------------------------
/** 相册文件的asset */
@property (nonatomic, strong) PHAsset *asset;
/** 选中状态 */
@property (nonatomic, assign, getter=isSelected) BOOL selected;
/** 传输速度 */
@property (nonatomic, assign) uint64_t transmissionSpeed;

/** 创建时间，格式化好的字符串 */
@property (nonatomic, readonly) NSString *createTimeFormatString;
/** 传输速度，格式化好的字符串 */
@property (nonatomic, readonly) NSString *speedFormatString;
/** 文件大小，格式化好的字符串 */
@property (nonatomic, copy) NSString *sizeFormatString;
/** 已传输的大小，格式化好的字符串 */
@property (nonatomic, readonly) NSString *completedSizeFormatString;
/** 本地沙盒缓存绝对路径 */
@property (nonatomic, copy) NSString *absoluteLocalPath;
/** 断点续传的数据 */
@property (nonatomic, copy) NSString *resumeDataName;

+ (BOOL)createTable;

/**
 获取数据库中最大的Id

 @return Id
 */
+ (NSInteger)fileTaskMaxId;

/**
 正在下载，或者正在上传的任务，按id升序排列

 @param user 用户
 @param type 任务类型
 @return 任务
 */
+ (NSArray<FileTask *> *)progressFileTasksForUser:(User *)user taskType:(FileTaskType)type;

+ (NSArray<FileTask *> *)progressFileTasksForUser:(User *)user taskType:(FileTaskType)type offset:(NSUInteger)offset;

/**
 获取大于自定id的任务，且是正在下载，或者正在上传的任务

 @param user 用户
 @param type 任务类型
 @param Id fileTask.Id
 @return 任务
 */
+ (NSArray<FileTask *> *)progressFileTasksForUser:(User *)user taskType:(FileTaskType)type idGreaterThan:(NSInteger)Id;

/**
 已成功的任务
 
 @param user 用户
 @param type 任务类型
 @return 任务
 */
+ (NSArray<FileTask *> *)successFileTasksForUser:(User *)user taskType:(FileTaskType)type;
/**
 已失败的任务
 
 @param user 用户
 @param type 任务类型
 @return 任务
 */
+ (NSArray<FileTask *> *)failureFileTasksForUser:(User *)user taskType:(FileTaskType)type;

+ (BOOL)isExistsFileTaskForUser:(User *)user nasPath:(NSString *)nasPath fileTaskType:(FileTaskType)type;

/**
 添加新任务

 @param fileTasks 多个任务
 @return 是否添加成功
 */
+ (BOOL)addFileTasks:(NSArray<FileTask *> *)fileTasks;

/**
 删除用户所有数据

 @return 是否删除成功
 */
+ (BOOL)deleteAllFileTasksForUser:(User *)user forType:(FileTaskType)type;

+ (BOOL)deleteFileTask:(FileTask *)ftask;

+ (BOOL)deleteFileTaskWithIDs:(NSArray<NSNumber *> *)ids;

+ (BOOL)updateFileTasks:(NSArray<FileTask *> *)fileTasks;


/**
 新数据插入到数据库使用的初始化方法

 @return FileTask
 */
- (instancetype)initForInsert;

/**
 把用户数据更新到数据库，<br>当数据库不存在这条数据，且使用了initForInsert初始化实例，则会插入一条数据，否则会更新数据库
 */
- (BOOL)updateToLocal;

- (BOOL)updateStatusToLocal;

@end
