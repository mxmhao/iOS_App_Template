//
//  User.mm
//  本类用'WCDB'的'WCTDatabase'操作数据库

#import "User.h"
#import "User+WCTTableCoding.h"

float const LowBatteryValue = 0.20000f;//20%
float const LowBatteryMustStopValue = 0.100000f;//10%
NSNotificationName const UserLogoutNotification = @"nUserLogout";
NSNotificationName const LoadOnWiFiSwitchNotification = @"nLoadOnWiFiSwitch";

static NSString *const UserTableNameKey = @"User";
static NSString *const UserDBFileKey = @"users.sqlite";

NS_INLINE
WCTDatabase * UserDatabase()
{
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:UserDBFileKey];
    return [[WCTDatabase alloc] initWithPath:path];
}

@interface User ()
@property (nonatomic, assign) int Id;//set方法WCDB库会用到
@end;

@implementation User

//使用WCDB_IMPLEMENTATIO宏在类文件定义绑定到数据库表的类
WCDB_IMPLEMENTATION(User)
//使用WCDB_SYNTHESIZE宏在类文件定义需要绑定到数据库表的字段
WCDB_SYNTHESIZE(User, Id)
WCDB_SYNTHESIZE(User, mac)
WCDB_SYNTHESIZE(User, account)
WCDB_SYNTHESIZE(User, password)
WCDB_SYNTHESIZE(User, lastLoginTime)
WCDB_SYNTHESIZE(User, rememberMe)
WCDB_SYNTHESIZE(User, loadOnWiFi)
WCDB_SYNTHESIZE(User, patternLockOn)
WCDB_SYNTHESIZE(User, patternPassword)
WCDB_SYNTHESIZE(User, secondsOfLockDelayed)
WCDB_SYNTHESIZE(User, numberOfRemainingDrawing)
WCDB_SYNTHESIZE(User, autoBackupAlbum)
WCDB_SYNTHESIZE(User, stopBackupAlbumWhenLowBattery)
WCDB_SYNTHESIZE(User, backupPhotos)
WCDB_SYNTHESIZE(User, backupVideos)
WCDB_SYNTHESIZE(User, totalBackup)
WCDB_SYNTHESIZE(User, completedBackup)
WCDB_SYNTHESIZE(User, isPauseAllDownload)
WCDB_SYNTHESIZE(User, isPauseAllUpload)
WCDB_SYNTHESIZE(User, notFirstAutoBackupAlbum)
//主键自增
WCDB_PRIMARY_AUTO_INCREMENT(User, Id)
//索引, 降序
WCDB_INDEX_DESC(User, "_index", lastLoginTime)
//多字段唯一约束
WCDB_MULTI_UNIQUE(User, "_mac_account", mac)
WCDB_MULTI_UNIQUE(User, "_mac_account", account)

static User *_currentUser;
+ (User *)currentUser
{
    return _currentUser;
}

+ (void)setCurrentUser:(User *)currentUser
{
    _currentUser = currentUser;
}

+ (BOOL)createTable
{
    return [UserDatabase() createTableAndIndexesOfName:UserTableNameKey withClass:self.class];
}

+ (NSArray<User *> *)usersForMac:(NSString *)mac
{
    return [UserDatabase() getObjectsOfClass:self.class fromTable:UserTableNameKey where:self.mac == mac orderBy:User.lastLoginTime.order(WCTOrderedDescending)];
}

+ (instancetype)userForMac:(NSString *)mac account:(NSString *)account
{
    return [UserDatabase() getOneObjectOfClass:self.class fromTable:UserTableNameKey where:self.mac == mac && self.account == account];
}

+ (instancetype)lastLoginUserForMac:(NSString *)mac
{
    return [UserDatabase() getOneObjectOfClass:self.class fromTable:UserTableNameKey where:self.mac == mac orderBy:User.lastLoginTime.order(WCTOrderedDescending)];
}

+ (nullable NSArray<NSString *> *)modelPropertyBlacklist
{
    return @[NSStringFromSelector(@selector(Id)), NSStringFromSelector(@selector(sessionId))];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _Id = -1;
        _loadOnWiFi = YES;
        _stopBackupAlbumWhenLowBattery = YES;
    }
    return self;
}

- (void)dealloc
{
    NSLog(@"User -- 释放");
}

- (BOOL)updateToLocal
{
    WCTDatabase *database = UserDatabase();
    if (_Id < 0) {
        //这个是自增插入要做的事
        self.isAutoIncrement = YES;
        BOOL result = [database insertObject:self into:UserTableNameKey];
        _Id = self.lastInsertedRowID;//获取最新的id
        self.isAutoIncrement = NO;
        return result;
    }
    
//    return [database insertOrReplaceObject:self into:UserTableNameKey];
    return [database updateRowsInTable:UserTableNameKey onProperties:self.class.AllProperties withObject:self where:self.class.Id == _Id];//'=='是被重载过的运算符
}

- (BOOL)updateBackupCount
{
    return [UserDatabase() updateRowsInTable:UserTableNameKey onProperties:{self.class.completedBackup, self.class.totalBackup} withObject:self where:self.class.Id == _Id];
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    /*
    [aCoder encodeObject:_mac forKey:NSStringFromSelector(@selector(mac))];
    [aCoder encodeObject:_account forKey:NSStringFromSelector(@selector(account))];
    [aCoder encodeObject:_password forKey:NSStringFromSelector(@selector(password))];
    [aCoder encodeDouble:_lastLoginTime forKey:NSStringFromSelector(@selector(lastLoginTime))];
    [aCoder encodeBool:_rememberMe forKey:NSStringFromSelector(@selector(rememberMe))];
    [aCoder encodeBool:_loadOnWiFi forKey:NSStringFromSelector(@selector(loadOnWiFi))];
    [aCoder encodeBool:_patternLockOn forKey:NSStringFromSelector(@selector(patternLockOn))];
    [aCoder encodeInteger:_patternPassword forKey:NSStringFromSelector(@selector(patternPassword))];
    [aCoder encodeInteger:_secondsOfLockDelayed forKey:NSStringFromSelector(@selector(secondsOfLockDelayed))];
    [aCoder encodeInt:_numberOfRemainingDrawing forKey:NSStringFromSelector(@selector(numberOfRemainingDrawing))];
    [aCoder encodeBool:_autoBackupAlbum forKey:NSStringFromSelector(@selector(autoBackupAlbum))];
    [aCoder encodeBool:_stopBackupAlbumWhenLowBattery forKey:NSStringFromSelector(@selector(stopBackupAlbumWhenLowBattery))];
    [aCoder encodeBool:_backupPhotos forKey:NSStringFromSelector(@selector(backupPhotos))];
    [aCoder encodeBool:_backupVideos forKey:NSStringFromSelector(@selector(backupVideos))];
     */
//    [self yy_modelEncodeWithCoder:aCoder];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    self = [super init];
    if (self) {
//        [self yy_modelInitWithCoder:aDecoder];
    }
    return self;
}

- (BOOL)isEqual:(User *)other
{
    if (other == self) {
        return YES;
    }/* else if (![super isEqual:other]) {
        return NO;
    }*/ else if (![other isMemberOfClass:[self class]]) {
        return NO;
    } else {
        if (_Id > 0 && other->_Id > 0) {
            return _Id == other->_Id;
        }
        return [_mac isEqual:other->_mac] && [_account isEqual:other->_account];
    }
}

- (NSUInteger)hash
{
    if (_Id > 0) {
        return _Id;
    }
    return _mac.hash ^ _account.hash;
}

@end
