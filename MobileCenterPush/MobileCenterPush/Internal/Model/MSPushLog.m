#import "MSPushLog.h"

static NSString *const kMSTypePushInstallationType = @"push_type";
static NSString *const kMSDeviceToken = @"device_token";

@implementation MSPushLog

@synthesize type = _type;

- (instancetype)init {
  self = [super init];
  if (self) {
    _type = kMSTypePushInstallationType;
  }
  return self;
}

- (NSMutableDictionary *)serializeToDictionary {
  NSMutableDictionary *dict = [super serializeToDictionary];
  if (self.deviceToken) {
    dict[kMSDeviceToken] = self.deviceToken;
  }
  return dict;
}

- (BOOL)isValid {
  return [super isValid] && self.deviceToken;
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)coder {
  self = [super initWithCoder:coder];
  if (self) {
    _type = [coder decodeObjectForKey:kMSTypePushInstallationType];
    _deviceToken = [coder decodeObjectForKey:kMSDeviceToken];
  }
  return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
  [super encodeWithCoder:coder];
  [coder encodeObject:self.type forKey:kMSTypePushInstallationType];
  [coder encodeObject:self.deviceToken forKey:kMSDeviceToken];
}

@end
