// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSDataSourceError.h"
#import "MSDataStorageConstants.h"
#import "MSDictionaryDocument.h"
#import "MSDocumentUtils.h"
#import "MSMockDocument.h"
#import "MSTestFrameworks.h"
#import "MSUtility+Date.h"
#import "NSObject+MSTestFixture.h"

@interface MSDocumentUtilsTests : XCTestCase

@end

@implementation MSDocumentUtilsTests

- (void)testDocumentPayloadWithDocumentIdReturnsCorrectDictionary {

  // If
  NSString *documentId = @"documentId";
  NSString *partition = @"partition";
  NSDictionary *document = @{@"documentKey" : @"documentValue"};

  // When
  NSDictionary *actualDic = [MSDocumentUtils documentPayloadWithDocumentId:documentId partition:partition document:document];

  // Then
  XCTAssertEqualObjects(actualDic[kMSDocument], document);
  XCTAssertEqualObjects(actualDic[kMSPartitionKey], partition);
  XCTAssertEqualObjects(actualDic[kMSIdKey], documentId);
}

- (void)testIsReferenceDictionaryWithKeyWithNilObject {

  // If, When, Then
  XCTAssertFalse([MSDocumentUtils isReferenceDictionaryWithKey:nil key:@"test" keyType:[NSString class]]);
}

- (void)testIsReferenceDictionaryWithKeyWithNonDictionary {

  // If
  NSString *someString = @"some string";

  // When, Then
  XCTAssertFalse([MSDocumentUtils isReferenceDictionaryWithKey:someString key:@"test" keyType:[NSString class]]);
}

- (void)testIsReferenceDictionaryWithDictionary {

  // If
  NSMutableDictionary *dictionary = [NSMutableDictionary new];
  dictionary[@"string"] = @"some string";
  dictionary[@"number"] = @42;
  dictionary[@"array"] = [NSArray new];

  // When, Then
  XCTAssertTrue([MSDocumentUtils isReferenceDictionaryWithKey:dictionary key:@"string" keyType:[NSString class]]);
  XCTAssertFalse([MSDocumentUtils isReferenceDictionaryWithKey:dictionary key:@"string" keyType:[NSNumber class]]);
  XCTAssertFalse([MSDocumentUtils isReferenceDictionaryWithKey:dictionary key:@"string" keyType:[NSArray class]]);
  XCTAssertFalse([MSDocumentUtils isReferenceDictionaryWithKey:dictionary key:@"number" keyType:[NSString class]]);
  XCTAssertTrue([MSDocumentUtils isReferenceDictionaryWithKey:dictionary key:@"number" keyType:[NSNumber class]]);
  XCTAssertFalse([MSDocumentUtils isReferenceDictionaryWithKey:dictionary key:@"number" keyType:[NSArray class]]);
  XCTAssertFalse([MSDocumentUtils isReferenceDictionaryWithKey:dictionary key:@"array" keyType:[NSString class]]);
  XCTAssertFalse([MSDocumentUtils isReferenceDictionaryWithKey:dictionary key:@"array" keyType:[NSNumber class]]);
  XCTAssertTrue([MSDocumentUtils isReferenceDictionaryWithKey:dictionary key:@"array" keyType:[NSArray class]]);
}

- (void)testDocumentWrapperFromDictionaryWithInvalidReference {

  // If
  NSString *badReference = @"bad reference";

  // When
  MSDocumentWrapper *document = [MSDocumentUtils documentWrapperFromDictionary:badReference documentType:[NSString class]];

  // Then
  XCTAssertNotNil(document);
  XCTAssertNotNil([document error]);
  XCTAssertNil([document documentId]);
  XCTAssertNil([document deserializedValue]);
  XCTAssertNil([document eTag]);
  XCTAssertNil([document lastUpdatedDate]);
  XCTAssertNil([document partition]);
  XCTAssertNil([document jsonValue]);
}

- (void)testDocumentWrapperFromDictionaryWithSystemPropertiesAndPartition {

  // If
  NSMutableDictionary *dictionary = [NSMutableDictionary new];
  dictionary[@"id"] = @"document-id";
  dictionary[@"_etag"] = @"etag";
  dictionary[@"_ts"] = @0;
  dictionary[@"PartitionKey"] = @"readonly";

  // When
  MSDocumentWrapper *document = [MSDocumentUtils documentWrapperFromDictionary:dictionary documentType:[NSString class]];

  // Then
  XCTAssertNotNil(document);
  XCTAssertNotNil([document error]);
  XCTAssertTrue([[document documentId] isEqualToString:@"document-id"]);
  XCTAssertNil([document deserializedValue]);
  XCTAssertTrue([[document eTag] isEqualToString:@"etag"]);
  XCTAssertNotNil([document lastUpdatedDate]);
  XCTAssertTrue([[document partition] isEqualToString:@"readonly"]);
  XCTAssertNotNil([document jsonValue]);

  // If, system property has incorrect type
  dictionary[@"_ts"] = @"some unexpected timestamp";

  // When
  document = [MSDocumentUtils documentWrapperFromDictionary:dictionary documentType:[NSString class]];

  // Then
  XCTAssertNotNil(document);
  XCTAssertNotNil([document error]);
  XCTAssertNil([document documentId]);
  XCTAssertNil([document deserializedValue]);
  XCTAssertNil([document eTag]);
  XCTAssertNil([document lastUpdatedDate]);
  XCTAssertNil([document partition]);
  XCTAssertNil([document jsonValue]);
}

