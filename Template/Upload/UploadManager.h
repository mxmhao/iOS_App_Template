//
//  UploadManager.h
/**
 断点上传的思路：
 上传前先查询服务器当前文件是否上传过，如果上传过，返回已上传的字节数，
 然后接着已上传的继续上传，否则从0开始上传；
 第一次上传时给服务器，除文件名外，最好还提交一个文件计算过的唯一标识符(如
 MD5)，以后断点续传时，可检查上次上传的文件和此次的是否为同一个文件，
 若不是，就要相应的做出处理，否则，继续断点续传
 
 我下面的是用的分片上传，然后本地记录已上传的片段数，这种方式不太好
 */

#import <Foundation/Foundation.h>

@class User, FileTask, UploadManager, PHAsset;

@protocol UploadManagerDelegate <NSObject>

@optional
//fileTasks可能是uploadingTasks或者failureTasks
- (void)uploadManager:(UploadManager *)manager didAddNewFileTasks:(NSArray<FileTask *> *)fileTasks;

- (void)uploadManager:(UploadManager *)manager didChangeFileTask:(FileTask *)fileTask;
//将要移动
- (void)uploadManager:(UploadManager *)manager willMoveFileTaskToArr:(NSArray *)toArr;
//移动了
- (void)uploadManager:(UploadManager *)manager didMoveFileTask:(FileTask *)fileTask fromArr:(NSArray *)fromArr fromIndex:(NSUInteger)fromIdx toArr:(NSArray *)toArr toIdx:(NSUInteger)toIdx;
@end

@interface UploadManager : NSObject

/** 代理 */
@property (nonatomic, weak) id<UploadManagerDelegate> delegate;
/** 上传任务 */
@property (nonatomic, strong, readonly) NSArray<FileTask *> *uploadingTasks;
/** 上传成功的任务 */
@property (nonatomic, strong, readonly) NSArray<FileTask *> *successTasks;
/** 上传失败的任务 */
@property (nonatomic, strong, readonly) NSArray<FileTask *> *failureTasks;

+ (instancetype)shareManager;

/**
 上传相册文件

 @param assets PHAssets
 @param directory 目标目录
 @return 是否已添加到上传列表
 */
- (BOOL)uploadPHAsset:(NSArray<PHAsset *> *)assets toserverDirectory:(NSString *)directory;

/**
 暂停所有
 */
//- (void)pauseAll;

/**
 暂停单个FileTask
 
 @param ftask FileTask
 */
//- (void)pauseFileTask:(FileTask *)ftask;

/**
 恢复所有
 */
//- (void)resumeAll;

/**
 恢复单个FileTask
 
 @param ftask FileTask
 */
//- (void)resumeFileTask:(FileTask *)ftask;

/**
 删除所有FileTask
 */
- (void)deleteAll;

/**
 删除单个FileTask
 
 @param ftask FileTask
 */
- (void)deleteFileTask:(FileTask *)ftask;

/**
 删除所有选中的FileTask
 */
- (void)deleteAllSelected;

- (void)selectAllTasks;

- (void)deselectAllTasks;

- (BOOL)reupload:(FileTask *)filetask;

@end
