//
//  FileTask.mm
//  本类用'WCDB'的'WCTTable'操作数据库
//  insertOrReplaceObject 1.0.5、1.0.6有bug

#import "FileTask.h"
#import "FileTask+WCTTableCoding.h"
#import "User.h"

static NSString *const FileTaskTableNameKey = @"FileTask";
static NSString *const FileTaskDBFileKey = @"filetask.sqlite";

NS_INLINE
WCTDatabase * FileTaskDatabase()
{
    static NSString *path = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:FileTaskDBFileKey];
    });
    return [[WCTDatabase alloc] initWithPath:path];
}

NS_INLINE
WCTTable * FileTaskTable()
{
    return [FileTaskDatabase() getTableOfName:FileTaskTableNameKey withClass:FileTask.class];
}

@interface FileTask ()

@property (nonatomic, assign) NSUInteger Id;

@end

@implementation FileTask
{
    NSString *_createTimeFormatString;   //创建时间格式化的字符串
}

WCDB_IMPLEMENTATION(FileTask)

WCDB_SYNTHESIZE(FileTask, Id)
WCDB_SYNTHESIZE(FileTask, mac)
WCDB_SYNTHESIZE(FileTask, userId)
WCDB_SYNTHESIZE(FileTask, fileName)
WCDB_SYNTHESIZE(FileTask, fileExt)
WCDB_SYNTHESIZE(FileTask, mediaType)
WCDB_SYNTHESIZE(FileTask, state)
WCDB_SYNTHESIZE(FileTask, size)
WCDB_SYNTHESIZE(FileTask, completedSize)
WCDB_SYNTHESIZE(FileTask, type)
WCDB_SYNTHESIZE(FileTask, serverPath)
WCDB_SYNTHESIZE(FileTask, createTime)
WCDB_SYNTHESIZE(FileTask, localPath)
WCDB_SYNTHESIZE(FileTask, currentFragment)
WCDB_SYNTHESIZE(FileTask, totalFragment)
WCDB_SYNTHESIZE(FileTask, assetLocalIdentifier)
WCDB_SYNTHESIZE(FileTask, filetype)
WCDB_SYNTHESIZE(FileTask, resumeDataName)

WCDB_PRIMARY_AUTO_INCREMENT(FileTask, Id)
//WCDB_PRIMARY_ASC_AUTO_INCREMENT(FileTask, Id)

+ (BOOL)createTable
{
    return [FileTaskDatabase() createTableAndIndexesOfName:FileTaskTableNameKey withClass:self];
}

+ (NSInteger)fileTaskMaxId
{
    return [[FileTaskTable() getOneValueOnResult:self.Id.max()] integerValue];
}

+ (NSArray<FileTask *> *)progressFileTasksForUser:(User *)user taskType:(FileTaskType)type
{
    return [FileTaskTable() getObjectsWhere:(self.mac == user.mac) && (self.userId == user.Id) && (self.type == type) && (self.state != FileTaskStatusCompleted && self.state != FileTaskStatusError) orderBy:self.Id.order(WCTOrderedAscending)];
}

+ (NSArray<FileTask *> *)progressFileTasksForUser:(User *)user taskType:(FileTaskType)type offset:(NSUInteger)offset
{
    return [FileTaskTable() getObjectsWhere:(self.mac == user.mac) && (self.userId == user.Id) && (self.type == type) && (self.state != FileTaskStatusCompleted && self.state != FileTaskStatusError) orderBy:self.Id.order(WCTOrderedAscending) offset:offset];
}

+ (NSArray<FileTask *> *)progressFileTasksForUser:(User *)user taskType:(FileTaskType)type idGreaterThan:(NSInteger)Id
{
    return [FileTaskTable() getObjectsWhere:(self.mac == user.mac) && (self.userId == user.Id) && (self.type == type) && (self.state != FileTaskStatusCompleted && self.state != FileTaskStatusError) && (self.Id > Id) orderBy:self.Id.order(WCTOrderedAscending)];
}

+ (NSArray<FileTask *> *)successFileTasksForUser:(User *)user taskType:(FileTaskType)type
{
    return [FileTaskTable() getObjectsWhere:(self.mac == user.mac) && (self.userId == user.Id) && (self.type == type) && (self.state == FileTaskStatusCompleted) orderBy:self.Id.order(WCTOrderedAscending)];
}

