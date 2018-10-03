#import "MSDBStorage.h"

NS_ASSUME_NONNULL_BEGIN

typedef int (^MSDBStorageQueryBlock)(void *);

// 4 KiB.
static const long kMSDefaultPageSizeInBytes = 4 * 1024;

// 10 MiB.
static const long kMSDefaultDatabaseSizeInBytes = 10 * 1024 * 1024;

@interface MSDBStorage ()

/**
 * Database file name.
 */
@property(nonatomic, readonly, nullable) NSURL *dbFileURL;

/**
 * Called when migration is needed. Override to customize.
 *
 * @param db Database handle.
 * @param version Current database version.
 */
- (void)migrateDatabase:(void *)db fromVersion:(NSUInteger)version;

/**
 * Open database to prepare actions in callback.
 *
 * @param block Actions to perform in query.
 */
- (int)executeQueryUsingBlock:(MSDBStorageQueryBlock)block;

/**
 * Check if a table exists in this database.
 *
 * @param tableName Table name.
 * @param db Database handle.
 *
 * @return `YES` if the table exists in the database, otherwise `NO`.
 */
+ (BOOL)tableExists:(NSString *)tableName inOpenedDatabase:(void *)db;

/**
 * Get current database version.
 *
 * @param db Database handle.
 */
+ (NSUInteger)versionInOpenedDatabase:(void *)db;

/**
 * Set current database version.
 *
 * @param db Database handle.
 */
+ (void)setVersion:(NSUInteger)version inOpenedDatabase:(void *)db;

/**
 * Execute a non selection SQLite query on the database (i.e.: "CREATE",
 * "INSERT", "UPDATE"... but not "SELECT").
 *
 * @param query An SQLite query to execute.
 * @param db Database handle.
 *
 * @return `YES` if the query executed successfully, otherwise `NO`.
 */
+ (int)executeNonSelectionQuery:(NSString *)query inOpenedDatabase:(void *)db;

/**
 * Execute a "SELECT" SQLite query on the database.
 *
 * @param query An SQLite "SELECT" query to execute.
 * @param db Database handle.
 *
 * @return The selected entries.
 */
+ (NSArray<NSArray *> *)executeSelectionQuery:(NSString *)query inOpenedDatabase:(void *)db;

@end

NS_ASSUME_NONNULL_END