- (void)testDocumentWrapperFromDictionaryWithDocument {

  // If
  NSMutableDictionary *dictionary = [NSMutableDictionary new];
  dictionary[@"id"] = @"document-id";
  dictionary[@"_etag"] = @"etag";
  dictionary[@"_ts"] = @0;
  dictionary[@"PartitionKey"] = @"readonly";
  dictionary[@"document"] = @"this should be a dictionary";

  // When
  MSDocumentWrapper *document = [MSDocumentUtils documentWrapperFromDictionary:dictionary documentType:[NSString class]];

  // Then
  XCTAssertNotNil(document);
  XCTAssertNotNil([document error]);
  XCTAssertTrue([[document documentId] isEqualToString:@"document-id"]);
  XCTAssertNil([document deserializedValue]);
  XCTAssertTrue([[document eTag] isEqualToString:@"etag"]);
  XCTAssertNotNil([document lastUpdatedDate]);
  XCTAssertTrue([[document partition] isEqualToString:@"readonly"]);
  XCTAssertNotNil([document jsonValue]);

  // If, document is a dictionary
  dictionary[@"document"] = [NSMutableDictionary new];
  dictionary[@"document"][@"property1"] = @"first property";
  dictionary[@"document"][@"property2"] = @123;

  // When
  document = [MSDocumentUtils documentWrapperFromDictionary:dictionary documentType:[MSDictionaryDocument class]];
  NSDictionary *resultDictionary = [[document deserializedValue] serializeToDictionary];

  // Then
  XCTAssertNotNil(document);
  XCTAssertNil([document error]);
  XCTAssertTrue([[document documentId] isEqualToString:@"document-id"]);
  XCTAssertNotNil([document deserializedValue]);
  XCTAssertTrue([resultDictionary[@"property1"] isEqualToString:@"first property"]);
  XCTAssertTrue([resultDictionary[@"property2"] isEqualToNumber:@123]);
  XCTAssertTrue([[document eTag] isEqualToString:@"etag"]);
  XCTAssertNotNil([document lastUpdatedDate]);
  XCTAssertTrue([[document partition] isEqualToString:@"readonly"]);
  XCTAssertNotNil([document jsonValue]);
}

- (void)testDocumentWrapperFromDictionaryWithUnserializable {
  // If
  NSMutableDictionary *documentDictionary = [NSMutableDictionary new];
  documentDictionary[@"shouldFail"] = [NSSet set];

  NSMutableDictionary *dictionary = [NSMutableDictionary new];
  dictionary[@"id"] = @"document-id";
  dictionary[@"_etag"] = @"etag";
  dictionary[@"_ts"] = @0;
  dictionary[@"PartitionKey"] = @"readonly";
  dictionary[@"document"] = documentDictionary;

  // When
  MSDocumentWrapper *document = [MSDocumentUtils documentWrapperFromDictionary:dictionary documentType:[NSString class]];

  // Then
  XCTAssertNotNil(document);
  XCTAssertNotNil([document error]);
  XCTAssertEqual([document documentId], @"document-id");
}

- (void)testDocumentWrapperFromDictionaryWithDate {
  // If
  NSMutableDictionary *documentDictionary = [NSMutableDictionary new];
  documentDictionary[@"date"] = [NSDate date];

  NSMutableDictionary *dictionary = [NSMutableDictionary new];
  dictionary[@"id"] = @"document-id";
  dictionary[@"_etag"] = @"etag";
  dictionary[@"_ts"] = @0;
  dictionary[@"PartitionKey"] = @"readonly";
  dictionary[@"document"] = documentDictionary;

  // When
  MSDocumentWrapper *document = [MSDocumentUtils documentWrapperFromDictionary:dictionary documentType:[NSString class]];

  // Then
  XCTAssertNotNil(document);
  XCTAssertNil([document error]);
  XCTAssertEqual([document documentId], @"document-id");
}