+ (NSArray<FileTask *> *)failureFileTasksForUser:(User *)user taskType:(FileTaskType)type
{
    return [FileTaskTable() getObjectsWhere:(self.mac == user.mac) && (self.userId == user.Id) && (self.type == type) && (self.state == FileTaskStatusError) orderBy:self.Id.order(WCTOrderedAscending)];
}

+ (BOOL)addFileTasks:(NSArray<FileTask *> *)fileTasks
{
    return [FileTaskTable() insertObjects:fileTasks];
}

+ (BOOL)isExistsFileTaskForUser:(User *)user serverPath:(NSString *)serverPath fileTaskType:(FileTaskType)type
{
    return [[FileTaskTable() getOneValueOnResult:self.AnyProperty.count() where:self.mac == user.mac && self.userId == user.Id && self.type == type && self.serverPath == serverPath] intValue] > 0;
}

+ (BOOL)deleteAllFileTasksForUser:(User *)user forType:(FileTaskType)type
{
    return [FileTaskTable() deleteObjectsWhere:self.mac == user.mac && self.userId == user.Id && self.type == type];
}

+ (BOOL)deleteFileTask:(FileTask *)ftask
{
    return [FileTaskTable() deleteObjectsWhere:self.Id == ftask.Id];
}

//(NSArray<FileTask *> *)ftasks
//+ (BOOL)deleteFileTaskWithIDs:(NSIndexSet *)indexSet
//{
//    return [FileTaskTable() deleteObjectsWhere:self.Id.in(indexSet)];
//}

+ (BOOL)deleteFileTaskWithIDs:(NSArray<NSNumber *> *)ids
{
    return [FileTaskTable() deleteObjectsWhere:self.Id.in(ids)];
}

+ (BOOL)updateFileTasks:(NSArray<FileTask *> *)fileTasks
{
    return [FileTaskTable() insertOrReplaceObjects:fileTasks onProperties:{self.state, self.size, self.completedSize, self.currentFragment, self.totalFragment, self.localPath, self.resumeDataName}];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _Id = 0;
        _canUpload = YES;
    }
    return self;
}

- (instancetype)initForInsert
{
    self = [super init];
    if (self) {
        _Id = 0;
        _canUpload = YES;
        self.isAutoIncrement = YES;
    }
    return self;
}

- (BOOL)updateToLocal
{
    WCTTable *table = FileTaskTable();
    if (0 == _Id) {
        //这个是自增插入要做的事
        self.isAutoIncrement = YES;
        BOOL result = [table insertObject:self];
        _Id = self.lastInsertedRowID;//获取最新的id
        self.isAutoIncrement = NO;
        return result;
    }
//    return [table insertOrReplaceObject:self];//1.0.5此方法有bug
    return [table updateRowsOnProperties:self.class.AllProperties withObject:self where:self.class.Id == _Id];
}

- (BOOL)updateStatusToLocal
{
    return [FileTaskTable() updateRowsOnProperties:{self.class.state, self.class.size, self.class.completedSize, self.class.currentFragment, self.class.totalFragment, self.class.localPath, self.class.resumeDataName} withObject:self where:self.class.Id == _Id];
//    return [FileTaskTable() insertOrReplaceObject:self onProperties:{self.class.state, self.class.size, self.class.completedSize}];//这个有bug
}

- (BOOL)isEqual:(FileTask *)other
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
        return [other->_mac isEqual:_mac] && other->_userId == _userId && [other->_serverPath isEqual:_serverPath];
    }
}

- (NSUInteger)hash
{
    if (_Id > 0) {
        return _Id;
    }
    return _mac.hash ^ _userId ^ _serverPath.hash;
}

#pragma mark - 计算属性
- (NSString *)speedFormatString
{
    return [[NSByteCountFormatter stringFromByteCount:_transmissionSpeed countStyle:NSByteCountFormatterCountStyleBinary] stringByAppendingString:@"/s"];
}

- (NSString *)sizeFormatString
{
    if (nil == _sizeFormatString) {
        _sizeFormatString = [NSByteCountFormatter stringFromByteCount:_size countStyle:NSByteCountFormatterCountStyleBinary];
    }
    return _sizeFormatString;
}

- (NSString *)completedSizeFormatString
{
    return [NSByteCountFormatter stringFromByteCount:_completedSize countStyle:NSByteCountFormatterCountStyleBinary];
}

- (NSString *)createTimeFormatString
{
    if (nil == _createTimeFormatString) {
        _createTimeFormatString = [NSDateFormatter localizedStringFromDate:[NSDate dateWithTimeIntervalSince1970:_createTime] dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterShortStyle];
    }
    return _createTimeFormatString;
}

@end
