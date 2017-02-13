#import <Foundation/Foundation.h>
#import <OCHamcrestIOS/OCHamcrestIOS.h>
#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>

#import "MSReleaseDetails.h"

@interface MSReleaseDetailsTests : XCTestCase

@end

@implementation MSReleaseDetailsTests

#pragma mark - Tests

- (void)testInitializeWithDictionary {
  NSString *filename = [[NSBundle bundleForClass:[self class]] pathForResource:@"release_details" ofType:@"json"];
  MSReleaseDetails *details = [[MSReleaseDetails alloc]
      initWithDictionary:[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:filename]
                                                         options:NSJSONReadingMutableContainers
                                                           error:nil]];

  assertThat(details.id, equalTo(@"1"));
  assertThat(details.status, equalTo(@"available"));
  assertThat(details.appName, equalTo(@"Unittest"));
  assertThat(details.version, equalTo(@"1.0"));
  assertThat(details.shortVersion, equalTo(@"0"));
  assertThat(details.releaseNotes, equalTo(@"This is a release note for test"));
  assertThat(details.provisioningProfileName, equalTo(@"Provisioning profile name"));
  assertThat(details.size, equalTo(@1234567));
  assertThat(details.minOs, equalTo(@"iOS 8.0"));
  assertThat(details.fingerprint, equalTo(@"b10a8db164e0754105b7a99be72e3fe5"));
  assertThat(details.uploadedAt, equalTo([NSDate dateWithTimeIntervalSince1970:(1483257600)]));
  assertThat(details.downloadUrl, equalTo(@"http://contoso.com/path/download/filename"));
  assertThat(details.appIconUrl, equalTo(@"http://contoso.com/path/icon/filename"));
  assertThat(details.installUrl, equalTo(@"itms-service://?action=download-manifest&url=contoso.com/release/filename"));
  assertThat(details.distributionGroups, equalTo(nil));
}

@end