- (void)testDocumentWrapperFromDataNull {

  // If
  NSData *data;

  // When
  MSDocumentWrapper *document = [MSDocumentUtils documentWrapperFromData:data documentType:[NSString class]];

  // Then
  XCTAssertNotNil(document);
  XCTAssertNotNil([document error]);
  XCTAssertNil([document documentId]);
  XCTAssertNil([document deserializedValue]);
  XCTAssertNil([document eTag]);
  XCTAssertNil([document lastUpdatedDate]);
  XCTAssertNil([document partition]);
  XCTAssertNil([document jsonValue]);
}

- (void)testDocumentWrapperFromDataDeserializationError {

  // If
  NSData *data = [self jsonFixture:@"invalidTestDocument"];
  XCTAssertNotNil(data);

  // When
  MSDocumentWrapper *document = [MSDocumentUtils documentWrapperFromData:data documentType:[NSString class]];

  // Then
  XCTAssertNotNil(document);
  XCTAssertNotNil([document error]);
  XCTAssertNil([document documentId]);
  XCTAssertNil([document deserializedValue]);
  XCTAssertNil([document eTag]);
  XCTAssertNil([document lastUpdatedDate]);
  XCTAssertNil([document partition]);
  XCTAssertNil([document jsonValue]);
}

- (void)testDocumentWrapperFromDocumentDataDeserializationError {

  // If
  NSData *data = [self jsonFixture:@"invalidTestDocument"];
  XCTAssertNotNil(data);

  // When
  MSDocumentWrapper *document = [MSDocumentUtils documentWrapperFromDocumentData:data
                                                                    documentType:[NSString class]
                                                                            eTag:@"etag"
                                                                 lastUpdatedDate:[NSDate date]
                                                                       partition:@"partition"
                                                                      documentId:@"document-id"
                                                                pendingOperation:nil];

  // Then
  XCTAssertNotNil(document);
  XCTAssertNotNil([document error]);
  XCTAssertEqual([document documentId], @"document-id");
  XCTAssertNil([document deserializedValue]);
  XCTAssertNil([document eTag]);
  XCTAssertNil([document lastUpdatedDate]);
  XCTAssertNil([document partition]);
  XCTAssertNil([document jsonValue]);
}

- (void)testDocumentWrapperFromDataFixture {

  // If
  NSData *data;

  // When
  MSDocumentWrapper *document = [MSDocumentUtils documentWrapperFromData:data documentType:[NSString class]];

  // Then
  XCTAssertNotNil(document);
  XCTAssertNotNil([document error]);
  XCTAssertNil([document documentId]);
  XCTAssertNil([document deserializedValue]);
  XCTAssertNil([document eTag]);
  XCTAssertNil([document lastUpdatedDate]);
  XCTAssertNil([document partition]);
  XCTAssertNil([document jsonValue]);

  // If, data is set to a valid document
  data = [self jsonFixture:@"validTestDocument"];

  // When
  document = [MSDocumentUtils documentWrapperFromData:data documentType:[MSDictionaryDocument class]];
  NSDictionary *resultDictionary = [[document deserializedValue] serializeToDictionary];

  // Then
  XCTAssertNotNil(document);
  XCTAssertNil([document error]);
  XCTAssertTrue([[document documentId] isEqualToString:@"standalonedocument1"]);
  XCTAssertNotNil([document deserializedValue]);
  XCTAssertTrue([resultDictionary[@"property1"] isEqualToString:@"property number 1"]);
  XCTAssertTrue([resultDictionary[@"property2"] isEqualToNumber:@123]);
  XCTAssertTrue([[document eTag] isEqualToString:@"etag value"]);
  XCTAssertNotNil([document lastUpdatedDate]);
  XCTAssertTrue([[document partition] isEqualToString:@"readonly"]);
  XCTAssertNotNil([document jsonValue]);
}

- (void)testIsSerializableDocument {

  // If
  // NSProxy is not a NSObject, but it conforms to the NSObject protocol (light edge case testing).
  NSProxy *anotherRootObject = [NSProxy alloc];

  // When, Then
  XCTAssertFalse([MSDocumentUtils isSerializableDocument:[NSString class]]);
  XCTAssertFalse([MSDocumentUtils isSerializableDocument:object_getClass(anotherRootObject)]);
  XCTAssertTrue([MSDocumentUtils isSerializableDocument:[MSDictionaryDocument class]]);
}

- (void)testIsSerializableDictionary {

  // If
  NSMutableDictionary *dictionary; //= [NSMutableDictionary new];
  //[dictionary setObject:@"value" forKey:[NSNumber numberWithInt:2]];

  // Then
  XCTAssertTrue([NSJSONSerialization isValidJSONObject:dictionary]);
}

- (void)testIsSerializableDictionaryFake {

  // If
  NSMutableDictionary *dictionary = [NSMutableDictionary new];
  dictionary[@"timestamp"] = [NSDate date];

  // Then
  XCTAssertFalse([NSJSONSerialization isValidJSONObject:dictionary]);
}

@end
