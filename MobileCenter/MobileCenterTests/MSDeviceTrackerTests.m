#import <OCHamcrestIOS/OCHamcrestIOS.h>
#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>
#import "MSDevice.h"
#import "MSDeviceHistoryInfo.h"
#import "MSDeviceInternal.h"
#import "MSDeviceTracker.h"
#import "MSDeviceTrackerPrivate.h"
#import "MSMockUserDefaults.h"
#import "MSUtility+Date.h"
#import "MSWrapperSdkInternal.h"

static NSString *const kMSDeviceManufacturerTest = @"Apple";

@interface MSDeviceTrackerTests : XCTestCase

@property(nonatomic) MSDeviceTracker *sut;

@end

@implementation MSDeviceTrackerTests

- (void)setUp {
  [super setUp];
  // System Under Test.
  self.sut = [MSDeviceTracker sharedInstance];
}

- (void)tearDown {
  [super tearDown];
}

- (void)testDeviceInfo {

  assertThat(self.sut.device.sdkVersion, notNilValue());
  assertThatInteger([self.sut.device.sdkVersion length], greaterThan(@(0)));

  assertThat(self.sut.device.model, notNilValue());
  assertThatInteger([self.sut.device.model length], greaterThan(@(0)));

  assertThat(self.sut.device.oemName, is(kMSDeviceManufacturerTest));

  assertThat(self.sut.device.osName, notNilValue());
  assertThatInteger([self.sut.device.osName length], greaterThan(@(0)));

  assertThat(self.sut.device.osVersion, notNilValue());
  assertThatInteger([self.sut.device.osVersion length], greaterThan(@(0)));
  assertThatFloat([self.sut.device.osVersion floatValue], greaterThan(@(0.0)));

  assertThat(self.sut.device.locale, notNilValue());
  assertThatInteger([self.sut.device.locale length], greaterThan(@(0)));

  assertThat(self.sut.device.timeZoneOffset, notNilValue());

  assertThat(self.sut.device.screenSize, notNilValue());

  // Can't access carrier name and country in test context but it's optional and in that case it has to be nil.
  assertThat(self.sut.device.carrierCountry, nilValue());
  assertThat(self.sut.device.carrierName, nilValue());

  // Can't access a valid main bundle from test context so we can't test for App namespace (bundle ID), version and
  // build.
}

- (void)testSDKVersion {

  // If
  NSString *expected = @"1.2.3";
  const char *versionMock = [expected UTF8String];

  // When
  NSString *sdkVersion = [self.sut sdkVersion:versionMock];

  // Then
  assertThat(sdkVersion, is(expected));
}

- (void)testDeviceModel {

  // When
  NSString *model = [self.sut deviceModel];

  // Then
  assertThat(model, notNilValue());
  assertThatInteger([model length], greaterThan(@(0)));
}

- (void)testDeviceOSName {

  // If
  NSString *expected = @"iMock OS";
  UIDevice *deviceMock = OCMClassMock([UIDevice class]);
  OCMStub([deviceMock systemName]).andReturn(expected);

  // When
  NSString *osName = [self.sut osName:deviceMock];

  // Then
  assertThat(osName, is(expected));
}

- (void)testDeviceOSVersion {

  // If
  NSString *expected = @"4.5.6";
  UIDevice *deviceMock = OCMClassMock([UIDevice class]);
  OCMStub([deviceMock systemVersion]).andReturn(expected);

  // When
  NSString *osVersion = [self.sut osVersion:deviceMock];

  // Then
  assertThat(osVersion, is(expected));
}

- (void)testDeviceLocale {

  // If
  NSString *expected = @"en-US";
  UIDevice *deviceMock = OCMClassMock([UIDevice class]);
  OCMStub([deviceMock systemVersion]).andReturn(expected);

  // When
  NSString *osVersion = [self.sut osVersion:deviceMock];

  // Then
  assertThat(osVersion, is(expected));
}

- (void)testDeviceTimezoneOffset {

  // If
  NSNumber *expected = @(-420);
  NSTimeZone *tzMock = OCMClassMock([NSTimeZone class]);
  OCMStub([tzMock secondsFromGMT]).andReturn(-25200);

  // When
  NSNumber *tz = [self.sut timeZoneOffset:tzMock];

  // Then
  assertThat(tz, is(expected));
}

- (void)testDeviceScreenSize {

  // When
  NSString *screenSize = [self.sut screenSize];

  // Then
  assertThat(screenSize, notNilValue());
  assertThatInteger([screenSize length], greaterThan(@(0)));
}

- (void)testCarrierName {

  // If
  NSString *expected = @"MobileParadise";
  CTCarrier *carrierMock = OCMClassMock([CTCarrier class]);
  OCMStub([carrierMock carrierName]).andReturn(expected);

  // When
  NSString *carrierName = [self.sut carrierName:carrierMock];

  // Then
  assertThat(carrierName, is(expected));
}

