#import "MSDataSourceError.h"
#import "MSDocumentWrapper.h"
#import "MSSerializableDocument.h"

@interface MSPage : NSObject

/**
 * Continuation token for retrieving the next page from CosmosDB.
 */
@property(readonly) NSString *continuationToken;

/**
 * Error (or null).
 */
@property(readonly) MSDataSourceError *error;

/**
 * Array of documents in the current page (or null).
 */
@property(readonly) NSArray<MSDocumentWrapper *> *items;

@end
