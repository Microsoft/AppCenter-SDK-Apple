#import <Foundation/Foundation.h>
#import <OCHamcrestIOS/OCHamcrestIOS.h>
#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>

#import "MSAppleErrorLog.h"
#import "MSChannelDefault.h"
#import "MSCrashesDelegate.h"
#import "MSCrashesInternal.h"
#import "MSCrashesPrivate.h"
#import "MSCrashesTestUtil.h"
#import "MSCrashesUtil.h"
#import "MSErrorAttachmentLogInternal.h"
#import "MSErrorLogFormatter.h"
#import "MSException.h"
#import "MSLogManagerDefault.h"
#import "MSMobileCenter.h"
#import "MSMobileCenterInternal.h"
#import "MSMockCrashesDelegate.h"
#import "MSServiceAbstractPrivate.h"
#import "MSServiceAbstractProtected.h"
#import "MSWrapperExceptionManagerInternal.h"

@class MSMockCrashesDelegate;

static NSString *const kMSTestAppSecret = @"TestAppSecret";
static NSString *const kMSCrashesServiceName = @"Crashes";
static NSString *const kMSFatal = @"fatal";
static unsigned int kMaxAttachmentsPerCrashReport = 2;

@interface MSCrashes ()

+ (void)notifyWithUserConfirmation:(MSUserConfirmation)userConfirmation;

- (void)startCrashProcessing;

@end

@interface MSCrashesTests : XCTestCase <MSCrashesDelegate>

@property(nonatomic) MSCrashes *sut;

@end

@implementation MSCrashesTests

#pragma mark - Housekeeping

- (void)setUp {
  [super setUp];
  self.sut = [MSCrashes new];

  // Some tests actually require the shared instance because,
  // so it is important to ensure that it is enabled at the start of each test
  [[MSCrashes sharedInstance] setEnabled:YES];
}

- (void)tearDown {
  [super tearDown];
  [self.sut deleteAllFromCrashesDirectory];
  [MSCrashesTestUtil deleteAllFilesInDirectory:[self.sut.logBufferDir path]];

  // Some tests actually require the shared instance because,
  // so it is important to clean up
  [[MSCrashes sharedInstance] deleteAllFromCrashesDirectory];
  [MSCrashesTestUtil deleteAllFilesInDirectory:[[MSCrashes sharedInstance].logBufferDir path]];
}

#pragma mark - Tests

- (void)testNewInstanceWasInitialisedCorrectly {

  // When
  // An instance of MSCrashes is created.

  // Then
  assertThat(self.sut, notNilValue());
  assertThat(self.sut.fileManager, notNilValue());
  assertThat(self.sut.crashFiles, isEmpty());
  assertThat(self.sut.logBufferDir, notNilValue());
  assertThat(self.sut.crashesDir, notNilValue());
  assertThat(self.sut.analyzerInProgressFile, notNilValue());
  XCTAssertTrue(msCrashesLogBuffer.size() == ms_crashes_log_buffer_size);

  // Creation of buffer files is done asynchronously, we need to give it some time to create the files.
  [NSThread sleepForTimeInterval:0.05];
  NSError *error = [NSError errorWithDomain:@"MSTestingError" code:-57 userInfo:nil];
  NSArray *files = [[NSFileManager defaultManager]
      contentsOfDirectoryAtPath:reinterpret_cast<NSString *_Nonnull>([self.sut.logBufferDir path])
                          error:&error];
  assertThat(files, hasCountOf(ms_crashes_log_buffer_size));
}

- (void)testStartingManagerInitializesPLCrashReporter {

  // When
  [self.sut startWithLogManager:OCMProtocolMock(@protocol(MSLogManager)) appSecret:kMSTestAppSecret];

  // Then
  assertThat(self.sut.plCrashReporter, notNilValue());
}

- (void)testStartingManagerWritesLastCrashReportToCrashesDir {
  assertThatBool([MSCrashesTestUtil copyFixtureCrashReportWithFileName:@"live_report_exception"], isTrue());

  // When
  [self.sut startWithLogManager:OCMProtocolMock(@protocol(MSLogManager)) appSecret:kMSTestAppSecret];

  // Then
  assertThat(self.sut.crashFiles, hasCountOf(1));
}

