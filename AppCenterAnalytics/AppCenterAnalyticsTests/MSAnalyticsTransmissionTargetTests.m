#import "MSAnalyticsAuthenticationProviderInternal.h"
#import "MSAnalyticsInternal.h"
#import "MSAnalyticsPrivate.h"
#import "MSAnalyticsTransmissionTargetInternal.h"
#import "MSAnalyticsTransmissionTargetPrivate.h"
#import "MSAppCenterInternal.h"
#import "MSAppExtension.h"
#import "MSBooleanTypedProperty.h"
#import "MSCSExtensions.h"
#import "MSChannelUnitDefault.h"
#import "MSDateTimeTypedProperty.h"
#import "MSDoubleTypedProperty.h"
#import "MSEventLog.h"
#import "MSEventPropertiesInternal.h"
#import "MSLongTypedProperty.h"
#import "MSMockUserDefaults.h"
#import "MSPropertyConfiguratorInternal.h"
#import "MSPropertyConfiguratorPrivate.h"
#import "MSStringTypedProperty.h"
#import "MSTestFrameworks.h"
#import <OCMock/OCMock.h>

static NSString *const kMSTestTransmissionToken = @"TestTransmissionToken";
static NSString *const kMSTestTransmissionToken2 = @"TestTransmissionToken2";

@interface MSAnalyticsTransmissionTargetTests : XCTestCase

@property(nonatomic) MSMockUserDefaults *settingsMock;
@property(nonatomic) id analyticsClassMock;
@property(nonatomic) id<MSChannelGroupProtocol> channelGroupMock;

@end

@implementation MSAnalyticsTransmissionTargetTests

- (void)setUp {
  [super setUp];

  // Mock NSUserDefaults
  self.settingsMock = [MSMockUserDefaults new];

  // Analytics enabled state can prevent targets from tracking events.
  id analyticsClassMock = OCMClassMock([MSAnalytics class]);
  self.analyticsClassMock = OCMPartialMock([MSAnalytics sharedInstance]);
  OCMStub([analyticsClassMock sharedInstance]).andReturn(self.analyticsClassMock);
  self.channelGroupMock = OCMProtocolMock(@protocol(MSChannelGroupProtocol));
  [MSAppCenter sharedInstance].sdkConfigured = YES;
  [[MSAnalytics sharedInstance] startWithChannelGroup:self.channelGroupMock
                                            appSecret:@"appsecret"
                              transmissionTargetToken:@"token"
                                      fromApplication:YES];
}

- (void)tearDown {
  [self.settingsMock stopMocking];
  [self.analyticsClassMock stopMocking];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  MSAnalyticsTransmissionTarget.authenticationProvider = nil;
#pragma clang diagnostic pop
  [super tearDown];
}

#pragma mark - Tests

- (void)testInitialization {

  // When
  MSAnalyticsTransmissionTarget *sut = [[MSAnalyticsTransmissionTarget alloc] initWithTransmissionTargetToken:kMSTestTransmissionToken
                                                                                                 parentTarget:nil
                                                                                                 channelGroup:self.channelGroupMock];

  // Then
  XCTAssertNotNil(sut);
  XCTAssertEqual(kMSTestTransmissionToken, sut.transmissionTargetToken);
  XCTAssertTrue([sut.propertyConfigurator.eventProperties isEmpty]);
  XCTAssertNil(MSAnalyticsTransmissionTarget.authenticationProvider);
}

- (void)testTrackEvent {

  // If
  MSAnalyticsTransmissionTarget *sut = [[MSAnalyticsTransmissionTarget alloc] initWithTransmissionTargetToken:kMSTestTransmissionToken
                                                                                                 parentTarget:nil
                                                                                                 channelGroup:self.channelGroupMock];
  NSString *eventName = @"event";

  // When
  [sut trackEvent:eventName];

  // Then
  XCTAssertTrue(sut.propertyConfigurator.eventProperties.properties.count == 0);
  OCMVerify(ClassMethod([self.analyticsClassMock trackEvent:eventName withTypedProperties:nil forTransmissionTarget:sut]));
}

- (void)testTrackEventWithProperties {

  // If
  MSAnalyticsTransmissionTarget *sut = [[MSAnalyticsTransmissionTarget alloc] initWithTransmissionTargetToken:kMSTestTransmissionToken
                                                                                                 parentTarget:nil
                                                                                                 channelGroup:self.channelGroupMock];
  NSString *eventName = @"event";
  NSDictionary *properties = @{@"prop1" : @"val1", @"prop2" : @"val2"};
  MSEventProperties *expectedProperties = [MSEventProperties new];
  for (NSString *key in properties.allKeys) {
    [expectedProperties setString:properties[key] forKey:key];
  }

  // When
  [sut trackEvent:eventName withProperties:properties];

  // Then
  XCTAssertTrue(sut.propertyConfigurator.eventProperties.properties.count == 0);
  OCMVerify(ClassMethod([self.analyticsClassMock trackEvent:eventName withTypedProperties:expectedProperties forTransmissionTarget:sut]));
}

- (void)testTrackEventWithNilDictionaryProperties {

  // If
  MSAnalyticsTransmissionTarget *sut = [[MSAnalyticsTransmissionTarget alloc] initWithTransmissionTargetToken:kMSTestTransmissionToken
                                                                                                 parentTarget:nil
                                                                                                 channelGroup:self.channelGroupMock];
  NSString *eventName = @"event";
  OCMStub([self.analyticsClassMock canBeUsed]).andReturn(YES);

  // When
  [sut trackEvent:eventName withProperties:nil];

  // Then
  XCTAssertTrue(sut.propertyConfigurator.eventProperties.properties.count == 0);
  OCMVerify(ClassMethod([self.analyticsClassMock trackEvent:eventName withTypedProperties:nil forTransmissionTarget:sut]));
}

