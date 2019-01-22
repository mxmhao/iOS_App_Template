//
//  BackupManager.h
// 依赖DownloadUploadBackupCommon中的部分文件

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
