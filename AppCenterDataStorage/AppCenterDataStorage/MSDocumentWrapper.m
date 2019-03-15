#import "MSDocumentWrapper.h"
#import "MSDataSourceError.h"
#import "MSSerializableObject.h"

@implementation MSDocumentWrapper

@synthesize deserializedValue = _deserializedValue;
@synthesize documentId = _documentId;
@synthesize partition = _partition;
@synthesize eTag = _eTag;
@synthesize lastUpdatedDate = _lastUpdatedDate;
@synthesize error = _error;

- (instancetype)initWithDeserializedValue:(MSSerializableDocument *)deserializedValue
                                partition:(NSString *)partition
                               documentId:(NSString *)documentId
                                     eTag:(NSString *)eTag
                          lastUpdatedDate:(NSDate *)lastUpdatedDate {
  if ((self = [super init])) {
    _deserializedValue = deserializedValue;
    _partition = partition;
    _documentId = documentId;
    _eTag = eTag;
    _lastUpdatedDate = lastUpdatedDate;
  }
  return self;
}

- (instancetype)initWithError:(NSError *)error documentId:(NSString *)documentId {
  if ((self = [super init])) {
    _documentId = documentId;
    _error = [[MSDataSourceError alloc] initWithError:error];
  }
  return self;
}

- (BOOL)fromDeviceCache {
  // @todo
  return false;
}

@end