- (void)testTrackEventWithNilEventProperties {

  // If
  MSAnalyticsTransmissionTarget *sut = [[MSAnalyticsTransmissionTarget alloc] initWithTransmissionTargetToken:kMSTestTransmissionToken
                                                                                                 parentTarget:nil
                                                                                                 channelGroup:self.channelGroupMock];
  NSString *eventName = @"event";
  OCMStub([self.analyticsClassMock canBeUsed]).andReturn(YES);

  // When
  [sut trackEvent:eventName withTypedProperties:nil];

  // Then
  XCTAssertTrue(sut.propertyConfigurator.eventProperties.properties.count == 0);
  OCMVerify(ClassMethod([self.analyticsClassMock trackEvent:eventName withTypedProperties:nil forTransmissionTarget:sut]));
}

- (void)testTransmissionTargetForToken {

  // If
  NSDictionary *properties = [NSDictionary new];
  MSEventProperties *emptyProperties = [MSEventProperties new];
  NSString *event1 = @"event1";
  NSString *event2 = @"event2";
  NSString *event3 = @"event3";

  MSAnalyticsTransmissionTarget *parentTransmissionTarget =
      [[MSAnalyticsTransmissionTarget alloc] initWithTransmissionTargetToken:kMSTestTransmissionToken
                                                                parentTarget:nil
                                                                channelGroup:self.channelGroupMock];
  MSAnalyticsTransmissionTarget *childTransmissionTarget;

  // When
  childTransmissionTarget = [parentTransmissionTarget transmissionTargetForToken:kMSTestTransmissionToken2];
  [childTransmissionTarget trackEvent:event1 withProperties:properties];

  // Then
  XCTAssertEqualObjects(kMSTestTransmissionToken2, childTransmissionTarget.transmissionTargetToken);
  XCTAssertEqualObjects(childTransmissionTarget, parentTransmissionTarget.childTransmissionTargets[kMSTestTransmissionToken2]);

  // When
  MSAnalyticsTransmissionTarget *childTransmissionTarget2 = [parentTransmissionTarget transmissionTargetForToken:kMSTestTransmissionToken2];
  [childTransmissionTarget2 trackEvent:event2 withProperties:properties];

  // Then
  XCTAssertEqualObjects(childTransmissionTarget, childTransmissionTarget2);
  XCTAssertEqualObjects(childTransmissionTarget2, parentTransmissionTarget.childTransmissionTargets[kMSTestTransmissionToken2]);

  // When
  MSAnalyticsTransmissionTarget *childTransmissionTarget3 = [parentTransmissionTarget transmissionTargetForToken:kMSTestTransmissionToken];
  [childTransmissionTarget3 trackEvent:event3 withProperties:properties];

  // Then
  XCTAssertNotEqualObjects(parentTransmissionTarget, childTransmissionTarget3);
  XCTAssertEqualObjects(childTransmissionTarget3, parentTransmissionTarget.childTransmissionTargets[kMSTestTransmissionToken]);
  OCMVerify(ClassMethod([self.analyticsClassMock trackEvent:event1
                                        withTypedProperties:emptyProperties
                                      forTransmissionTarget:childTransmissionTarget]));
  OCMVerify(ClassMethod([self.analyticsClassMock trackEvent:event2
                                        withTypedProperties:emptyProperties
                                      forTransmissionTarget:childTransmissionTarget2]));
  OCMVerify(ClassMethod([self.analyticsClassMock trackEvent:event3
                                        withTypedProperties:emptyProperties
                                      forTransmissionTarget:childTransmissionTarget3]));
}

- (void)testTransmissionTargetEnabledState {

  // If
  NSDictionary *properties = @{@"prop1" : @"val1", @"prop2" : @"val2"};
  MSEventProperties *expectedProperties = [MSEventProperties new];
  for (NSString *key in properties.allKeys) {
    [expectedProperties setString:properties[key] forKey:key];
  }
  NSString *event1 = @"event1";
  NSString *event2 = @"event2";
  NSString *event3 = @"event3";
  NSString *event4 = @"event4";
  MSAnalyticsTransmissionTarget *transmissionTarget, *transmissionTarget2;
  OCMStub([self.analyticsClassMock canBeUsed]).andReturn(YES);

  // Events tracked when disabled mustn't be sent.
  OCMReject(ClassMethod([self.analyticsClassMock trackEvent:event2 withProperties:properties forTransmissionTarget:transmissionTarget]));
  OCMReject(ClassMethod([self.analyticsClassMock trackEvent:event3 withProperties:properties forTransmissionTarget:transmissionTarget2]));

  // When

  // Target enabled by default.
  transmissionTarget = [[MSAnalyticsTransmissionTarget alloc] initWithTransmissionTargetToken:kMSTestTransmissionToken
                                                                                 parentTarget:nil
                                                                                 channelGroup:self.channelGroupMock];
  [transmissionTarget setEnabled:YES];

  // Then
  XCTAssertTrue([transmissionTarget isEnabled]);
  [transmissionTarget trackEvent:event1 withProperties:properties];

  // When

  // Disabling, track event won't work.
  [transmissionTarget setEnabled:NO];
  [transmissionTarget trackEvent:event2 withProperties:properties];

  // Then
  XCTAssertFalse([transmissionTarget isEnabled]);

  // When

  // Allocating a new object with the same token should return the enabled state
  // for this token.
  transmissionTarget2 = [[MSAnalyticsTransmissionTarget alloc] initWithTransmissionTargetToken:kMSTestTransmissionToken
                                                                                  parentTarget:nil
                                                                                  channelGroup:self.channelGroupMock];
  [transmissionTarget2 trackEvent:event3 withProperties:properties];

  // Then
  XCTAssertFalse([transmissionTarget2 isEnabled]);

  // When

  // Re-enabling
  [transmissionTarget2 setEnabled:YES];
  [transmissionTarget2 trackEvent:event4 withProperties:properties];

  // Then
  XCTAssertTrue([transmissionTarget2 isEnabled]);
  OCMVerify(ClassMethod([self.analyticsClassMock trackEvent:event1
                                        withTypedProperties:expectedProperties
                                      forTransmissionTarget:transmissionTarget]));
  OCMVerify(ClassMethod([self.analyticsClassMock trackEvent:event4
                                        withTypedProperties:expectedProperties
                                      forTransmissionTarget:transmissionTarget2]));
}

