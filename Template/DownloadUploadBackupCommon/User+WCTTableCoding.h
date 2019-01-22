//
//  User+WCTTableCoding.h

#import "User.h"
#import <WCDB/WCDB.h>

@interface User (WCTTableCoding) <WCTTableCoding>

//使用WCDB_PROPERTY宏在头文件声明需要绑定到数据库表的字段
WCDB_PROPERTY(Id)
WCDB_PROPERTY(mac)
WCDB_PROPERTY(account)
WCDB_PROPERTY(password)
WCDB_PROPERTY(lastLoginTime)
WCDB_PROPERTY(rememberMe)
WCDB_PROPERTY(loadOnWiFi)
WCDB_PROPERTY(patternLockOn)
WCDB_PROPERTY(patternPassword)
WCDB_PROPERTY(secondsOfLockDelayed)
WCDB_PROPERTY(numberOfRemainingDrawing)
WCDB_PROPERTY(autoBackupAlbum)
WCDB_PROPERTY(stopBackupAlbumWhenLowBattery)
WCDB_PROPERTY(backupPhotos)
WCDB_PROPERTY(backupVideos)
WCDB_PROPERTY(totalBackup)
WCDB_PROPERTY(completedBackup)
WCDB_PROPERTY(isPauseAllDownload)
WCDB_PROPERTY(isPauseAllUpload)
WCDB_PROPERTY(notFirstAutoBackupAlbum)

@end
