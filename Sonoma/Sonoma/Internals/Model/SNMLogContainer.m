/*
 * Copyright (c) Microsoft Corporation. All rights reserved.
 */

#import "SNMLogContainer.h"
#import "SNMSerializableObject.h"

@implementation SNMLogContainer

- (id)initWithBatchId:(NSString *)batchId andLogs:(NSArray<SNMLog> *)logs {
  if (self = [super init]) {
    self.batchId = batchId;
    self.logs = logs;
  }
  return self;
}

- (NSString *)serializeLog {
  return [self serializeLogWithPrettyPrinting:NO];
}

- (NSString *)serializeLogWithPrettyPrinting:(BOOL)prettyPrint {
  NSString *jsonString;
  NSMutableArray *jsonArray = [NSMutableArray array];
  [self.logs enumerateObjectsUsingBlock:^(id _Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
    NSMutableDictionary *dict = [obj serializeToDictionary];
    if (dict) {
      [jsonArray addObject:dict];
    }
  }];

  NSError *error;
  NSJSONWritingOptions printOptions = prettyPrint ? NSJSONWritingPrettyPrinted : 0;
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonArray options:printOptions error:&error];

  if (!jsonData) {
    NSLog(@"Got an error: %@", error);
  } else {
    jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
  }
  return jsonString;
}

- (BOOL)isValid {

  // Check for empty container
  if ([self.logs count] == 0)
    return NO;

  __block BOOL isValid = YES;
  [self.logs enumerateObjectsUsingBlock:^(id _Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
    if (![obj isValid]) {
      *stop = YES;
      isValid = NO;
      return;
    }
  }];
  return isValid;
}

@end