- (void)testTransmissionTargetNestedEnabledState {

  // If
  MSAnalyticsTransmissionTarget *target = [[MSAnalyticsTransmissionTarget alloc] initWithTransmissionTargetToken:kMSTestTransmissionToken
                                                                                                    parentTarget:nil
                                                                                                    channelGroup:self.channelGroupMock];

  // When

  // Create a child while parent is enabled, child also enabled.
  MSAnalyticsTransmissionTarget *childTarget = [target transmissionTargetForToken:@"childTarget1-guid"];

  // Then
  XCTAssertTrue([childTarget isEnabled]);

  // If
  MSAnalyticsTransmissionTarget *subChildTarget = [childTarget transmissionTargetForToken:@"subChildTarget1-guid"];

  // When

  // Disabling the parent disables its children.
  [target setEnabled:NO];

  // Then
  XCTAssertFalse([target isEnabled]);
  XCTAssertFalse([childTarget isEnabled]);
  XCTAssertFalse([subChildTarget isEnabled]);

  // When

  // Enabling a child while parent is disabled won't work.
  [childTarget setEnabled:YES];

  // Then
  XCTAssertFalse([target isEnabled]);
  XCTAssertFalse([childTarget isEnabled]);
  XCTAssertFalse([subChildTarget isEnabled]);

  // When

  // Adding another child, it's state should reflect its parent.
  MSAnalyticsTransmissionTarget *childTarget2 = [target transmissionTargetForToken:@"childTarget2-guid"];

  // Then
  XCTAssertFalse([target isEnabled]);
  XCTAssertFalse([childTarget isEnabled]);
  XCTAssertFalse([subChildTarget isEnabled]);
  XCTAssertFalse([childTarget2 isEnabled]);

  // When

  // Enabling a parent enables its children.
  [target setEnabled:YES];

  // Then
  XCTAssertTrue([target isEnabled]);
  XCTAssertTrue([childTarget isEnabled]);
  XCTAssertTrue([subChildTarget isEnabled]);
  XCTAssertTrue([childTarget2 isEnabled]);

  // When

  // Disabling a child only disables its children.
  [childTarget setEnabled:NO];

  // Then
  XCTAssertTrue([target isEnabled]);
  XCTAssertFalse([childTarget isEnabled]);
  XCTAssertFalse([subChildTarget isEnabled]);
  XCTAssertTrue([childTarget2 isEnabled]);
}

- (void)testLongListOfImmediateChildren {

  // If
  short maxChildren = 50;
  NSMutableArray<MSAnalyticsTransmissionTarget *> *childrenTargets;
  MSAnalyticsTransmissionTarget *parentTarget =
      [[MSAnalyticsTransmissionTarget alloc] initWithTransmissionTargetToken:kMSTestTransmissionToken
                                                                parentTarget:nil
                                                                channelGroup:self.channelGroupMock];
  for (short i = 1; i <= maxChildren; i++) {
    [childrenTargets addObject:[parentTarget transmissionTargetForToken:[NSString stringWithFormat:@"Child%d-guid", i]]];
  }

  // When
  [self measureBlock:^{
    [parentTarget setEnabled:NO];
  }];

  // Then
  XCTAssertFalse(parentTarget.isEnabled);
  for (MSAnalyticsTransmissionTarget *child in childrenTargets) {
    XCTAssertFalse(child.isEnabled);
  }
}

- (void)testLongListOfSubChildren {

  // If
  short maxSubChildren = 50;
  NSMutableArray<MSAnalyticsTransmissionTarget *> *childrenTargets;
  MSAnalyticsTransmissionTarget *parentTarget =
      [[MSAnalyticsTransmissionTarget alloc] initWithTransmissionTargetToken:kMSTestTransmissionToken
                                                                parentTarget:nil
                                                                channelGroup:self.channelGroupMock];
  MSAnalyticsTransmissionTarget *currentChildren = [parentTarget transmissionTargetForToken:@"Child1-guid"];
  [childrenTargets addObject:currentChildren];
  for (short i = 2; i <= maxSubChildren; i++) {
    currentChildren = [currentChildren transmissionTargetForToken:[NSString stringWithFormat:@"SubChild%d-guid", i]];
    [childrenTargets addObject:currentChildren];
  }

  // When
  [self measureBlock:^{
    [parentTarget setEnabled:NO];
  }];

  // Then
  XCTAssertFalse(parentTarget.isEnabled);
  for (MSAnalyticsTransmissionTarget *child in childrenTargets) {
    XCTAssertFalse(child.isEnabled);
  }
}

- (void)testMergingEventPropertiesWithCommonPropertiesOnly {

  // If

  // Common properties only.
  MSAnalyticsTransmissionTarget *target = [[MSAnalyticsTransmissionTarget alloc] initWithTransmissionTargetToken:kMSTestTransmissionToken
                                                                                                    parentTarget:nil
                                                                                                    channelGroup:self.channelGroupMock];
  NSString *eventName = @"event";
  NSString *propCommonKey = @"propCommonKey";
  NSString *propCommonValue = @"propCommonValue";
  NSString *propCommonDoubleKey = @"propCommonDoubleKey";
  double propCommonDoubleValue = 298374;
  NSString *propCommonKey2 = @"sharedPropKey";
  NSDate *propCommonValue2 = [NSDate date];

  [target.propertyConfigurator setEventPropertyString:propCommonValue forKey:propCommonKey];
  [target.propertyConfigurator setEventPropertyDouble:propCommonDoubleValue forKey:propCommonDoubleKey];
  [target.propertyConfigurator setEventPropertyDate:propCommonValue2 forKey:propCommonKey2];
  MSEventProperties *expectedProperties = [MSEventProperties new];
  [expectedProperties setString:propCommonValue forKey:propCommonKey];
  [expectedProperties setDate:propCommonValue2 forKey:propCommonKey2];
  [expectedProperties setDouble:propCommonDoubleValue forKey:propCommonDoubleKey];

  // When
  [target trackEvent:eventName];

  // Then
  OCMVerify(ClassMethod([self.analyticsClassMock trackEvent:eventName
                                        withTypedProperties:expectedProperties
                                      forTransmissionTarget:target]));
}

