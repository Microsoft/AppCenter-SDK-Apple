#import "MSSerializableDocument.h"


@class MSDataSourceError;

@interface MSDocumentWrapper : NSObject

/**
 * Deserialized document.
 */
@property(nonatomic, strong, readonly) MSSerializableDocument *deserializedValue;

/**
 * Cosmos Db document partition.
 */
@property(nonatomic, strong, readonly) NSString *partition;

/**
 * Document Id.
 */
@property(nonatomic, strong, readonly) NSString *documentId;

/**
 * Document eTag.
 */
@property(nonatomic, strong, readonly) NSString *eTag;

/**
 * Last update timestamp.
 */
@property(nonatomic, strong, readonly) NSDate *lastUpdatedDate;

/**
 * Document error.
 */
@property(nonatomic, strong, readonly) MSDataSourceError *error;

/**
 * Initialize a `MSDocumentWrapper` instance.
 *
 * @param deserializedValue The document value. Must conform to MSSerializableDocument protocol.
 * @param partition Partition key.
 * @param documentId Document id.
 * @param eTag Document eTag.
 * @param lastUpdatedDate Last updated date of the document.
 *
 * @return A new `MSDocumentWrapper` instance.
 */
- (instancetype)initWithDeserializedValue:(MSSerializableDocument *)deserializedValue
                                partition:(NSString *)partition
                               documentId:(NSString *)documentId
                                     eTag:(NSString *)eTag
                          lastUpdatedDate:(NSDate *)lastUpdatedDate;

/**
 * Initialize a `MSDocumentWrapper` instance.
 *
 * @param error Document error.
 * @param documentId Document Id.
 *
 * @return A new `MSDocumentWrapper` instance.
 */
- (instancetype)initWithError:(NSError *)error documentId:(NSString *)documentId;

/**
 * Check if the document is from the device cache.
 *
 * @return Flag indicating if the document was retrieved
 * from the device cache instead of from CosmosDB.
 */
- (BOOL)fromDeviceCache;

@end
