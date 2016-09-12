#import "SNMFile.h"
#import <Foundation/Foundation.h>

@interface SNMStorageTestHelper : NSObject

+ (NSString *)logsDir;
+ (NSString *)storageDirForStorageKey:(NSString *)storageKey;
+ (NSString *)filePathForLogWithId:(NSString *)logsId extension:(NSString *)extension storageKey:(NSString *)storageKey;
+ (SNMFile *)createFileWithId:(NSString *)logsId
                         data:(NSData *)data
                    extension:(NSString *)extension
                   storageKey:(NSString *)storageKey
                 creationDate:(NSDate *)creationDate;
+ (void)createDirectoryAtPath:(NSString *)directoryPath;
+ (void)resetLogsDirectory;

@end