- (void)testMergingEventPropertiesWithCommonAndTrackEventProperties {

  // If
  MSAnalyticsTransmissionTarget *target = [[MSAnalyticsTransmissionTarget alloc] initWithTransmissionTargetToken:kMSTestTransmissionToken
                                                                                                    parentTarget:nil
                                                                                                    channelGroup:self.channelGroupMock];

  // Common properties.
  NSString *eventName = @"event";
  NSString *propCommonKey = @"propCommonKey";
  NSString *propCommonValue = @"propCommonValue";
  NSString *propCommonDoubleKey = @"propCommonDoubleKey";
  double propCommonDoubleValue = 298374;
  NSString *propCommonKey2 = @"sharedPropKey";
  NSDate *propCommonValue2 = [NSDate date];
  [target.propertyConfigurator setEventPropertyString:propCommonValue forKey:propCommonKey];
  [target.propertyConfigurator setEventPropertyDouble:propCommonDoubleValue forKey:propCommonDoubleKey];
  [target.propertyConfigurator setEventPropertyDate:propCommonValue2 forKey:propCommonKey2];

  // Track event properties.
  NSString *propTrackKey = @"propTrackKey";
  NSString *propTrackValue = @"propTrackValue";
  NSString *propTrackKey2 = @"sharedPropKey";
  NSString *propTrackValue2 = @"propTrackValue2";
  MSEventProperties *expectedProperties = [MSEventProperties new];
  [expectedProperties setString:propCommonValue forKey:propCommonKey];
  [expectedProperties setDate:propCommonValue2 forKey:propCommonKey2];
  [expectedProperties setDouble:propCommonDoubleValue forKey:propCommonDoubleKey];
  [expectedProperties setString:propTrackValue forKey:propTrackKey];
  [expectedProperties setString:propTrackValue2 forKey:propTrackKey2];

  // When
  [target trackEvent:eventName withProperties:@{propTrackKey : propTrackValue, propTrackKey2 : propTrackValue2}];

  // Then
  OCMVerify(ClassMethod([self.analyticsClassMock trackEvent:eventName
                                        withTypedProperties:expectedProperties
                                      forTransmissionTarget:target]));
}

- (void)testMergingEventPropertiesWithCommonAndTrackEventTypedProperties {

  // If
  MSAnalyticsTransmissionTarget *target = [[MSAnalyticsTransmissionTarget alloc] initWithTransmissionTargetToken:kMSTestTransmissionToken
                                                                                                    parentTarget:nil
                                                                                                    channelGroup:self.channelGroupMock];

  // Common properties.
  NSString *eventName = @"event";
  NSString *propCommonKey = @"propCommonKey";
  NSString *propCommonValue = @"propCommonValue";
  NSString *propCommonDoubleKey = @"propCommonDoubleKey";
  double propCommonDoubleValue = 298374;
  NSString *propCommonKey2 = @"sharedPropKey";
  NSDate *propCommonValue2 = [NSDate date];
  [target.propertyConfigurator setEventPropertyString:propCommonValue forKey:propCommonKey];
  [target.propertyConfigurator setEventPropertyDouble:propCommonDoubleValue forKey:propCommonDoubleKey];
  [target.propertyConfigurator setEventPropertyDate:propCommonValue2 forKey:propCommonKey2];

  // Track event properties.
  NSString *propTrackKey = @"propTrackKey";
  NSString *propTrackValue = @"propTrackValue";
  NSString *propTrackKey2 = @"sharedPropKey";
  BOOL propTrackValue2 = YES;
  MSEventProperties *expectedProperties = [MSEventProperties new];
  [expectedProperties setString:propCommonValue forKey:propCommonKey];
  [expectedProperties setDate:propCommonValue2 forKey:propCommonKey2];
  [expectedProperties setDouble:propCommonDoubleValue forKey:propCommonDoubleKey];
  [expectedProperties setString:propTrackValue forKey:propTrackKey];
  [expectedProperties setBool:propTrackValue2 forKey:propTrackKey2];
  MSEventProperties *trackEventProperties = [MSEventProperties new];
  [trackEventProperties setString:propTrackValue forKey:propTrackKey];
  [trackEventProperties setBool:propTrackValue2 forKey:propTrackKey2];

  // When
  [target trackEvent:eventName withTypedProperties:trackEventProperties];

  // Then
  OCMVerify(ClassMethod([self.analyticsClassMock trackEvent:eventName
                                        withTypedProperties:expectedProperties
                                      forTransmissionTarget:target]));
}

