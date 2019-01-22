//
//  DownloadManager.h

#import <Foundation/Foundation.h>

@class DownloadManager, FileTask, TMRequestModel;

@protocol DownloadManagerDelegate <NSObject>
@optional

- (void)downloadManager:(DownloadManager *)manager didAddNewFileTasks:(NSArray<FileTask *> *)fileTasks;

- (void)downloadManager:(DownloadManager *)manager didChangeFileTask:(FileTask *)fileTask;
//将要移动
- (void)downloadManager:(DownloadManager *)manager willMoveFileTaskToArr:(NSArray *)toArr;
//移动了
- (void)downloadManager:(DownloadManager *)manager didMoveFileTask:(FileTask *)fileTask fromArr:(NSArray *)fromArr fromIndex:(NSUInteger)fromIdx toArr:(NSArray *)toArr toIdx:(NSUInteger)toIdx;
//没有正在下载的任务
- (void)downloadManager:(DownloadManager *)manager noTasksBeingDownloaded:(BOOL)isNo;
@end

@interface DownloadManager : NSObject
/** 代理 */
@property (nonatomic, weak) id<DownloadManagerDelegate> delegate;
/** 正在下载的任务，为了减少拷贝，用的strong */
@property (nonatomic, strong, readonly) NSArray<FileTask *> *downloadingTasks;
/** 下载成功的任务 */
@property (nonatomic, strong, readonly) NSArray<FileTask *> *successTasks;
/** 下载失败的任务 */
@property (nonatomic, strong, readonly) NSArray<FileTask *> *failureTasks;

+ (instancetype)shareManager;

/**
 下载文件

 @param model 文件
 @param nasDirectory 文件所在目录
 */
- (void)downloadFile:(TMRequestModel *)model fromNasDirectory:(NSString *)nasDirectory;

/**
 暂停所有
 
 @return YES表示：执行完毕，不会回调noTasksBeingDownloaded；NO表示：未执行完毕，会回调noTasksBeingDownloaded
 */
- (BOOL)pauseAll;

/**
 暂停单个FileTask

 @param ftask FileTask
 */
- (void)pauseFileTask:(FileTask *)ftask;

/**
 恢复所有
 
 @return YES表示：执行完毕，不会回调noTasksBeingDownloaded；NO表示：未执行完毕，会回调noTasksBeingDownloaded
 */
- (BOOL)resumeAll;

/**
 恢复单个FileTask
 
 @param ftask FileTask
 */
- (void)resumeFileTask:(FileTask *)ftask;

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

- (BOOL)isAllPaused;

- (void)redownload:(FileTask *)fileTask;

@end
