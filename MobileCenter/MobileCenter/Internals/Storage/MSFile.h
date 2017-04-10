#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 A class that represents a file on the file system.
 */
@interface MSFile : NSObject

/**
 * The creation date of the file.
 */
@property(nonatomic) NSDate *creationDate;

/**
 * The unique identifier for this file.
 */
@property(nonatomic, copy) NSString *fileId;

/**
 * The url to the file.
 */
@property(nonatomic, copy) NSURL *fileURL;

/**
 * Returns a new `MSFile` instance with a given file id and creation date.
 *
 * @param fileURL the url to the file
 * @param fileId a unique file identifier
 * @param creationDate the creation date of the file
 *
 * @return a new `MSFile` instance
 */
- (instancetype)initWithURL:(NSURL *)fileURL fileId:(NSString *)fileId creationDate:(NSDate *)creationDate;

@end

NS_ASSUME_NONNULL_END