- (void)testEventPropertiesCascading {

  // If
  [MSAnalytics resetSharedInstance];
  id<MSChannelUnitProtocol> channelUnitMock = OCMProtocolMock(@protocol(MSChannelUnitProtocol));
  OCMStub([self.channelGroupMock addChannelUnitWithConfiguration:OCMOCK_ANY]).andReturn(channelUnitMock);
  [MSAppCenter sharedInstance].sdkConfigured = YES;
  [[MSAnalytics sharedInstance] startWithChannelGroup:self.channelGroupMock
                                            appSecret:@"appsecret"
                              transmissionTargetToken:@"token"
                                      fromApplication:YES];

  // Prepare target instances.
  MSAnalyticsTransmissionTarget *grandParent = [MSAnalytics transmissionTargetForToken:@"grand-parent"];
  MSAnalyticsTransmissionTarget *parent = [grandParent transmissionTargetForToken:@"parent"];
  MSAnalyticsTransmissionTarget *child = [parent transmissionTargetForToken:@"child"];

  // Set properties to grand parent.
  [grandParent.propertyConfigurator setEventPropertyString:@"1" forKey:@"a"];
  [grandParent.propertyConfigurator setEventPropertyString:@"2" forKey:@"b"];
  [grandParent.propertyConfigurator setEventPropertyString:@"3" forKey:@"c"];

  // Override some properties.
  [parent.propertyConfigurator setEventPropertyString:@"11" forKey:@"a"];
  [parent.propertyConfigurator setEventPropertyString:@"22" forKey:@"b"];

  // Set a new property in parent.
  [parent.propertyConfigurator setEventPropertyString:@"44" forKey:@"d"];

  // Just to show we still get value from parent which is inherited from grand parent, if we remove an override.
  [parent.propertyConfigurator setEventPropertyString:@"33" forKey:@"c"];
  [parent.propertyConfigurator removeEventPropertyForKey:@"c"];

  // Override a property.
  [child.propertyConfigurator setEventPropertyString:@"444" forKey:@"d"];

  // Set new properties in child.
  [child.propertyConfigurator setEventPropertyString:@"555" forKey:@"e"];
  [child.propertyConfigurator setEventPropertyString:@"666" forKey:@"f"];

  // Track event in child. Override some properties in trackEvent.
  NSMutableDictionary<NSString *, NSString *> *properties = [NSMutableDictionary new];
  [properties setValue:@"6666" forKey:@"f"];
  [properties setValue:@"7777" forKey:@"g"];

  // Mock channel group.
  __block MSEventLog *eventLog;
  OCMStub([channelUnitMock enqueueItem:OCMOCK_ANY critical:NO]).andDo(^(NSInvocation *invocation) {
    id<MSLog> log = nil;
    [invocation getArgument:&log atIndex:2];
    eventLog = (MSEventLog *)log;
  });

  // When
  [child trackEvent:@"eventName" withProperties:properties];

  // Then
  XCTAssertNotNil(eventLog);
  XCTAssertEqual([eventLog.typedProperties.properties count], 7);
  XCTAssertEqualObjects(((MSStringTypedProperty *)eventLog.typedProperties.properties[@"a"]).value, @"11");
  XCTAssertEqualObjects(((MSStringTypedProperty *)eventLog.typedProperties.properties[@"b"]).value, @"22");
  XCTAssertEqualObjects(((MSStringTypedProperty *)eventLog.typedProperties.properties[@"c"]).value, @"3");
  XCTAssertEqualObjects(((MSStringTypedProperty *)eventLog.typedProperties.properties[@"d"]).value, @"444");
  XCTAssertEqualObjects(((MSStringTypedProperty *)eventLog.typedProperties.properties[@"e"]).value, @"555");
  XCTAssertEqualObjects(((MSStringTypedProperty *)eventLog.typedProperties.properties[@"f"]).value, @"6666");
  XCTAssertEqualObjects(((MSStringTypedProperty *)eventLog.typedProperties.properties[@"g"]).value, @"7777");
}

- (void)testEventPropertiesCascadingWithTypes {

  // If
  [MSAnalytics resetSharedInstance];
  id<MSChannelUnitProtocol> channelUnitMock = OCMProtocolMock(@protocol(MSChannelUnitProtocol));
  OCMStub([self.channelGroupMock addChannelUnitWithConfiguration:OCMOCK_ANY]).andReturn(channelUnitMock);
  [MSAppCenter sharedInstance].sdkConfigured = YES;
  [[MSAnalytics sharedInstance] startWithChannelGroup:self.channelGroupMock
                                            appSecret:@"appsecret"
                              transmissionTargetToken:@"token"
                                      fromApplication:YES];

  // Prepare target instances.
  MSAnalyticsTransmissionTarget *grandParent = [MSAnalytics transmissionTargetForToken:@"grand-parent"];
  MSAnalyticsTransmissionTarget *parent = [grandParent transmissionTargetForToken:@"parent"];
  MSAnalyticsTransmissionTarget *child = [parent transmissionTargetForToken:@"child"];

  // Set properties to grand parent.
  [grandParent.propertyConfigurator setEventPropertyString:@"1" forKey:@"a"];
  [grandParent.propertyConfigurator setEventPropertyDouble:2.0 forKey:@"b"];
  [grandParent.propertyConfigurator setEventPropertyString:@"3" forKey:@"c"];

  // Override some properties.
  [parent.propertyConfigurator setEventPropertyInt64:11 forKey:@"a"];
  [parent.propertyConfigurator setEventPropertyString:@"22" forKey:@"b"];

  // Set a new property in parent.
  [parent.propertyConfigurator setEventPropertyInt64:44 forKey:@"d"];

  // Just to show we still get value from parent which is inherited from grand parent, if we remove an override.
  [parent.propertyConfigurator setEventPropertyString:@"33" forKey:@"c"];
  [parent.propertyConfigurator removeEventPropertyForKey:@"c"];

  // Override a property.
  [child.propertyConfigurator setEventPropertyBool:YES forKey:@"d"];

  // Set new properties in child.
  [child.propertyConfigurator setEventPropertyDouble:55.5 forKey:@"e"];
  [child.propertyConfigurator setEventPropertyString:@"666" forKey:@"f"];

  // Track event in child. Override some properties in trackEvent.
  MSEventProperties *properties = [MSEventProperties new];
  [properties setDate:[NSDate dateWithTimeIntervalSince1970:6666] forKey:@"f"];
  [properties setString:@"7777" forKey:@"g"];

  // Mock channel group.
  __block MSEventLog *eventLog;
  OCMStub([channelUnitMock enqueueItem:OCMOCK_ANY critical:NO]).andDo(^(NSInvocation *invocation) {
    id<MSLog> log = nil;
    [invocation getArgument:&log atIndex:2];
    eventLog = (MSEventLog *)log;
  });

  // When
  [child trackEvent:@"eventName" withTypedProperties:properties];

  // Then
  XCTAssertNotNil(eventLog);
  XCTAssertEqual([eventLog.typedProperties.properties count], 7);
  XCTAssertEqual(((MSLongTypedProperty *)eventLog.typedProperties.properties[@"a"]).value, 11);
  XCTAssertEqualObjects(((MSStringTypedProperty *)eventLog.typedProperties.properties[@"b"]).value, @"22");
  XCTAssertEqualObjects(((MSStringTypedProperty *)eventLog.typedProperties.properties[@"c"]).value, @"3");
  XCTAssertEqual(((MSBooleanTypedProperty *)eventLog.typedProperties.properties[@"d"]).value, YES);
  XCTAssertEqual(((MSDoubleTypedProperty *)eventLog.typedProperties.properties[@"e"]).value, 55.5);
  XCTAssertEqualObjects(((MSDateTimeTypedProperty *)eventLog.typedProperties.properties[@"f"]).value,
                        [NSDate dateWithTimeIntervalSince1970:6666]);
  XCTAssertEqualObjects(((MSStringTypedProperty *)eventLog.typedProperties.properties[@"g"]).value, @"7777");
}

