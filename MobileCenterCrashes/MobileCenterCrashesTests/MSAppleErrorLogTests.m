#import <Foundation/Foundation.h>
#import <OCMock/OCMock.h>
#import <OCHamcrestIOS/OCHamcrestIOS.h>
#import <XCTest/XCTest.h>

#import "MSAppleErrorLog.h"
#import "MSBinary.h"
#import "MSCrashesTestUtil.h"
#import "MSErrorAttachment.h"
#import "MSException.h"
#import "MSThread.h"

@interface MSAppleErrorLogTests : XCTestCase

@property(nonatomic) MSAppleErrorLog *sut;


@end


@implementation MSAppleErrorLogTests


#pragma mark - Housekeeping

- (void)setUp {
  [super setUp];

  self.sut = [self appleErrorLog];
}

- (void)tearDown {
  [super tearDown];
}

#pragma mark - Helper

- (MSAppleErrorLog *)appleErrorLog {

  MSAppleErrorLog *appleLog = [MSAppleErrorLog new];
  appleLog.type = @"iOS Error";
  appleLog.primaryArchitectureId = @1;
  appleLog.architectureVariantId = @123;
  appleLog.applicationPath = @"user/something/something/mypath";
  appleLog.osExceptionType = @"NSSuperOSException";
  appleLog.osExceptionCode = @"0x08aeee81";
  appleLog.osExceptionAddress = @"0x124342345";
  appleLog.exceptionType = @"NSExceptionType";
  appleLog.exceptionReason = @"Trying to access array[12]";
  appleLog.threads = @[[MSThread new]];
  appleLog.binaries = @[[MSBinary new]];
  appleLog.exception = [MSCrashesTestUtil exception];
  appleLog.errorId = @"123";
  appleLog.processId = @123;
  appleLog.processName = @"123";
  appleLog.parentProcessId = @234;
  appleLog.parentProcessName = @"234";
  appleLog.errorThreadId = @2;
  appleLog.errorThreadName = @"2";
  appleLog.fatal = @YES;
  appleLog.appLaunchTOffset = @123;
  appleLog.errorAttachment = [MSErrorAttachment attachmentWithText:@"test"];
  appleLog.architecture = @"test";

  return appleLog;
}

#pragma mark - Tests

- (void)testInitializationWorks {
  XCTAssertNotNil(self.sut);
}

- (void)testSerializationToDicationaryWorks {
  NSDictionary *actual = [self.sut serializeToDictionary];
  XCTAssertNotNil(actual);
  assertThat(actual[@"type"], equalTo(self.sut.type));
  assertThat(actual[@"primary_architecture_id"], equalTo(self.sut.primaryArchitectureId));
  assertThat(actual[@"architecture_variant_id"], equalTo(self.sut.architectureVariantId));
  assertThat(actual[@"application_path"], equalTo(self.sut.applicationPath));
  assertThat(actual[@"os_exception_type"], equalTo(self.sut.osExceptionType));
  assertThat(actual[@"os_exception_code"], equalTo(self.sut.osExceptionCode));
  assertThat(actual[@"os_exception_address"], equalTo(self.sut.osExceptionAddress));
  assertThat(actual[@"exception_type"], equalTo(self.sut.exceptionType));
  assertThat(actual[@"exception_reason"], equalTo(self.sut.exceptionReason));
  assertThat(actual[@"id"], equalTo(self.sut.errorId));
  assertThat(actual[@"process_id"], equalTo(self.sut.processId));
  assertThat(actual[@"process_name"], equalTo(self.sut.processName));
  assertThat(actual[@"parent_process_id"], equalTo(self.sut.parentProcessId));
  assertThat(actual[@"parent_process_name"], equalTo(self.sut.parentProcessName));
  assertThat(actual[@"error_thread_id"], equalTo(self.sut.errorThreadId));
  assertThat(actual[@"error_thread_name"], equalTo(self.sut.errorThreadName));
  XCTAssertEqual([actual[@"fatal"] boolValue], self.sut.fatal);
  assertThat(actual[@"app_launch_toffset"], equalTo(self.sut.appLaunchTOffset));
  assertThat(actual[@"architecture"], equalTo(self.sut.architecture));

  NSDictionary *exceptionDicationary = actual[@"exception"];
  XCTAssertNotNil(exceptionDicationary);
  assertThat(exceptionDicationary[@"type"], equalTo(self.sut.exception.type));
  assertThat(exceptionDicationary[@"message"], equalTo(self.sut.exception.message));
  assertThat(exceptionDicationary[@"wrapper_sdk_name"], equalTo(self.sut.exception.wrapperSdkName));
  
  NSDictionary *attachmentDicationary = actual[@"error_attachment"];
  XCTAssertNotNil(attachmentDicationary);
  assertThat(attachmentDicationary[@"text_attachment"], equalTo(self.sut.errorAttachment.textAttachment));
}