- (void)testSettingDelegateWorks {

  // When
  id<MSCrashesDelegate> delegateMock = OCMProtocolMock(@protocol(MSCrashesDelegate));
  [MSCrashes setDelegate:delegateMock];

  // Then
  id<MSCrashesDelegate> strongDelegate = [MSCrashes sharedInstance].delegate;
  XCTAssertNotNil(strongDelegate);
  XCTAssertEqual(strongDelegate, delegateMock);
}

- (void)testDelegateMethodsAreCalled {

  // If
  NSString *groupId = [[MSCrashes sharedInstance] groupId];
  id<MSCrashesDelegate> delegateMock = OCMProtocolMock(@protocol(MSCrashesDelegate));
  [MSMobileCenter sharedInstance].sdkConfigured = NO;
  [MSMobileCenter start:kMSTestAppSecret withServices:@[ [MSCrashes class] ]];
  NSMutableDictionary *channelsInLogManager =
      (static_cast<MSLogManagerDefault *>([MSCrashes sharedInstance].logManager)).channels;
  MSChannelDefault *channelMock = channelsInLogManager[groupId] = OCMPartialMock(channelsInLogManager[groupId]);
  OCMStub([channelMock enqueueItem:[OCMArg any] withCompletion:[OCMArg any]]).andDo(^(NSInvocation *invocation) {
    id<MSLog> log = nil;
    [invocation getArgument:&log atIndex:2];
    for (id<MSChannelDelegate> delegate in channelMock.delegates) {

      // Call all channel delegate methods for testing.
      [delegate channel:channelMock willSendLog:log];
      [delegate channel:channelMock didSucceedSendingLog:log];
      [delegate channel:channelMock didFailSendingLog:log withError:nil];
    }
  });
  MSAppleErrorLog *errorLog = OCMClassMock([MSAppleErrorLog class]);
  MSErrorReport *errorReport = OCMClassMock([MSErrorReport class]);
  id errorLogFormatterMock = OCMClassMock([MSErrorLogFormatter class]);
  OCMStub(ClassMethod([errorLogFormatterMock errorReportFromLog:errorLog])).andReturn(errorReport);

  // When
  [[MSCrashes sharedInstance] setDelegate:delegateMock];
  [[MSCrashes sharedInstance].logManager processLog:errorLog forGroupId:groupId];

  // Then
  OCMVerify([delegateMock crashes:[MSCrashes sharedInstance] willSendErrorReport:errorReport]);
  OCMVerify([delegateMock crashes:[MSCrashes sharedInstance] didSucceedSendingErrorReport:errorReport]);
  OCMVerify([delegateMock crashes:[MSCrashes sharedInstance] didFailSendingErrorReport:errorReport withError:nil]);
}

- (void)testSettingUserConfirmationHandler {

  // When
  MSUserConfirmationHandler userConfirmationHandler =
      ^BOOL(__attribute__((unused)) NSArray<MSErrorReport *> *_Nonnull errorReports) {
        return NO;
      };
  [MSCrashes setUserConfirmationHandler:userConfirmationHandler];

  // Then
  XCTAssertNotNil([MSCrashes sharedInstance].userConfirmationHandler);
  XCTAssertEqual([MSCrashes sharedInstance].userConfirmationHandler, userConfirmationHandler);
}

- (void)testCrashesDelegateWithoutImplementations {

  // When
  MSMockCrashesDelegate *delegateMock = OCMPartialMock([MSMockCrashesDelegate new]);
  [MSCrashes setDelegate:delegateMock];

  // Then
  assertThatBool([[MSCrashes sharedInstance] shouldProcessErrorReport:nil], isTrue());
  assertThatBool([[MSCrashes sharedInstance] delegateImplementsAttachmentCallback], isFalse());
}

