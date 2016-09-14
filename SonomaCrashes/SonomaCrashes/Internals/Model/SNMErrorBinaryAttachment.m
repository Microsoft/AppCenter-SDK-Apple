/*
 * Copyright (c) Microsoft Corporation. All rights reserved.
 */

#import "SNMErrorBinaryAttachment.h"

static NSString *const kSNMFilename = @"fileName";
static NSString *const kSNMData = @"data";
static NSString *const kSNMContentType = @"contentType";


@implementation SNMErrorBinaryAttachment

- (nonnull instancetype)initWithFileName:(nonnull NSString *)fileName
                  attachmentData:(nonnull NSData *)data
                     contentType:(nullable NSString *)contentType {
  if (self = [super init]) {
    _fileName = fileName;
    _data = data;

    if (contentType) {
      _contentType = contentType;
    } else {
      _contentType = @"application/octet-stream";
    }
  }

  return self;
}

- (NSMutableDictionary *)serializeToDictionary {
  NSMutableDictionary *dict = [NSMutableDictionary new];
  
  if (self.fileName) {
    dict[kSNMFilename] = self.fileName;
  }
  if(self.data) {
    dict[kSNMData] = self.data;
  }
  if(self.contentType) {
    dict[kSNMContentType] = self.contentType;
  }
  
  return dict;
}

#pragma mark - NSCoding
- (void)encodeWithCoder:(NSCoder *)encoder {
  if (self.fileName) {
    [encoder encodeObject:self.fileName forKey:kSNMFilename];
  }
  if (self.data) {
    [encoder encodeObject:self.data forKey:kSNMData];
  }
  [encoder encodeObject:self.contentType forKey:kSNMContentType];
}

- (instancetype)initWithCoder:(NSCoder *)decoder {
  if ((self = [super init])) {
    _fileName = [decoder decodeObjectForKey:kSNMFilename];
    _data = [decoder decodeObjectForKey:kSNMData];
    _contentType = [decoder decodeObjectForKey:kSNMContentType];
  }
  return self;
}

@end