- (void)testNoCarrierName {

  // If
  CTCarrier *carrierMock = OCMClassMock([CTCarrier class]);
  OCMStub([carrierMock carrierName]).andReturn(nil);

  // When
  NSString *carrierName = [self.sut carrierName:carrierMock];

  // Then
  assertThat(carrierName, nilValue());
}

- (void)testCarrierCountry {

  // If
  NSString *expected = @"US";
  CTCarrier *carrierMock = OCMClassMock([CTCarrier class]);
  OCMStub([carrierMock isoCountryCode]).andReturn(expected);

  // When
  NSString *carrierCountry = [self.sut carrierCountry:carrierMock];

  // Then
  assertThat(carrierCountry, is(expected));
}

- (void)testNoCarrierCountry {

  // If
  CTCarrier *carrierMock = OCMClassMock([CTCarrier class]);
  OCMStub([carrierMock isoCountryCode]).andReturn(nil);

  // When
  NSString *carrierCountry = [self.sut carrierCountry:carrierMock];

  // Then
  assertThat(carrierCountry, nilValue());
}

- (void)testAppVersion {

  // If
  NSString *expected = @"7.8.9";
  NSDictionary<NSString *, id> *plist = @{ @"CFBundleShortVersionString" : expected };
  NSBundle *bundleMock = OCMClassMock([NSBundle class]);
  OCMStub([bundleMock infoDictionary]).andReturn(plist);

  // When
  NSString *appVersion = [self.sut appVersion:bundleMock];

  // Then
  assertThat(appVersion, is(expected));
}

- (void)testAppBuild {

  // If
  NSString *expected = @"42";
  NSDictionary<NSString *, id> *plist = @{ @"CFBundleVersion" : expected };
  NSBundle *bundleMock = OCMClassMock([NSBundle class]);
  OCMStub([bundleMock infoDictionary]).andReturn(plist);

  // When
  NSString *appBuild = [self.sut appBuild:bundleMock];

  // Then
  assertThat(appBuild, is(expected));
}

- (void)testAppNamespace {

  // If
  NSString *expected = @"com.microsoft.test.app";
  NSBundle *bundleMock = OCMClassMock([NSBundle class]);
  OCMStub([bundleMock bundleIdentifier]).andReturn(expected);

  // When
  NSString *appNamespace = [self.sut appNamespace:bundleMock];

  // Then
  assertThat(appNamespace, is(expected));
}

- (void)testWrapperSdk {

  // If
  MSWrapperSdk *wrapperSdk = [[MSWrapperSdk alloc] initWithWrapperSdkVersion:@"10.11.12"
                                                              wrapperSdkName:@"Wrapper SDK for iOS"
                                                       wrapperRuntimeVersion:@"13.14"
                                                      liveUpdateReleaseLabel:@"Release Label"
                                                     liveUpdateDeploymentKey:@"Deployment Key"
                                                       liveUpdatePackageHash:@"Package Hash"];

  // When
  [[MSDeviceTracker sharedInstance] setWrapperSdk:wrapperSdk];
  MSDevice *device = self.sut.device;

  // Then
  XCTAssertEqual(device.wrapperSdkVersion, wrapperSdk.wrapperSdkVersion);
  XCTAssertEqual(device.wrapperSdkName, wrapperSdk.wrapperSdkName);
  XCTAssertEqual(device.wrapperRuntimeVersion, wrapperSdk.wrapperRuntimeVersion);
  XCTAssertEqual(device.liveUpdateReleaseLabel, wrapperSdk.liveUpdateReleaseLabel);
  XCTAssertEqual(device.liveUpdateDeploymentKey, wrapperSdk.liveUpdateDeploymentKey);
  XCTAssertEqual(device.liveUpdatePackageHash, wrapperSdk.liveUpdatePackageHash);

  // Update wrapper SDK
  // If
  wrapperSdk.wrapperSdkVersion = @"10.11.13";

  // When
  [[MSDeviceTracker sharedInstance] setWrapperSdk:wrapperSdk];

  // Then
  XCTAssertNotEqual(device.wrapperSdkVersion, wrapperSdk.wrapperSdkVersion);

  // When
  device = self.sut.device;

  // Then
  XCTAssertEqual(device.wrapperSdkVersion, wrapperSdk.wrapperSdkVersion);
}