- (void)testProcessCrashes {

  // When
  assertThatBool([MSCrashesTestUtil copyFixtureCrashReportWithFileName:@"live_report_exception"], isTrue());
  [[MSCrashes sharedInstance] startWithLogManager:OCMProtocolMock(@protocol(MSLogManager)) appSecret:kMSTestAppSecret];

  // Then
  assertThat([MSCrashes sharedInstance].crashFiles, hasCountOf(1));

  // When
  [MS_USER_DEFAULTS setObject:@YES forKey:@"MSUserConfirmation"];
  [[MSCrashes sharedInstance] startCrashProcessing];
  [MS_USER_DEFAULTS removeObjectForKey:@"MSUserConfirmation"];

  // Then
  assertThat([MSCrashes sharedInstance].crashFiles, hasCountOf(0));

  // When
  assertThatBool([MSCrashesTestUtil copyFixtureCrashReportWithFileName:@"live_report_exception"], isTrue());
  [[MSCrashes sharedInstance] startWithLogManager:OCMProtocolMock(@protocol(MSLogManager)) appSecret:kMSTestAppSecret];

  // Then
  assertThat([MSCrashes sharedInstance].crashFiles, hasCountOf(1));

  // When
  MSUserConfirmationHandler userConfirmationHandlerYES =
      ^BOOL(__attribute__((unused)) NSArray<MSErrorReport *> *_Nonnull errorReports) {
        return YES;
      };
  [MSCrashes setUserConfirmationHandler:userConfirmationHandlerYES];
  [[MSCrashes sharedInstance] startCrashProcessing];
  [MSCrashes notifyWithUserConfirmation:MSUserConfirmationDontSend];
  [MSCrashes setUserConfirmationHandler:nil];

  // Then
  assertThat([MSCrashes sharedInstance].crashFiles, hasCountOf(0));

  // When
  assertThatBool([MSCrashesTestUtil copyFixtureCrashReportWithFileName:@"live_report_exception"], isTrue());
  [[MSCrashes sharedInstance] startWithLogManager:OCMProtocolMock(@protocol(MSLogManager)) appSecret:kMSTestAppSecret];

  // Then
  assertThat([MSCrashes sharedInstance].crashFiles, hasCountOf(1));

  // When
  MSUserConfirmationHandler userConfirmationHandlerNO =
      ^BOOL(__attribute__((unused)) NSArray<MSErrorReport *> *_Nonnull errorReports) {
        return NO;
      };
  [MSCrashes setUserConfirmationHandler:userConfirmationHandlerNO];
  [[MSCrashes sharedInstance] startCrashProcessing];

  // Then
  assertThat([MSCrashes sharedInstance].crashFiles, hasCountOf(0));
}

- (void)testProcessCrashesWithErrorAttachments {
  
  // When
  id logManagerMock = OCMProtocolMock(@protocol(MSLogManager));
  assertThatBool([MSCrashesTestUtil copyFixtureCrashReportWithFileName:@"live_report_exception"], isTrue());
  [[MSCrashes sharedInstance] startWithLogManager:logManagerMock appSecret:kMSTestAppSecret];
  NSString *validString = @"valid";
  NSData *validData = [validString dataUsingEncoding:NSUTF8StringEncoding];
  NSData *emptyData = [@"" dataUsingEncoding:NSUTF8StringEncoding];
  NSArray *invalidLogs = @[
    [self attachmentWithAttachmentId:nil attachmentData:validData contentType:validString],
    [self attachmentWithAttachmentId:@"" attachmentData:validData contentType:validString],
    [self attachmentWithAttachmentId:validString attachmentData:nil contentType:validString],
    [self attachmentWithAttachmentId:validString attachmentData:emptyData contentType:validString],
    [self attachmentWithAttachmentId:validString attachmentData:validData contentType:nil],
    [self attachmentWithAttachmentId:validString attachmentData:validData contentType:@""]
  ];
  MSErrorAttachmentLog *validLog = [self attachmentWithAttachmentId:validString attachmentData:validData contentType:validString];
  NSMutableArray *logs = invalidLogs.mutableCopy;
  [logs addObject:validLog];
  id crashesDelegateMock = OCMProtocolMock(@protocol(MSCrashesDelegate));
  OCMStub([crashesDelegateMock attachmentsWithCrashes:[OCMArg any] forErrorReport:[OCMArg any]]).andReturn(logs);
  OCMStub([crashesDelegateMock crashes:[OCMArg any] shouldProcessErrorReport:[OCMArg any]]).andReturn(YES);
  [[MSCrashes sharedInstance] setDelegate:crashesDelegateMock];

  //Then
  for(NSUInteger i = 0; i < invalidLogs.count; i++) {
    OCMReject([logManagerMock processLog:invalidLogs[i] forGroupId:[OCMArg any]]);
  }
  OCMExpect([logManagerMock processLog:validLog forGroupId:[OCMArg any]]);
  [[MSCrashes sharedInstance] startCrashProcessing];
  OCMVerifyAll(logManagerMock);
}

