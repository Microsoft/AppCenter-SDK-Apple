/*
 * Copyright (c) Microsoft Corporation. All rights reserved.
 */

#import "SNMDevice.h"

static NSString *const kSNMSdkVersion = @"sdkVersion";
static NSString *const kSNMWrapperSdkVersion = @"wrapperSdkVersion";
static NSString *const kSNMWrapperSdkName = @"wrapperSdkName";
static NSString *const kSNMModel = @"model";
static NSString *const kSNMOemName = @"oemName";
static NSString *const kSNMOsName = @"osName";
static NSString *const kSNMOsVersion = @"osVersion";
static NSString *const kSNMOsBuild = @"osBuild";
static NSString *const kSNMOsApiLevel = @"osApiLevel";
static NSString *const kSNMLocale = @"locale";
static NSString *const kSNMTimeZoneOffset = @"timeZoneOffset";
static NSString *const kSNMScreenSize = @"screenSize";
static NSString *const kSNMAppVersion = @"appVersion";
static NSString *const kSNMCarrierName = @"carrierName";
static NSString *const kSNMCarrierCountry = @"carrierCountry";
static NSString *const kSNMAppBuild = @"appBuild";
static NSString *const kSNMAppNamespace = @"appNamespace";

@implementation SNMDevice

- (NSMutableDictionary *)serializeToDictionary {
  NSMutableDictionary *dict = [NSMutableDictionary new];

  if (self.sdkVersion) {
    dict[kSNMSdkVersion] = self.sdkVersion;
  }
  if (self.wrapperSdkVersion) {
    dict[kSNMWrapperSdkVersion] = self.wrapperSdkVersion;
  }
  if (self.wrapperSdkName) {
    dict[kSNMWrapperSdkName] = self.wrapperSdkName;
  }
  if (self.model) {
    dict[kSNMModel] = self.model;
  }
  if (self.oemName) {
    dict[kSNMOemName] = self.oemName;
  }
  if (self.osName) {
    dict[kSNMOsName] = self.osName;
  }
  if (self.osVersion) {
    dict[kSNMOsVersion] = self.osVersion;
  }
  if (self.osBuild) {
    dict[kSNMOsBuild] = self.osVersion;
  }
  if (self.osApiLevel) {
    dict[kSNMOsApiLevel] = self.osApiLevel;
  }
  if (self.locale) {
    dict[kSNMLocale] = self.locale;
  }
  if (self.timeZoneOffset) {
    dict[kSNMTimeZoneOffset] = self.timeZoneOffset;
  }
  if (self.screenSize) {
    dict[kSNMScreenSize] = self.screenSize;
  }
  if (self.appVersion) {
    dict[kSNMAppVersion] = self.appVersion;
  }
  if (self.carrierName) {
    dict[kSNMCarrierName] = self.carrierName;
  }
  if (self.carrierCountry) {
    dict[kSNMCarrierCountry] = self.carrierCountry;
  }
  if (self.appBuild) {
    dict[kSNMAppBuild] = self.appBuild;
  }
  if (self.appNamespace) {
    dict[kSNMAppNamespace] = self.appNamespace;
  }
  return dict;
}

- (BOOL)isValid {
  BOOL isValid = (!self.sdkVersion || !self.wrapperSdkVersion || !self.wrapperSdkName || !self.model || !self.oemName ||
                  !self.osName || !self.osVersion || !self.osBuild || !self.osApiLevel || !self.locale ||
                  !self.timeZoneOffset || !self.screenSize || !self.appVersion || !self.carrierName ||
                  !self.carrierCountry || !self.appBuild || !self.appNamespace);

  return isValid;
}

