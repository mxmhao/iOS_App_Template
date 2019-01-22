//
//  BackupManager.h
// 依赖DownloadUploadBackupCommon中的部分文件
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

FOUNDATION_EXTERN NSNotificationName const BackupFileCountUpdateNotification;

@interface BackupManager : NSObject
/** 用户, 不能为空 */
//@property (nonatomic, weak) User *user;
/** 是否正在备份 */
@property (nonatomic, assign, readonly) BOOL isInProgress;
/** 备份文件总数 */
@property (nonatomic, assign, readonly) NSUInteger total;
/** 已经备份了多少个文件 */
@property (nonatomic, assign, readonly) NSUInteger completedCount;

/**
 单例类
 在调用前请设置好 User.currentUser
 @return BackupManager单例
 */
+ (instancetype)shareManager;

+ (instancetype)new NS_UNAVAILABLE;//不可调用
- (instancetype)init NS_UNAVAILABLE;//不可调用

/**
 立刻备份
 先调用[BackupManager switchAutoBackup:YES]才会有效
 */
- (void)backupImmediately;

/**
 自动备份开关

 @param isAuto YES：开，NO：关
 */
- (void)switchAutoBackup:(BOOL)isAuto;

/**
 停止备份，关闭自动备份时调用，重新选择备份相册时也要调用
 */
- (void)stopBackup;

@end