- (void)testDeleteAllFromCrashesDirectory {

  // If
  assertThatBool([MSCrashesTestUtil copyFixtureCrashReportWithFileName:@"live_report_exception"], isTrue());
  [self.sut startWithLogManager:OCMProtocolMock(@protocol(MSLogManager)) appSecret:kMSTestAppSecret];
  assertThatBool([MSCrashesTestUtil copyFixtureCrashReportWithFileName:@"live_report_signal"], isTrue());
  [self.sut startWithLogManager:OCMProtocolMock(@protocol(MSLogManager)) appSecret:kMSTestAppSecret];

  // When
  [self.sut deleteAllFromCrashesDirectory];

  // Then
  assertThat(self.sut.crashFiles, hasCountOf(0));
}

- (void)testDeleteCrashReportsOnDisabled {

  // If
  id settingsMock = OCMClassMock([NSUserDefaults class]);
  OCMStub([settingsMock objectForKey:[OCMArg any]]).andReturn(@YES);
  self.sut.storage = settingsMock;
  assertThatBool([MSCrashesTestUtil copyFixtureCrashReportWithFileName:@"live_report_exception"], isTrue());
  [self.sut startWithLogManager:OCMProtocolMock(@protocol(MSLogManager)) appSecret:kMSTestAppSecret];
  NSString *path = [self.sut.crashesDir path];

  // When
  [self.sut setEnabled:NO];

  // Then
  assertThat(self.sut.crashFiles, hasCountOf(0));
  assertThatLong([self.sut.fileManager contentsOfDirectoryAtPath:path error:nil].count, equalToLong(0));
}

- (void)testDeleteCrashReportsFromDisabledToEnabled {

  // If
  id settingsMock = OCMClassMock([NSUserDefaults class]);
  OCMStub([settingsMock objectForKey:[OCMArg any]]).andReturn(@NO);
  self.sut.storage = settingsMock;
  assertThatBool([MSCrashesTestUtil copyFixtureCrashReportWithFileName:@"live_report_exception"], isTrue());
  [self.sut startWithLogManager:OCMProtocolMock(@protocol(MSLogManager)) appSecret:kMSTestAppSecret];
  NSString *path = [self.sut.crashesDir path];

  // When
  [self.sut setEnabled:YES];

  // Then
  assertThat(self.sut.crashFiles, hasCountOf(0));
  assertThatLong([self.sut.fileManager contentsOfDirectoryAtPath:path error:nil].count, equalToLong(0));
}

- (void)testSetupLogBufferWorks {

  // If
  // Creation of buffer files is done asynchronously, we need to give it some time to create the files.
  [NSThread sleepForTimeInterval:0.05];

  // Then
  NSError *error = [NSError errorWithDomain:@"MSTestingError" code:-57 userInfo:nil];
  NSArray *first = [[NSFileManager defaultManager]
      contentsOfDirectoryAtPath:reinterpret_cast<NSString *_Nonnull>([self.sut.logBufferDir path])
                          error:&error];
  XCTAssertTrue(first.count == ms_crashes_log_buffer_size);
  for (NSString *path in first) {
    unsigned long long fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil] fileSize];
    XCTAssertTrue(fileSize == 0);
  }

  // When
  [self.sut setupLogBuffer];

  // Then
  NSArray *second = [[NSFileManager defaultManager]
      contentsOfDirectoryAtPath:reinterpret_cast<NSString *_Nonnull>([self.sut.logBufferDir path])
                          error:&error];
  for (int i = 0; i < ms_crashes_log_buffer_size; i++) {
    XCTAssertTrue([first[i] isEqualToString:second[i]]);
  }
}

- (void)testCreateBufferFile {
  // When
  NSString *testName = @"afilename";
  NSString *filePath = [[self.sut.logBufferDir path]
      stringByAppendingPathComponent:[testName stringByAppendingString:@".mscrasheslogbuffer"]];
  [self.sut createBufferFileAtURL:[NSURL fileURLWithPath:filePath]];

  // Then
  BOOL success = [[NSFileManager defaultManager] fileExistsAtPath:filePath];
  XCTAssertTrue(success);
}

- (void)testEmptyLogBufferFiles {
  // If
  NSString *testName = @"afilename";
  NSString *dataString = @"SomeBufferedData";
  NSData *someData = [dataString dataUsingEncoding:NSUTF8StringEncoding];
  NSString *filePath = [[self.sut.logBufferDir path]
      stringByAppendingPathComponent:[testName stringByAppendingString:@".mscrasheslogbuffer"]];

  [someData writeToFile:filePath options:NSDataWritingFileProtectionNone error:nil];

  // When
  BOOL success = [[NSFileManager defaultManager] fileExistsAtPath:filePath];
  XCTAssertTrue(success);

  // Then
  unsigned long long fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil] fileSize];
  XCTAssertTrue(fileSize == 16);
  [self.sut emptyLogBufferFiles];
  fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil] fileSize];
  XCTAssertTrue(fileSize == 0);
}