- (void)testAppExtensionCommonSchemaPropertiesWithoutOverriding {

  // If

  // Prepare target instance.
  MSAnalyticsTransmissionTarget *target = [MSAnalytics transmissionTargetForToken:@"target"];

  // Set a log.
  MSCommonSchemaLog *log = [MSCommonSchemaLog new];
  log.ext = [MSCSExtensions new];
  log.ext.appExt = [MSAppExtension new];
  log.ext.appExt.ver = @"0.0.1";
  log.ext.appExt.name = @"baseAppName";
  log.ext.appExt.locale = @"en-us";

  // When
  [target.propertyConfigurator channel:nil prepareLog:log];

  // Then
  XCTAssertNil(target.propertyConfigurator.appVersion);
  XCTAssertNil(target.propertyConfigurator.appName);
  XCTAssertNil(target.propertyConfigurator.appLocale);
  XCTAssertEqual(log.ext.appExt.ver, @"0.0.1");
  XCTAssertEqual(log.ext.appExt.name, @"baseAppName");
  XCTAssertEqual(log.ext.appExt.locale, @"en-us");
}

- (void)testOverridingDefaultCommonSchemaProperties {

  // If

  // Prepare target instances.
  MSAnalyticsTransmissionTarget *parent = [MSAnalytics transmissionTargetForToken:@"parent"];
  MSAnalyticsTransmissionTarget *child = [parent transmissionTargetForToken:@"child"];

  // Set properties to grand parent.
  [parent.propertyConfigurator setAppVersion:@"8.4.1"];
  [parent.propertyConfigurator setAppName:@"ParentAppName"];
  [parent.propertyConfigurator setAppLocale:@"en-us"];

  // Set a log with default values.
  MSCommonSchemaLog *log = [MSCommonSchemaLog new];
  log.tag = child;
  log.ext = [MSCSExtensions new];
  log.ext.appExt = [MSAppExtension new];
  [log addTransmissionTargetToken:@"parent"];
  [log addTransmissionTargetToken:@"child"];

  // When
  [child.propertyConfigurator channel:nil prepareLog:log];

  // Then
  XCTAssertEqual(log.ext.appExt.ver, parent.propertyConfigurator.appVersion);
  XCTAssertEqual(log.ext.appExt.name, parent.propertyConfigurator.appName);
  XCTAssertEqual(log.ext.appExt.locale, parent.propertyConfigurator.appLocale);
}

- (void)testOverridingCommonSchemaProperties {

  // If

  // Prepare target instance.
  MSAnalyticsTransmissionTarget *target = [MSAnalytics transmissionTargetForToken:@"target"];

  // Set properties to the target.
  [target.propertyConfigurator setAppVersion:@"8.4.1"];
  [target.propertyConfigurator setAppName:@"NewAppName"];
  [target.propertyConfigurator setAppLocale:@"en-us"];

  // Set a log.
  MSCommonSchemaLog *log = [MSCommonSchemaLog new];
  log.tag = target;
  [log addTransmissionTargetToken:@"target"];
  log.ext = [MSCSExtensions new];
  log.ext.appExt = [MSAppExtension new];
  log.ext.appExt.ver = @"0.0.1";
  log.ext.appExt.name = @"baseAppName";
  log.ext.appExt.locale = @"zh-cn";

  // When
  [target.propertyConfigurator channel:nil prepareLog:log];

  // Then
  XCTAssertEqual(log.ext.appExt.ver, target.propertyConfigurator.appVersion);
  XCTAssertEqual(log.ext.appExt.name, target.propertyConfigurator.appName);
  XCTAssertEqual(log.ext.appExt.locale, target.propertyConfigurator.appLocale);
}

