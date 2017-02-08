@import Foundation;
#import <OCHamcrestIOS/OCHamcrestIOS.h>
#import <OCMock/OCMock.h>
@import XCTest;

#import "MSAbstractLog.h"
#import "MSChannelConfiguration.h"
#import "MSChannelDefault.h"
#import "MSLogManagerDefault.h"
#import "MSLogManagerDefaultPrivate.h"

@interface MSLogManagerDefaultTests : XCTestCase

@end

@implementation MSLogManagerDefaultTests

#pragma mark - Tests

- (void)testNewInstanceWasInitialisedCorrectly {

  // If
  id senderMock = OCMProtocolMock(@protocol(MSSender));
  id storageMock = OCMProtocolMock(@protocol(MSStorage));

  // When
  MSLogManagerDefault *sut = [[MSLogManagerDefault alloc] initWithSender:senderMock storage:storageMock];

  // Then
  assertThat(sut, notNilValue());
  assertThat(sut.logsDispatchQueue, notNilValue());
  assertThat(sut.channels, isEmpty());
  assertThat(sut.sender, equalTo(senderMock));
  assertThat(sut.storage, equalTo(storageMock));
}

- (void)testProcessingWithNewPriorityWillCreateNewChannel {

  // If
  MSPriority priority = MSPriorityDefault;
  MSLogManagerDefault *sut = [[MSLogManagerDefault alloc] initWithSender:OCMProtocolMock(@protocol(MSSender))
                                                                 storage:OCMProtocolMock(@protocol(MSStorage))];
  MSAbstractLog *log = [MSAbstractLog new];
  assertThat(sut.channels, isEmpty());

  // When
  [sut processLog:log withPriority:priority];

  // Then
  assertThat(sut.channels[@(priority)], notNilValue());
}

@end