- (void)testBufferIndexIncrementForAllPriorities {

  // When
  MSLogWithProperties *log = [MSLogWithProperties new];
  [self.sut onEnqueuingLog:log withInternalId:MS_UUID_STRING];

  // Then
  XCTAssertTrue([self crashesLogBufferCount] == 1);
}

- (void)testBufferIndexOverflowForAllPriorities {

  // When
  for (int i = 0; i < ms_crashes_log_buffer_size; i++) {
    MSLogWithProperties *log = [MSLogWithProperties new];
    [self.sut onEnqueuingLog:log withInternalId:MS_UUID_STRING];
  }

  // Then
  XCTAssertTrue([self crashesLogBufferCount] == ms_crashes_log_buffer_size);

  // When
  MSLogWithProperties *log = [MSLogWithProperties new];
  [self.sut onEnqueuingLog:log withInternalId:MS_UUID_STRING];
  NSNumberFormatter *timestampFormatter = [[NSNumberFormatter alloc] init];
  timestampFormatter.numberStyle = NSNumberFormatterDecimalStyle;
  int indexOfLatestObject = 0;
  NSNumber *oldestTimestamp;
  for (auto it = msCrashesLogBuffer.begin(), end = msCrashesLogBuffer.end(); it != end; ++it) {
    NSString *timestampString = [NSString stringWithCString:it->timestamp.c_str() encoding:NSUTF8StringEncoding];
    NSNumber *bufferedLogTimestamp = [timestampFormatter numberFromString:timestampString];

    // Remember the timestamp if the log is older than the previous one or the initial one.
    if (!oldestTimestamp || oldestTimestamp.doubleValue > bufferedLogTimestamp.doubleValue) {
      oldestTimestamp = bufferedLogTimestamp;
      indexOfLatestObject = static_cast<int>(it - msCrashesLogBuffer.begin());
    }
  }
  // Then
  XCTAssertTrue([self crashesLogBufferCount] == ms_crashes_log_buffer_size);
  XCTAssertTrue(indexOfLatestObject == 1);

  // If
  int numberOfLogs = 50;
  // When
  for (int i = 0; i < numberOfLogs; i++) {
    MSLogWithProperties *aLog = [MSLogWithProperties new];
    [self.sut onEnqueuingLog:aLog withInternalId:MS_UUID_STRING];
  }

  indexOfLatestObject = 0;
  oldestTimestamp = nil;
  for (auto it = msCrashesLogBuffer.begin(), end = msCrashesLogBuffer.end(); it != end; ++it) {
    NSString *timestampString = [NSString stringWithCString:it->timestamp.c_str() encoding:NSUTF8StringEncoding];
    NSNumber *bufferedLogTimestamp = [timestampFormatter numberFromString:timestampString];

    // Remember the timestamp if the log is older than the previous one or the initial one.
    if (!oldestTimestamp || oldestTimestamp.doubleValue > bufferedLogTimestamp.doubleValue) {
      oldestTimestamp = bufferedLogTimestamp;
      indexOfLatestObject = static_cast<int>(it - msCrashesLogBuffer.begin());
    }
  }

  // Then
  XCTAssertTrue([self crashesLogBufferCount] == ms_crashes_log_buffer_size);
  XCTAssertTrue(indexOfLatestObject == (1 + (numberOfLogs % ms_crashes_log_buffer_size)));
}

- (void)testBufferIndexOnPersistingLog {

  // When
  MSLogWithProperties *log = [MSLogWithProperties new];
  NSString *uuid1 = MS_UUID_STRING;
  NSString *uuid2 = MS_UUID_STRING;
  NSString *uuid3 = MS_UUID_STRING;
  [self.sut onEnqueuingLog:log withInternalId:uuid1];
  [self.sut onEnqueuingLog:log withInternalId:uuid2];
  [self.sut onEnqueuingLog:log withInternalId:uuid3];

  // Then
  XCTAssertTrue([self crashesLogBufferCount] == 3);

  // When
  [self.sut onFinishedPersistingLog:nil withInternalId:uuid1];

  // Then
  XCTAssertTrue([self crashesLogBufferCount] == 2);

  // When
  [self.sut onFailedPersistingLog:nil withInternalId:uuid2];

  // Then
  XCTAssertTrue([self crashesLogBufferCount] == 1);
}