- (void)testOverridingCommonSchemaPropertiesFromParent {

  // If

  // Prepare target instances.
  MSAnalyticsTransmissionTarget *parent = [MSAnalytics transmissionTargetForToken:@"parent"];
  MSAnalyticsTransmissionTarget *child = [parent transmissionTargetForToken:@"child"];

  // Set properties to grand parent.
  [parent.propertyConfigurator setAppVersion:@"8.4.1"];
  [parent.propertyConfigurator setAppName:@"ParentAppName"];
  [parent.propertyConfigurator setAppLocale:@"en-us"];

  // Set a log.
  MSCommonSchemaLog *log = [MSCommonSchemaLog new];
  log.tag = child;
  log.ext = [MSCSExtensions new];
  log.ext.appExt = [MSAppExtension new];
  log.ext.appExt.ver = @"0.0.1";
  log.ext.appExt.name = @"baseAppName";
  log.ext.appExt.locale = @"zh-cn";
  [log addTransmissionTargetToken:@"parent"];
  [log addTransmissionTargetToken:@"child"];

  // When
  [child.propertyConfigurator channel:nil prepareLog:log];

  // Then
  XCTAssertEqualObjects(log.ext.appExt.ver, parent.propertyConfigurator.appVersion);
  XCTAssertEqualObjects(log.ext.appExt.name, parent.propertyConfigurator.appName);
  XCTAssertEqualObjects(log.ext.appExt.locale, parent.propertyConfigurator.appLocale);
}

- (void)testOverridingCommonSchemaPropertiesDoNothingWhenTargetIsDisabled {

  // If

  // Prepare target instances.
  MSAnalyticsTransmissionTarget *grandParent = [MSAnalytics transmissionTargetForToken:@"grand-parent"];
  MSAnalyticsTransmissionTarget *parent = [grandParent transmissionTargetForToken:@"parent"];
  MSAnalyticsTransmissionTarget *child = [parent transmissionTargetForToken:@"child"];

  // Set properties to grand parent.
  [grandParent.propertyConfigurator setAppVersion:@"8.4.1"];
  [grandParent.propertyConfigurator setAppName:@"GrandParentAppName"];
  [grandParent.propertyConfigurator setAppLocale:@"en-us"];

  // Set common properties to child.
  [child.propertyConfigurator setAppVersion:@"1.4.8"];
  [child.propertyConfigurator setAppName:@"ChildAppName"];
  [child.propertyConfigurator setAppLocale:@"fr-ca"];

  // Set a log.
  MSCommonSchemaLog *log = [MSCommonSchemaLog new];
  log.tag = child;
  log.ext = [MSCSExtensions new];
  log.ext.appExt = [MSAppExtension new];
  log.ext.appExt.ver = @"0.0.1";
  log.ext.appExt.name = @"baseAppName";
  log.ext.appExt.locale = @"zh-cn";
  [log addTransmissionTargetToken:@"parent"];
  [log addTransmissionTargetToken:@"child"];
  [log addTransmissionTargetToken:@"grand-parent"];

  [grandParent setEnabled:NO];

  // When
  [grandParent.propertyConfigurator channel:nil prepareLog:log];

  // Then
  XCTAssertEqual(log.ext.appExt.ver, @"0.0.1");
  XCTAssertEqual(log.ext.appExt.name, @"baseAppName");
  XCTAssertEqual(log.ext.appExt.locale, @"zh-cn");

  // If
  [child setEnabled:NO];

  // When
  [child.propertyConfigurator channel:nil prepareLog:log];

  // Then
  XCTAssertNotEqual(log.ext.appExt.ver, child.propertyConfigurator.appVersion);
  XCTAssertNotEqual(log.ext.appExt.name, child.propertyConfigurator.appName);
  XCTAssertNotEqual(log.ext.appExt.locale, child.propertyConfigurator.appLocale);

  // If

  // Reset a log.
  log = [MSCommonSchemaLog new];
  log.tag = child;
  log.ext = [MSCSExtensions new];
  log.ext.appExt = [MSAppExtension new];
  log.ext.appExt.ver = @"0.0.1";
  log.ext.appExt.name = @"baseAppName";
  log.ext.appExt.locale = @"zh-cn";
  [log addTransmissionTargetToken:@"parent"];
  [log addTransmissionTargetToken:@"child"];
  [log addTransmissionTargetToken:@"grand-parent"];

  // When
  [parent.propertyConfigurator channel:nil prepareLog:log];

  // Then
  XCTAssertEqual(log.ext.appExt.ver, @"0.0.1");
  XCTAssertEqual(log.ext.appExt.name, @"baseAppName");
  XCTAssertEqual(log.ext.appExt.locale, @"zh-cn");
}

