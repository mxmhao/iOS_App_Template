//
//  FileTask+WCTTableCoding.h

#import "FileTask.h"
#import <WCDB/WCDB.h>

@interface FileTask (WCTTableCoding) <WCTTableCoding>

WCDB_PROPERTY(Id)
WCDB_PROPERTY(mac)
WCDB_PROPERTY(userId)
WCDB_PROPERTY(fileName)
WCDB_PROPERTY(fileExt)
WCDB_PROPERTY(mediaType)
WCDB_PROPERTY(state)
WCDB_PROPERTY(size)
WCDB_PROPERTY(completedSize)
WCDB_PROPERTY(type)
WCDB_PROPERTY(serverPath)
WCDB_PROPERTY(createTime)
WCDB_PROPERTY(localPath)
WCDB_PROPERTY(currentFragment)
WCDB_PROPERTY(totalFragment)
WCDB_PROPERTY(assetLocalIdentifier)
WCDB_PROPERTY(filetype)
WCDB_PROPERTY(resumeDataName)

@end