- (void)testInitializationPriorityCorrect {
  XCTAssertTrue([[MSCrashes sharedInstance] initializationPriority] == MSInitializationPriorityMax);
}

- (void)testDisableMachExceptionWorks {

  // Then
  XCTAssertTrue([[MSCrashes sharedInstance] isMachExceptionHandlerEnabled]);

  // When
  [MSCrashes disableMachExceptionHandler];

  // Then
  XCTAssertFalse([[MSCrashes sharedInstance] isMachExceptionHandlerEnabled]);

  // Then
  XCTAssertTrue([self.sut isMachExceptionHandlerEnabled]);

  // When
  [self.sut setEnableMachExceptionHandler:NO];

  // Then
  XCTAssertFalse([self.sut isMachExceptionHandlerEnabled]);
}

- (void)testWrapperCrashCallback {

  // If
  MSException *exception = [[MSException alloc] init];
  exception.message = @"a message";
  exception.type = @"a type";

  // When
  [[MSCrashes sharedInstance] startWithLogManager:OCMProtocolMock(@protocol(MSLogManager)) appSecret:kMSTestAppSecret];
  MSWrapperExceptionManager *manager = [MSWrapperExceptionManager sharedInstance];
  manager.wrapperException = exception;
  [MSCrashesTestUtil deleteAllFilesInDirectory:[MSWrapperExceptionManager directoryPath]];
  assertThatBool([MSCrashesTestUtil copyFixtureCrashReportWithFileName:@"live_report_exception"], isTrue());
  [MSCrashes wrapperCrashCallback];

  // Then
  NSArray *first =
      [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[MSWrapperExceptionManager directoryPath] error:NULL];
  XCTAssertTrue(first.count == 1);
}

- (void)testTrackExceptionWhenEnabled {
  id logManagerMock = OCMProtocolMock(@protocol(MSLogManager));
  [[MSCrashes sharedInstance] startWithLogManager:logManagerMock appSecret:kMSTestAppSecret];
  MSException *exception = [[MSException alloc] init];
  id errorLogFormatterMock = OCMClassMock([MSErrorLogFormatter class]);
  MSAppleErrorLog *emptyLog = [[MSAppleErrorLog alloc] init];
  OCMStub(ClassMethod([errorLogFormatterMock errorLogFromException:exception])).andReturn(emptyLog);

  [[MSCrashes sharedInstance] trackException:exception fatal:YES];

  OCMVerify([logManagerMock processLog:emptyLog forGroupId:[MSCrashes sharedInstance].groupId]);
}

- (void)testTrackExceptionWhenDisabled {
  id logManagerMock = OCMProtocolMock(@protocol(MSLogManager));
  [[MSCrashes sharedInstance] startWithLogManager:logManagerMock appSecret:kMSTestAppSecret];
  [[MSCrashes sharedInstance] setEnabled:NO];
  MSException *exception = [[MSException alloc] init];
  id errorLogFormatterMock = OCMClassMock([MSErrorLogFormatter class]);
  MSAppleErrorLog *emptyLog = [[MSAppleErrorLog alloc] init];
  OCMStub(ClassMethod([errorLogFormatterMock errorLogFromException:exception])).andReturn(emptyLog);

  // Should not call process log
  [[logManagerMock reject] processLog:emptyLog forGroupId:[MSCrashes sharedInstance].groupId];

  [[MSCrashes sharedInstance] trackException:exception fatal:YES];
}

- (void)testTrackExceptionNonFatal {
  id logManagerMock = OCMProtocolMock(@protocol(MSLogManager));
  [[MSCrashes sharedInstance] startWithLogManager:logManagerMock appSecret:kMSTestAppSecret];
  MSException *exception = [[MSException alloc] init];
  id errorLogFormatterMock = OCMClassMock([MSErrorLogFormatter class]);
  MSAppleErrorLog *emptyLog = [[MSAppleErrorLog alloc] init];
  emptyLog.fatal = YES;
  OCMStub(ClassMethod([errorLogFormatterMock errorLogFromException:exception])).andReturn(emptyLog);

  [[MSCrashes sharedInstance] trackException:exception fatal:NO];

  XCTAssertFalse(emptyLog.fatal);
}