- (BOOL)isEqual:(SNMDevice *)device {

  if (!device)
    return NO;

  return ((!self.sdkVersion && !device.sdkVersion) || [self.sdkVersion isEqualToString:device.sdkVersion]) &&
         ((!self.wrapperSdkVersion && !device.wrapperSdkVersion) ||
          [self.wrapperSdkVersion isEqualToString:device.wrapperSdkVersion]) &&
         ((!self.wrapperSdkName && !device.wrapperSdkName) ||
          [self.wrapperSdkName isEqualToString:device.wrapperSdkName]) &&
         ((!self.model && !device.model) || [self.model isEqualToString:device.model]) &&
         ((!self.oemName && !device.oemName) || [self.oemName isEqualToString:device.oemName]) &&
         ((!self.osName && !device.osName) || [self.osName isEqualToString:device.osName]) &&
         ((!self.osVersion && !device.osVersion) || [self.osVersion isEqualToString:device.osVersion]) &&
         ((!self.osBuild && !device.osBuild) || [self.osBuild isEqualToString:device.osBuild]) &&
         ((!self.osApiLevel && !device.osApiLevel) || [self.osApiLevel isEqualToNumber:device.osApiLevel]) &&
         ((!self.locale && !device.locale) || [self.locale isEqualToString:device.locale]) &&
         ((!self.timeZoneOffset && !device.timeZoneOffset) ||
          [self.timeZoneOffset isEqualToNumber:device.timeZoneOffset]) &&
         ((!self.screenSize && !device.screenSize) || [self.screenSize isEqualToString:device.screenSize]) &&
         ((!self.appVersion && !device.appVersion) || [self.appVersion isEqualToString:device.appVersion]) &&
         ((!self.carrierName && !device.carrierName) || [self.carrierName isEqualToString:device.carrierName]) &&
         ((!self.carrierCountry && !device.carrierCountry) ||
          [self.carrierCountry isEqualToString:device.carrierCountry]) &&
         ((!self.appBuild && !device.appBuild) || [self.appBuild isEqualToString:device.appBuild]) &&
         ((!self.appNamespace && !device.appNamespace) || [self.appNamespace isEqualToString:device.appNamespace]);
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)coder {
  self = [super init];
  if (self) {
    _sdkVersion = [coder decodeObjectForKey:kSNMSdkVersion];
    _wrapperSdkVersion = [coder decodeObjectForKey:kSNMWrapperSdkVersion];
    _wrapperSdkName = [coder decodeObjectForKey:kSNMWrapperSdkName];
    _model = [coder decodeObjectForKey:kSNMModel];
    _oemName = [coder decodeObjectForKey:kSNMOemName];
    _osName = [coder decodeObjectForKey:kSNMOsName];
    _osVersion = [coder decodeObjectForKey:kSNMOsVersion];
    _osBuild = [coder decodeObjectForKey:kSNMOsBuild];
    _osApiLevel = [coder decodeObjectForKey:kSNMOsApiLevel];
    _locale = [coder decodeObjectForKey:kSNMLocale];
    _timeZoneOffset = [coder decodeObjectForKey:kSNMTimeZoneOffset];
    _screenSize = [coder decodeObjectForKey:kSNMScreenSize];
    _appVersion = [coder decodeObjectForKey:kSNMAppVersion];
    _carrierName = [coder decodeObjectForKey:kSNMCarrierName];
    _carrierCountry = [coder decodeObjectForKey:kSNMCarrierCountry];
    _appBuild = [coder decodeObjectForKey:kSNMAppBuild];
    _appNamespace = [coder decodeObjectForKey:kSNMAppNamespace];
  }
  return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
  [coder encodeObject:self.sdkVersion forKey:kSNMSdkVersion];
  [coder encodeObject:self.wrapperSdkVersion forKey:kSNMWrapperSdkVersion];
  [coder encodeObject:self.wrapperSdkName forKey:kSNMWrapperSdkName];
  [coder encodeObject:self.model forKey:kSNMModel];
  [coder encodeObject:self.oemName forKey:kSNMOemName];
  [coder encodeObject:self.osName forKey:kSNMOsName];
  [coder encodeObject:self.osVersion forKey:kSNMOsVersion];
  [coder encodeObject:self.osBuild forKey:kSNMOsBuild];
  [coder encodeObject:self.osApiLevel forKey:kSNMOsApiLevel];
  [coder encodeObject:self.locale forKey:kSNMLocale];
  [coder encodeObject:self.timeZoneOffset forKey:kSNMTimeZoneOffset];
  [coder encodeObject:self.screenSize forKey:kSNMScreenSize];
  [coder encodeObject:self.appVersion forKey:kSNMAppVersion];
  [coder encodeObject:self.carrierName forKey:kSNMCarrierName];
  [coder encodeObject:self.carrierCountry forKey:kSNMCarrierCountry];
  [coder encodeObject:self.appBuild forKey:kSNMAppBuild];
  [coder encodeObject:self.appNamespace forKey:kSNMAppNamespace];
}

@end
