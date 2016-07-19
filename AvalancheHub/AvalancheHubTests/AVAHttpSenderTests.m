/*
 * Copyright (c) Microsoft Corporation. All rights reserved.
 */

#import "AVAHttpSender.h"
#import "AVALogContainer.h"
#import "AvalancheHub+Internal.h"
#import <XCTest/XCTest.h>

#import "OCMock.h"
#import "OHHTTPStubs.h"

static NSTimeInterval const kAVATestTimeout = 5.0;
static NSString *const kAVABaseUrl = @"https://test.com";
static NSString *const kAVAAppKey = @"mockAppKey";

@interface AVAHttpSenderTests : XCTestCase

@property(nonatomic, strong) AVAHttpSender *sut;

@end

@implementation AVAHttpSenderTests

- (void)setUp {
  [super setUp];

  NSDictionary *headers = @{
    @"Content-Type" : @"application/json",
    @"App-Key" : @"myUnitTestAppKey",
    @"Install-ID" : kAVAUUIDString
  };

  NSDictionary *queryStrings = @{ @"api-version" : @"1.0.0-preview20160901" };
  // sut: System under test
  _sut = [[AVAHttpSender alloc] initWithBaseUrl:kAVABaseUrl
                                        headers:headers
                                   queryStrings:queryStrings];
}

- (void)tearDown {
  [super tearDown];

  [OHHTTPStubs removeAllStubs];
}

- (void)stubNSURLSession {
  [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
    return YES;
  }
      withStubResponse:^OHHTTPStubsResponse *(NSURLRequest *request) {
        NSData *stubData =
            [@"Avalanche Response" dataUsingEncoding:NSUTF8StringEncoding];
        return [OHHTTPStubsResponse responseWithData:stubData
                                          statusCode:200
                                             headers:nil];
      }]
      .name = @"httpStub_200";

  [OHHTTPStubs onStubActivation:^(NSURLRequest *_Nonnull request,
                                  id<OHHTTPStubsDescriptor> _Nonnull stub,
                                  OHHTTPStubsResponse *_Nonnull responseStub) {
    NSLog(@"%@ stubbed by %@.", request.URL, stub.name);
  }];
}

- (void)testSendBatchLogs {

  // Stub http response
  [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
    return YES;
  }
      withStubResponse:^OHHTTPStubsResponse *(NSURLRequest *request) {
        NSData *stubData =
            [@"Avalanche Response" dataUsingEncoding:NSUTF8StringEncoding];
        return [OHHTTPStubsResponse responseWithData:stubData
                                          statusCode:AVAHTTPCodesNo200OK
                                             headers:nil];
      }]
      .name = @"httpStub_200";

  NSString *containerId = @"1";
  AVALogContainer *container = [self createLogContainerWithId:containerId];

  __weak XCTestExpectation *expectation =
      [self expectationWithDescription:@"HTTP Response 200"];
  [_sut sendAsync:container
          callbackQueue:dispatch_get_main_queue()
      completionHandler:^(NSError *error, NSUInteger statusCode,
                          NSString *batchId) {

        XCTAssertNil(error);
        XCTAssertEqual(containerId, batchId);
        XCTAssertEqual(statusCode, AVAHTTPCodesNo200OK);

        [expectation fulfill];
      }];

  [self waitForExpectationsWithTimeout:kAVATestTimeout
                               handler:^(NSError *_Nullable error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@",
                                           error);
                                 }
                               }];
}

- (void)testNetworkDown {

  // Stub response
  [OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest *request) {
    return YES; // All requests
  }
      withStubResponse:^OHHTTPStubsResponse *(NSURLRequest *request) {
        NSError *notConnectedError =
            [NSError errorWithDomain:NSURLErrorDomain
                                code:kCFURLErrorNotConnectedToInternet
                            userInfo:nil];
        return [OHHTTPStubsResponse responseWithError:notConnectedError];
      }]
      .name = @"httpStub_NetworkDown";

  NSString *containerId = @"1";
  AVALogContainer *container = [self createLogContainerWithId:containerId];

  __weak XCTestExpectation *expectation =
      [self expectationWithDescription:@"HTTP Network Down"];
  [_sut sendAsync:container
          callbackQueue:dispatch_get_main_queue()
      completionHandler:^(NSError *error, NSUInteger statusCode,
                          NSString *batchId) {

        XCTAssertNotNil(error);
        XCTAssertEqual(error.domain, NSURLErrorDomain);
        XCTAssertEqual(error.code, kCFURLErrorNotConnectedToInternet);
        [expectation fulfill];
      }];

  [self waitForExpectationsWithTimeout:kAVATestTimeout
                               handler:^(NSError *_Nullable error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@",
                                           error);
                                 }
                               }];
}

- (void)testNilContainer {

  AVALogContainer *container = nil;

  __weak XCTestExpectation *expectation =
      [self expectationWithDescription:@"HTTP Network Down"];
  [_sut sendAsync:container
          callbackQueue:dispatch_get_main_queue()
      completionHandler:^(NSError *error, NSUInteger statusCode,
                          NSString *batchId) {

        XCTAssertNotNil(error);
        [expectation fulfill];

      }];

  [self waitForExpectationsWithTimeout:kAVATestTimeout
                               handler:^(NSError *_Nullable error) {
                                 if (error) {
                                   XCTFail(@"Expectation Failed with error: %@",
                                           error);
                                 }
                               }];
}

- (void)testPerformanceExample {
  // This is an example of a performance test case.
  [self measureBlock:^{
      // Put the code you want to measure the time of here.
  }];
}

#pragma mark - Test Helpers

- (AVALogContainer *)createLogContainerWithId:(NSString *)batchId {
  AVAAbstractLog *log1 = [[AVAAbstractLog alloc] init];
  log1.sid = kAVAUUIDString;

  AVADeviceLog *log2 = [[AVADeviceLog alloc] init];
  log2.sdkVersion = @"1.0.0";

  AVALogContainer *logContainer = [[AVALogContainer alloc]
      initWithBatchId:batchId
              andLogs:(NSArray<AVALog> *)@[ log1, log2 ]];
  return logContainer;
}

@end