- (void)testCreationOfNewDeviceWorks {

  // When
  MSDevice *expected = [[MSDeviceTracker sharedInstance] updatedDevice];

  // Then

  assertThat(expected.sdkVersion, notNilValue());
  assertThatInteger([expected.sdkVersion length], greaterThan(@(0)));

  assertThat(expected.model, notNilValue());
  assertThatInteger([expected.model length], greaterThan(@(0)));

  assertThat(expected.oemName, is(kMSDeviceManufacturerTest));

  assertThat(expected.osName, notNilValue());
  assertThatInteger([expected.osName length], greaterThan(@(0)));

  assertThat(expected.osVersion, notNilValue());
  assertThatInteger([expected.osVersion length], greaterThan(@(0)));
  assertThatFloat([expected.osVersion floatValue], greaterThan(@(0.0)));

  assertThat(expected.locale, notNilValue());
  assertThatInteger([expected.locale length], greaterThan(@(0)));

  assertThat(expected.timeZoneOffset, notNilValue());

  assertThat(expected.screenSize, notNilValue());

  // Can't access carrier name and country in test context but it's optional and in that case it has to be nil.
  assertThat(expected.carrierCountry, nilValue());
  assertThat(expected.carrierName, nilValue());

  // Can't access a valid main bundle from test context so we can't test for App namespace (bundle ID), version and
  // build.

  XCTAssertNotEqual(expected, self.sut.device);
}

//FIXME: build falls each time because of this test. 
- (void)clearingDeviceHistoryWorks {

  MSMockUserDefaults *defaults = [MSMockUserDefaults new];

  // When
  [self.sut clearDevices];

  // Then
  XCTAssertTrue([self.sut.deviceHistory count] == 0);
  XCTAssertNil([defaults objectForKey:kMSPastDevicesKey]);

  // When
  [self.sut device];
  XCTAssertNotNil([defaults objectForKey:kMSPastDevicesKey]);
}

- (void)testEnqueuingAndRefreshWorks {

  // If
  MSDeviceTracker *tracker = [[MSDeviceTracker alloc] init];
  [tracker clearDevices];

  // When
  MSDevice *first = [tracker device];
  [MSDeviceTracker refreshDeviceNextTime];
  MSDevice *second = [tracker device];
  [MSDeviceTracker refreshDeviceNextTime];
  MSDevice *third = [tracker device];

  // Then
  XCTAssertTrue([[tracker deviceHistory] count] == 3);
  XCTAssertTrue([tracker.deviceHistory[0].device isEqual:first]);
  XCTAssertTrue([tracker.deviceHistory[1].device isEqual:second]);
  XCTAssertTrue([tracker.deviceHistory[2].device isEqual:third]);

  // When
  // We haven't called setNeedsRefresh: so device won't be refreshed.
  MSDevice *fourth = [tracker device];

  // Then
  XCTAssertTrue([[tracker deviceHistory] count] == 3);
  XCTAssertTrue([fourth isEqual:third]);

  // When
  [MSDeviceTracker refreshDeviceNextTime];
  fourth = [tracker device];

  // Then
  XCTAssertTrue([[tracker deviceHistory] count] == 4);
  XCTAssertTrue([tracker.deviceHistory[3].device isEqual:fourth]);

  // When
  [MSDeviceTracker refreshDeviceNextTime];
  MSDevice *fifth = [tracker device];

  // Then
  XCTAssertTrue([[tracker deviceHistory] count] == 5);
  XCTAssertTrue([tracker.deviceHistory[4].device isEqual:fifth]);

  // When
  [MSDeviceTracker refreshDeviceNextTime];
  MSDevice *sixth = [tracker device];

  // Then
  // The new device should be added at the end and the first one removed so that second is at index 0
  XCTAssertTrue([[tracker deviceHistory] count] == 5);
  XCTAssertTrue([tracker.deviceHistory[0].device isEqual:second]);
  XCTAssertTrue([tracker.deviceHistory[4].device isEqual:sixth]);

  // When
  [MSDeviceTracker refreshDeviceNextTime];
  MSDevice *seventh = [tracker device];

  // Then
  // The new device should be added at the end and the first one removed so that third is at index 0
  XCTAssertTrue([[tracker deviceHistory] count] == 5);
  XCTAssertTrue([tracker.deviceHistory[0].device isEqual:third]);
  XCTAssertTrue([tracker.deviceHistory[4].device isEqual:seventh]);
}

- (void)testHistoryReturnsClosestDevice {

  // If
  MSDeviceTracker *tracker = [MSDeviceTracker sharedInstance];
  [tracker clearDevices];

  // When
  MSDevice *actual = [tracker deviceForTimestamp:[NSDate dateWithTimeIntervalSince1970:1]];

  // Then
  XCTAssertTrue([actual isEqual:tracker.device]);
  XCTAssertTrue([[tracker deviceHistory] count] == 1);

  // If
  MSDevice *first = [tracker device];
  [MSDeviceTracker refreshDeviceNextTime];
  [tracker device]; // we don't need the second device history info
  [MSDeviceTracker refreshDeviceNextTime];
  MSDevice *third = [tracker device];

  // When
  actual = [tracker deviceForTimestamp:[NSDate dateWithTimeIntervalSince1970:1]];

  // Then
  XCTAssertTrue([actual isEqual:first]);

  // When
  actual = [tracker deviceForTimestamp:[NSDate date]];

  // Then
  XCTAssertTrue([actual isEqual:third]);
}

@end