- (void)testNSCodingSerializationAndDeserializationWorks {

  // When
  NSData *serializedEvent =
          [NSKeyedArchiver archivedDataWithRootObject:self.sut];
  id actual = [NSKeyedUnarchiver unarchiveObjectWithData:serializedEvent];

  // Then
  assertThat(actual, notNilValue());
  assertThat(actual, instanceOf([MSAppleErrorLog class]));

  MSAppleErrorLog *actualLog = actual;

  assertThat(actualLog, equalTo(self.sut));
  XCTAssertTrue([actualLog isEqual:self.sut]);
  assertThat(actualLog.type, equalTo(self.sut.type));
  assertThat(actualLog.primaryArchitectureId, equalTo(self.sut.primaryArchitectureId));
  assertThat(actualLog.architectureVariantId, equalTo(self.sut.architectureVariantId));
  assertThat(actualLog.architecture, equalTo(self.sut.architecture));
  assertThat(actualLog.applicationPath, equalTo(self.sut.applicationPath));
  assertThat(actualLog.osExceptionType, equalTo(self.sut.osExceptionType));
  assertThat(actualLog.osExceptionCode, equalTo(self.sut.osExceptionCode));
  assertThat(actualLog.osExceptionAddress, equalTo(self.sut.osExceptionAddress));
  assertThat(actualLog.exceptionType, equalTo(self.sut.exceptionType));
  assertThat(actualLog.exceptionReason, equalTo(self.sut.exceptionReason));

  MSException *actualException = actualLog.exception;

  assertThat(actualException.type, equalTo(self.sut.exception.type));
  assertThat(actualException.message, equalTo(self.sut.exception.message));
  assertThat(actualException.wrapperSdkName, equalTo(self.sut.exception.wrapperSdkName));
}

-(void)testIsEqual {
  
  // When
  MSAppleErrorLog *first = [self appleErrorLog];
  MSAppleErrorLog *second = [self appleErrorLog];
  
  // Then
  XCTAssertTrue([first isEqual:second]);
  
  // When
  second.processId = @345;
  
  // Then
  XCTAssertFalse([first isEqual:second]);
}

-(void)testIsValid {

  // When
  MSAppleErrorLog *log = [MSAppleErrorLog new];
  log.device = OCMClassMock([MSDevice class]);
  OCMStub([log.device isValid]).andReturn(YES);
  log.sid = @"sid";
  log.toffset = @123;
  log.errorId = @"errorId";
  log.processId = @123;
  log.processName = @"processName";

  // Then
  XCTAssertFalse([log isValid]);

  // When
  log.primaryArchitectureId = @456;

  // Then
  XCTAssertFalse([log isValid]);

  // When
  log.applicationPath = @"applicationPath";

  // Then
  XCTAssertFalse([log isValid]);

  // When
  log.osExceptionType = @"exceptionType";

  // Then
  XCTAssertFalse([log isValid]);

  // When
  log.osExceptionCode = @"exceptionCode";

  // Then
  XCTAssertFalse([log isValid]);

  // When
  log.osExceptionAddress = @"exceptionAddress";

  // Then
  XCTAssertTrue([log isValid]);
}

@end
