/*
 * Copyright (c) Microsoft Corporation. All rights reserved.
 */

#import "MSConstants+Internal.h"
#import "MSDevicePrivate.h"
#import "MSDeviceTracker.h"
#import "MSDeviceTrackerPrivate.h"
#import "MSUtil.h"
#import "MSWrapperSdkPrivate.h"

// SDK versioning struct. Needs to be big enough to hold the info.
typedef struct {
    uint8_t info_version;
    const char ms_name[32];
    const char ms_version[32];
    const char ms_build[32];
} ms_info_t;

// SDK versioning.
ms_info_t mobilecenter_library_info __attribute__((section("__TEXT,__ms_ios,regular,no_dead_strip"))) = {
        .info_version = 1,
        .ms_name = MOBILE_CENTER_C_NAME,
        .ms_version = MOBILE_CENTER_C_VERSION,
        .ms_build = MOBILE_CENTER_C_BUILD
};

@implementation MSDeviceTracker : NSObject

@synthesize device = _device;

static MSWrapperSdk *wrapperSdkInformation = nil;
static BOOL needRefresh = YES;

+ (void)setWrapperSdk:(MSWrapperSdk *)wrapperSdk {
  @synchronized (self) {
    wrapperSdkInformation = wrapperSdk;
    needRefresh = YES;
  }
}

/**
 *  Get the current device log.
 */
- (MSDevice *)device {
  @synchronized (self) {

    // Lazy creation.
    if (!_device || needRefresh) {
      [self refresh];
    }
    return _device;
  }
}

/**
 *  Refresh device properties.
 */
- (void)refresh {
  @synchronized (self) {
    MSDevice *newDevice = [[MSDevice alloc] init];
    NSBundle *appBundle = [NSBundle mainBundle];
    CTCarrier *carrier = [[[CTTelephonyNetworkInfo alloc] init] subscriberCellularProvider];

    // Collect device properties.
    newDevice.sdkName = [self sdkName:mobilecenter_library_info.ms_name];
    newDevice.sdkVersion = [self sdkVersion:mobilecenter_library_info.ms_version];
    newDevice.model = [self deviceModel];
    newDevice.oemName = kMSDeviceManufacturer;
    newDevice.osName = [self osName:MS_DEVICE];
    newDevice.osVersion = [self osVersion:MS_DEVICE];
    newDevice.osBuild = [self osBuild];
    newDevice.locale = [self locale:MS_LOCALE];
    newDevice.timeZoneOffset = [self timeZoneOffset:[NSTimeZone localTimeZone]];
    newDevice.screenSize = [self screenSize];
    newDevice.appVersion = [self appVersion:appBundle];
    newDevice.carrierCountry = [self carrierCountry:carrier];
    newDevice.carrierName = [self carrierName:carrier];
    newDevice.appBuild = [self appBuild:appBundle];
    newDevice.appNamespace = [self appNamespace:appBundle];

    // Add wrapper SDK information
    [self refreshWrapperSdk:newDevice];

    // Set the new device info.
    _device = newDevice;
    needRefresh = NO;
  }
}

/**
 *  Refresh wrapper SDK properties.
 */
- (void)refreshWrapperSdk:(MSDevice *)device {
  if (wrapperSdkInformation) {
    device.wrapperSdkVersion = wrapperSdkInformation.wrapperSdkVersion;
    device.wrapperSdkName = wrapperSdkInformation.wrapperSdkName;
    device.liveUpdateReleaseLabel = wrapperSdkInformation.liveUpdateReleaseLabel;
    device.liveUpdateDeploymentKey = wrapperSdkInformation.liveUpdateDeploymentKey;
    device.liveUpdatePackageHash = wrapperSdkInformation.liveUpdatePackageHash;
  }
}

#pragma mark - Helpers

- (NSString *)sdkName:(const char[])name {
  return [NSString stringWithUTF8String:name];
}

- (NSString *)sdkVersion:(const char[])version {
  return [NSString stringWithUTF8String:version];
}

- (NSString *)deviceModel {
  size_t size;
  sysctlbyname("hw.machine", NULL, &size, NULL, 0);
  char *machine = malloc(size);
  sysctlbyname("hw.machine", machine, &size, NULL, 0);
  NSString *model = [NSString stringWithCString:machine encoding:NSUTF8StringEncoding];
  free(machine);
  return model;
}

- (NSString *)osName:(UIDevice *)device {
  return device.systemName;
}

- (NSString *)osVersion:(UIDevice *)device {
  return device.systemVersion;
}

- (NSString *)osBuild {
  size_t size;
  sysctlbyname("kern.osversion", NULL, &size, NULL, 0);
  char *answer = (char *) malloc(size);
  if (answer == NULL)
    return nil; // returning nil to avoid a possible crash.
  sysctlbyname("kern.osversion", answer, &size, NULL, 0);
  NSString *osBuild = [NSString stringWithCString:answer encoding:NSUTF8StringEncoding];
  free(answer);
  return osBuild;
}

- (NSString *)locale:(NSLocale *)currentLocale {
  return [currentLocale objectForKey:NSLocaleIdentifier];
}

- (NSNumber *)timeZoneOffset:(NSTimeZone *)timeZone {
  return @([timeZone secondsFromGMT] / 60);
}

- (NSString *)screenSize {
  CGFloat scale = [UIScreen mainScreen].scale;
  CGSize screenSize = [UIScreen mainScreen].bounds.size;
  return [NSString stringWithFormat:@"%dx%d", (int) (screenSize.height * scale), (int) (screenSize.width * scale)];
}

- (NSString *)carrierName:(CTCarrier *)carrier {
  return ([carrier.carrierName length] > 0) ? carrier.carrierName : nil;
}

- (NSString *)carrierCountry:(CTCarrier *)carrier {
  return ([carrier.isoCountryCode length] > 0) ? carrier.isoCountryCode : nil;
}

- (NSString *)appVersion:(NSBundle *)appBundle {
  return [appBundle infoDictionary][@"CFBundleShortVersionString"];
}

- (NSString *)appBuild:(NSBundle *)appBundle {
  return [appBundle infoDictionary][@"CFBundleVersion"];
}

- (NSString *)appNamespace:(NSBundle *)appBundle {
  return [appBundle bundleIdentifier];
}

@end
