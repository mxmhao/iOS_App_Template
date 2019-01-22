//
//  User.h
//  使用的是WCDB框架

#import <Foundation/Foundation.h>
//#import <YYModel/YYModel.h>

FOUNDATION_EXTERN float const LowBatteryValue;
FOUNDATION_EXTERN float const LowBatteryMustStopValue;
//用户退出登录通知
FOUNDATION_EXTERN NSNotificationName const UserLogoutNotification;
FOUNDATION_EXTERN NSNotificationName const LoadOnWiFiSwitchNotification;

/**
 用户，用于保存用户的账号和设置等信息
 */
@interface User : NSObject ///<NSCoding, YYModel>
/** 当前登录的用户 */
@property (nonatomic, strong, class) User *currentUser;

#pragma mark - 账号
/** 主键 */
@property (nonatomic, assign, readonly) int Id;
/** 用户所属设备的Mac地址 */
@property (nonatomic, copy) NSString *mac;
/** 设备认证码 */
//@property (nonatomic, copy) NSString *deviceAuthorization;
/** 账号 */
@property (nonatomic, copy) NSString *account;
/** 密码 */
@property (nonatomic, copy) NSString *password;
/** 最后一次登录时间 */
@property (nonatomic, assign) NSTimeInterval lastLoginTime;
/** 是否记住账号密码 */
@property (nonatomic, assign) BOOL rememberMe;
/** 网络请求时需要的sessionId */
@property (nonatomic, copy) NSString *sessionId;//token?，不用保存到数据库?

#pragma mark - 设置
/** WiFi连接时上传/下载，默认YES */
@property (nonatomic, assign) BOOL loadOnWiFi;//transmission? Transmit?

/** 手势密码锁是否开启 */
@property (nonatomic, assign) BOOL patternLockOn;
/** 手势密码 */
@property (nonatomic, assign) NSInteger patternPassword;
/** 手势密码锁延迟上锁时间，单位秒 */
@property (nonatomic, assign) NSUInteger secondsOfLockDelayed;
/** 手势密码输入剩余次数 */
@property (nonatomic, assign) short numberOfRemainingDrawing;//remainingTimes;

@property (nonatomic, assign) BOOL notFirstAutoBackupAlbum;
/** 是否自动备份相册 */
@property (nonatomic, assign) BOOL autoBackupAlbum;
/** 电量低于20%时是否暂停自动备份，默认YES */
@property (nonatomic, assign) BOOL stopBackupAlbumWhenLowBattery;
/** 是否备份照片 */
@property (nonatomic, assign) BOOL backupPhotos;
/** 是否备份视频 */
@property (nonatomic, assign) BOOL backupVideos;
/** 备份文件总数 */
@property (nonatomic, assign) NSUInteger totalBackup;
/** 已经备份了多少个文件 */
@property (nonatomic, assign) NSUInteger completedBackup;

/** 暂停下载 */
@property (nonatomic, assign) BOOL isPauseAllDownload;//貌似没什么用了
/** 暂停上传 */
@property (nonatomic, assign) BOOL isPauseAllUpload;//貌似没什么用了

/** 排序方式, "name"或者"time" */
//@property (nonatomic, strong) NSString *sort;

#pragma mark - 方法
+ (BOOL)createTable;

/**
 获取指定设备的所有用户
 按登录时间降序排列
 @param mac 指定设备的Mac地址
 @return 所有用户
 */
+ (NSArray<User *> *)usersForMac:(NSString *)mac;

/**
 获取指定设备的一个已登录过的用户

 @param mac 指定设备的Mac地址
 @param account 账号
 @return 用户
 */
+ (instancetype)userForMac:(NSString *)mac account:(NSString *)account;

/**
 获取指定设备的最新一个登录的用户

 @param mac 指定设备的Mac地址
 @return 用户
 */
+ (instancetype)lastLoginUserForMac:(NSString *)mac;

/**
 把用户数据更新到本地存储
 */
- (BOOL)updateToLocal;

/**
 更新备份数量

 @return 是否更新成功
 */
- (BOOL)updateBackupCount;

@end