- (void)testOverridingCommonSchemaPropertiesWithTwoChildrenUnderTheSameParent {

  // If
  MSAnalyticsTransmissionTarget *parent = [MSAnalytics transmissionTargetForToken:@"parent"];
  MSAnalyticsTransmissionTarget *child1 = [parent transmissionTargetForToken:@"child1"];
  MSAnalyticsTransmissionTarget *child2 = [parent transmissionTargetForToken:@"child2"];

  // Set properties to grand parent.
  [parent.propertyConfigurator setAppVersion:@"8.4.1"];
  [parent.propertyConfigurator setAppName:@"ParentAppName"];
  [parent.propertyConfigurator setAppLocale:@"en-us"];

  // Set common properties to child1.
  [child1.propertyConfigurator setAppVersion:@"1.4.8"];
  [child1.propertyConfigurator setAppName:@"Child1AppName"];
  [child1.propertyConfigurator setAppLocale:@"fr-ca"];

  // Parent log.
  MSCommonSchemaLog *parentLog = [MSCommonSchemaLog new];
  parentLog.tag = parent;
  parentLog.ext = [MSCSExtensions new];
  parentLog.ext.appExt = [MSAppExtension new];
  parentLog.ext.appExt.ver = @"0.0.1";
  parentLog.ext.appExt.name = @"base1AppName";
  parentLog.ext.appExt.locale = @"zh-cn";
  [parentLog addTransmissionTargetToken:@"parent"];

  // Child1 log.
  MSCommonSchemaLog *child1Log = [MSCommonSchemaLog new];
  child1Log.tag = child1;
  child1Log.ext = [MSCSExtensions new];
  child1Log.ext.appExt = [MSAppExtension new];
  child1Log.ext.appExt.ver = @"0.0.1";
  child1Log.ext.appExt.name = @"base1AppName";
  child1Log.ext.appExt.locale = @"zh-cn";
  [child1Log addTransmissionTargetToken:@"child1"];

  // Child2 log.
  MSCommonSchemaLog *child2Log = [MSCommonSchemaLog new];
  child2Log.tag = child2;
  child2Log.ext = [MSCSExtensions new];
  child2Log.ext.appExt = [MSAppExtension new];
  child2Log.ext.appExt.ver = @"0.0.2";
  child2Log.ext.appExt.name = @"base2AppName";
  child2Log.ext.appExt.locale = @"en-us";
  [child2Log addTransmissionTargetToken:@"child2"];

  // When
  [parent.propertyConfigurator channel:nil prepareLog:parentLog];
  [child1.propertyConfigurator channel:nil prepareLog:child1Log];
  [child2.propertyConfigurator channel:nil prepareLog:child2Log];

  // Then
  XCTAssertEqualObjects(parentLog.ext.appExt.ver, parent.propertyConfigurator.appVersion);
  XCTAssertEqualObjects(parentLog.ext.appExt.name, parent.propertyConfigurator.appName);
  XCTAssertEqualObjects(parentLog.ext.appExt.locale, parent.propertyConfigurator.appLocale);
  XCTAssertEqualObjects(child1Log.ext.appExt.ver, child1.propertyConfigurator.appVersion);
  XCTAssertEqualObjects(child1Log.ext.appExt.name, child1.propertyConfigurator.appName);
  XCTAssertEqualObjects(child1Log.ext.appExt.locale, child1.propertyConfigurator.appLocale);
  XCTAssertEqualObjects(child2Log.ext.appExt.ver, parent.propertyConfigurator.appVersion);
  XCTAssertEqualObjects(child2Log.ext.appExt.name, parent.propertyConfigurator.appName);
  XCTAssertEqualObjects(child2Log.ext.appExt.locale, parent.propertyConfigurator.appLocale);
  XCTAssertNil(child2.propertyConfigurator.appVersion);
  XCTAssertNil(child2.propertyConfigurator.appName);
  XCTAssertNil(child2.propertyConfigurator.appLocale);
}

- (void)testAddAuthenticationProvider {

  // If
  MSAnalyticsAuthenticationProvider *provider = [[MSAnalyticsAuthenticationProvider alloc]
      initWithAuthenticationType:MSAnalyticsAuthenticationTypeMsaCompact
                       ticketKey:@"ticketKey"
                        delegate:OCMProtocolMock(@protocol(MSAnalyticsAuthenticationProviderDelegate))];

  // When
  [MSAnalyticsTransmissionTarget addAuthenticationProvider:provider];

  // Then
  XCTAssertNotNil(MSAnalyticsTransmissionTarget.authenticationProvider);
  XCTAssertEqual(provider, MSAnalyticsTransmissionTarget.authenticationProvider);

  // If
  MSAnalyticsAuthenticationProvider *provider2 =
      [[MSAnalyticsAuthenticationProvider alloc] initWithAuthenticationType:MSAnalyticsAuthenticationTypeMsaDelegate
                                                                  ticketKey:@"ticketKey2"
                                                                   delegate:OCMOCK_ANY];

  // When
  dispatch_async(dispatch_get_main_queue(), ^{
    [MSAnalyticsTransmissionTarget addAuthenticationProvider:provider2];
  });
  [MSAnalyticsTransmissionTarget addAuthenticationProvider:provider];
  dispatch_async(dispatch_get_main_queue(), ^{
    [MSAnalyticsTransmissionTarget addAuthenticationProvider:provider2];
  });

  // Then
  XCTAssertEqual(provider, MSAnalyticsTransmissionTarget.authenticationProvider);
}

- (void)testPauseSucceedsWhenTargetIsEnabled {

  // If
  MSAnalyticsTransmissionTarget *sut = [MSAnalytics transmissionTargetForToken:kMSTestTransmissionToken];

  // When
  [sut pause];

  // Then
  OCMVerify([self.analyticsClassMock pauseTransmissionTargetForToken:kMSTestTransmissionToken]);
}

- (void)testResumeSucceedsWhenTargetIsEnabled {

  // If
  MSAnalyticsTransmissionTarget *sut = [MSAnalytics transmissionTargetForToken:kMSTestTransmissionToken];

  // When
  [sut resume];

  // Then
  OCMVerify([self.analyticsClassMock resumeTransmissionTargetForToken:kMSTestTransmissionToken]);
}

- (void)testPauseDoesNotPauseWhenTargetIsDisabled {

  // If
  MSAnalyticsTransmissionTarget *sut = [MSAnalytics transmissionTargetForToken:kMSTestTransmissionToken];
  OCMStub([self.analyticsClassMock canBeUsed]).andReturn(YES);

  // Then
  OCMReject([self.analyticsClassMock pauseTransmissionTargetForToken:kMSTestTransmissionToken]);

  // When
  [MSAnalytics setEnabled:NO];
  [sut pause];
}

- (void)testResumeDoesNotResumeWhenTargetIsDisabled {

  // If
  MSAnalyticsTransmissionTarget *sut = [MSAnalytics transmissionTargetForToken:kMSTestTransmissionToken];
  OCMStub([self.analyticsClassMock canBeUsed]).andReturn(YES);

  // Then
  OCMReject([self.analyticsClassMock resumeTransmissionTargetForToken:kMSTestTransmissionToken]);

  // When
  [sut setEnabled:NO];
  [sut resume];
}

- (void)testPausedAndDisabledTargetIsResumedWhenEnabled {

  // If
  MSAnalyticsTransmissionTarget *sut = [MSAnalytics transmissionTargetForToken:kMSTestTransmissionToken];
  [sut pause];
  [sut setEnabled:NO];

  // When
  [sut setEnabled:YES];

  // Then
  OCMVerify([self.analyticsClassMock resumeTransmissionTargetForToken:kMSTestTransmissionToken]);
}

@end