- (void)testTrackExceptionFatal {
  id logManagerMock = OCMProtocolMock(@protocol(MSLogManager));
  [[MSCrashes sharedInstance] startWithLogManager:logManagerMock appSecret:kMSTestAppSecret];
  MSException *exception = [[MSException alloc] init];
  id errorLogFormatterMock = OCMClassMock([MSErrorLogFormatter class]);
  MSAppleErrorLog *emptyLog = [[MSAppleErrorLog alloc] init];
  emptyLog.fatal = NO;
  OCMStub(ClassMethod([errorLogFormatterMock errorLogFromException:exception])).andReturn(emptyLog);

  [[MSCrashes sharedInstance] trackException:exception fatal:YES];

  XCTAssertTrue(emptyLog.fatal);
}


- (void)testAbstractErrorLogSerialization {
  MSAbstractErrorLog *log = [MSAbstractErrorLog new];

  // When
  NSDictionary *serializedLog = [log serializeToDictionary];

  // Then
  XCTAssertFalse([static_cast<NSNumber *>([serializedLog objectForKey:kMSFatal]) boolValue]);

  // If
  log.fatal = NO;

  // When
  serializedLog = [log serializeToDictionary];

  // Then
  XCTAssertFalse([static_cast<NSNumber *>([serializedLog objectForKey:kMSFatal]) boolValue]);

  // If
  log.fatal = YES;

  // When
  serializedLog = [log serializeToDictionary];

  // Then
  XCTAssertTrue([static_cast<NSNumber *>([serializedLog objectForKey:kMSFatal]) boolValue]);
}

- (void)testWarningMessageAboutTooManyErrorAttachments {

  NSString *expectedMessage = [NSString stringWithFormat:@"A limit of %u attachments per error report might be enforced by server.", kMaxAttachmentsPerCrashReport];
  __block bool warningMessageHasBeenPrinted = false;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-parameter"
  [MSLogger setLogHandler:^(MSLogMessageProvider messageProvider, MSLogLevel logLevel, NSString *tag, const char *file,
                            const char *function, uint line) {
    if(warningMessageHasBeenPrinted) {
      return;
    }
    NSString *message = messageProvider();
    warningMessageHasBeenPrinted = [message isEqualToString:expectedMessage];
  }];
#pragma clang diagnostic pop

  // When
  assertThatBool([MSCrashesTestUtil copyFixtureCrashReportWithFileName:@"live_report_exception"], isTrue());
  [[MSCrashes sharedInstance] setDelegate:self];
  [[MSCrashes sharedInstance] startWithLogManager:OCMProtocolMock(@protocol(MSLogManager)) appSecret:kMSTestAppSecret];
  [[MSCrashes sharedInstance] startCrashProcessing];

  XCTAssertTrue(warningMessageHasBeenPrinted);
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-parameter"
- (NSArray<MSErrorAttachmentLog *> *)attachmentsWithCrashes:(MSCrashes *)crashes forErrorReport:(MSErrorReport *)errorReport {
  id deviceMock = OCMPartialMock([MSDevice new]);
  OCMStub([deviceMock isValid]).andReturn(YES);

  NSMutableArray *logs = [NSMutableArray new];
  for(unsigned int i = 0; i < kMaxAttachmentsPerCrashReport + 1; ++i) {
    NSString *text = [NSString stringWithFormat:@"%d", i];
    MSErrorAttachmentLog *log = [[MSErrorAttachmentLog alloc] initWithFilename:text attachmentText:text];
    log.toffset = [NSNumber numberWithInt:0];
    log.device = deviceMock;
    [logs addObject:log];
  }
  return logs;
}
#pragma clang diagnostic pop

- (NSInteger)crashesLogBufferCount {
  NSInteger bufferCount = 0;
  for (auto it = msCrashesLogBuffer.begin(), end = msCrashesLogBuffer.end(); it != end; ++it) {
    if (!it->internalId.empty()) {
      bufferCount++;
    }
  }
  return bufferCount;
}

- (MSErrorAttachmentLog *)attachmentWithAttachmentId:(NSString *)attachmentId
                                      attachmentData:(NSData *)attachmentData
                                         contentType:(NSString *)contentType {
  MSErrorAttachmentLog *log = [MSErrorAttachmentLog alloc];
  log.attachmentId = attachmentId;
  log.data = attachmentData;
  log.contentType = contentType;
  return log;
}

@end
