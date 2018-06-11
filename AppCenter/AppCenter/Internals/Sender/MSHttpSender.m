#import "MSAppCenterInternal.h"
#import "MSHttpSender.h"
#import "MSHttpSenderPrivate.h"
#import "MSSenderCall.h"
#import "MSSenderDelegate.h"

static NSTimeInterval kRequestTimeout = 60.0;

// URL components' name within a partial URL.
static NSString *const kMSPartialURLComponentsName[] = {@"scheme", @"user", @"password", @"host", @"port", @"path"};

@implementation MSHttpSender

@synthesize baseURL = _baseURL;
@synthesize apiPath = _apiPath;
@synthesize reachability = _reachability;
@synthesize suspended = _suspended;

#pragma mark - Initialize

- (id)initWithBaseUrl:(NSString *)baseUrl
              apiPath:(NSString *)apiPath
              headers:(NSDictionary *)headers
         queryStrings:(NSDictionary *)queryStrings
         reachability:(MS_Reachability *)reachability
       retryIntervals:(NSArray *)retryIntervals {
  return [self initWithBaseUrl:baseUrl apiPath:apiPath headers:headers queryStrings:queryStrings reachability:reachability retryIntervals:retryIntervals maxNumberOfConnections:4];
}

- (id)initWithBaseUrl:(NSString *)baseUrl
              apiPath:(NSString *)apiPath
              headers:(NSDictionary *)headers
         queryStrings:(NSDictionary *)queryStrings
         reachability:(MS_Reachability *)reachability
       retryIntervals:(NSArray *)retryIntervals
maxNumberOfConnections:(NSInteger)maxNumberOfConnections {
  if ((self = [super init])) {
    _httpHeaders = headers;
    _pendingCalls = [NSMutableDictionary new];
    _reachability = reachability;
    _enabled = YES;
    _suspended = NO;
    _delegates = [NSHashTable weakObjectsHashTable];
    _callsRetryIntervals = retryIntervals;
    _apiPath = apiPath;
    _maxNumberOfConnections = maxNumberOfConnections;

    // Construct the URL string with the query string.
    NSMutableString *urlString = [NSMutableString stringWithFormat:@"%@%@", baseUrl, apiPath];
    __block NSMutableString *queryStringForEncoding = [NSMutableString new];

    // Set query parameter.
    [queryStrings enumerateKeysAndObjectsUsingBlock:^(id _Nonnull key, id _Nonnull queryString,
                                                      __attribute__((unused)) BOOL *_Nonnull stop) {
      [queryStringForEncoding
          appendString:[NSString stringWithFormat:@"%@%@=%@", [queryStringForEncoding length] > 0 ? @"&" : @"", key,
                                                  queryString]];
    }];
    if ([queryStringForEncoding length] > 0) {
      [urlString appendFormat:@"?%@",
                              [queryStringForEncoding
                                  stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet
                                                                                         URLQueryAllowedCharacterSet]]];
    }

    // Set send URL which can't be null
    _sendURL = (NSURL * _Nonnull)[NSURL URLWithString:urlString];

    // Hookup to reachability.
    [MS_NOTIFICATION_CENTER addObserver:self
                               selector:@selector(networkStateChanged:)
                                   name:kMSReachabilityChangedNotification
                                 object:nil];
    [self.reachability startNotifier];

    // Apply current network state.
    [self networkStateChanged];
  }
  return self;
}

#pragma mark - MSSender

- (void)sendAsync:(NSObject *)data completionHandler:(MSSendAsyncCompletionHandler)handler {
  [self sendAsync:data callId:MS_UUID_STRING completionHandler:handler];
}

- (void)addDelegate:(id<MSSenderDelegate>)delegate {
  @synchronized(self) {
    [self.delegates addObject:delegate];
  }
}

- (void)removeDelegate:(id<MSSenderDelegate>)delegate {
  @synchronized(self) {
    [self.delegates removeObject:delegate];
  }
}

#pragma mark - Life cycle

- (void)setEnabled:(BOOL)isEnabled andDeleteDataOnDisabled:(BOOL)deleteData {
  @synchronized(self) {
    if (self.enabled != isEnabled) {
      self.enabled = isEnabled;
      if (isEnabled) {
        [self.reachability startNotifier];

        // Apply current network state, this will resume if network state allows it.
        [self networkStateChanged];
      } else {
        [self.reachability stopNotifier];
        [self suspend];

        // Data deletion is required.
        if (deleteData) {

          // Cancel all the tasks and invalidate current session to free resources.
          [self.session invalidateAndCancel];
          self.session = nil;

          // Remove pending calls.
          [self.pendingCalls removeAllObjects];
        }
      }
    }
  }
}

- (void)suspend {
  @synchronized(self) {
    if (!self.suspended) {
      MSLogInfo([MSAppCenter logTag], @"Suspend sender.");
      self.suspended = YES;

      // Suspend all tasks.
      [self.session getTasksWithCompletionHandler:^(
                        NSArray<NSURLSessionDataTask *> *_Nonnull dataTasks,
                        __attribute__((unused)) NSArray<NSURLSessionUploadTask *> *_Nonnull uploadTasks,
                        __attribute__((unused)) NSArray<NSURLSessionDownloadTask *> *_Nonnull downloadTasks) {
        [dataTasks enumerateObjectsUsingBlock:^(__kindof NSURLSessionTask *_Nonnull call,
                                                __attribute__((unused)) NSUInteger idx,
                                                __attribute__((unused)) BOOL *_Nonnull stop) {
          [call suspend];
        }];
      }];

      // Suspend current calls' retry.
      [self.pendingCalls.allValues
          enumerateObjectsUsingBlock:^(MSSenderCall *_Nonnull call, __attribute__((unused)) NSUInteger idx,
                                       __attribute__((unused)) BOOL *_Nonnull stop) {
            if (!call.submitted) {
              [call resetRetry];
            }
          }];

      // Notify delegates.
      [self enumerateDelegatesForSelector:@selector(senderDidSuspend:)
                                withBlock:^(id<MSSenderDelegate> delegate) {
                                  [delegate senderDidSuspend:self];
                                }];
    }
  }
}

- (void)resume {
  @synchronized(self) {

    // Resume only while enabled.
    if (self.suspended && self.enabled) {
      MSLogInfo([MSAppCenter logTag], @"Resume sender.");
      self.suspended = NO;

      // Resume existing calls.
      [self.session getTasksWithCompletionHandler:^(
                        NSArray<NSURLSessionDataTask *> *_Nonnull dataTasks,
                        __attribute__((unused)) NSArray<NSURLSessionUploadTask *> *_Nonnull uploadTasks,
                        __attribute__((unused)) NSArray<NSURLSessionDownloadTask *> *_Nonnull downloadTasks) {
        [dataTasks enumerateObjectsUsingBlock:^(__kindof NSURLSessionTask *_Nonnull call,
                                                __attribute__((unused)) NSUInteger idx,
                                                __attribute__((unused)) BOOL *_Nonnull stop) {
          [call resume];
        }];
      }];

      // Resume calls.
      [self.pendingCalls.allValues
          enumerateObjectsUsingBlock:^(MSSenderCall *_Nonnull call, __attribute__((unused)) NSUInteger idx,
                                       __attribute__((unused)) BOOL *_Nonnull stop) {
            if (!call.submitted) {
              [self sendCallAsync:call];
            }
          }];

      // Propagate.
      [self enumerateDelegatesForSelector:@selector(senderDidResume:)
                                withBlock:^(id<MSSenderDelegate> delegate) {
                                  [delegate senderDidResume:self];
                                }];
    }
  }
}

#pragma mark - MSSenderCallDelegate

- (void)sendCallAsync:(MSSenderCall *)call {
  @synchronized(self) {
    if (self.suspended || !self.enabled) {
      return;
    }

    if (!call) {
      return;
    }

    // Create the request.
    NSURLRequest *request = [self createRequest:call.data];
    if (!request) {
      return;
    }

    // Create a task for the request.
    NSURLSessionDataTask *task = [self.session
        dataTaskWithRequest:request
          completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            @synchronized(self) {
              NSString *payload = nil;
              NSInteger statusCode = [MSSenderUtil getStatusCode:response];

              // Trying to format json for log. Don't need to log json error here.
              if (data) {

                // Error instance for JSON parsing.
                NSError *jsonError = nil;
                id dictionary = [NSJSONSerialization JSONObjectWithData:data
                                                                options:NSJSONReadingMutableContainers
                                                                  error:&jsonError];
                if (jsonError) {
                  payload = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                } else {
                  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dictionary
                                                                     options:NSJSONWritingPrettyPrinted
                                                                       error:&jsonError];
                  if (!jsonData || jsonError) {
                    payload = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                  } else {

                    // NSJSONSerialization escapes paths by default so we replace them.
                    payload = [[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]
                        stringByReplacingOccurrencesOfString:@"\\/"
                                                  withString:@"/"];
                  }
                }
              }
              MSLogVerbose([MSAppCenter logTag], @"HTTP response received with status code=%tu and payload=%@",
                           statusCode, payload);

              // Call handles the completion.
              if (call) {
                call.submitted = NO;
                [call sender:self callCompletedWithStatus:statusCode data:data error:error];
              }
            }
          }];

    // TODO: Set task priority.
    [task resume];
    call.submitted = YES;
  }
}

- (void)call:(MSSenderCall *)call completedWithResult:(MSSenderCallResult)result {
  @synchronized(self) {
    switch (result) {
    case MSSenderCallResultFatalError: {

      // Disable and delete data.
      [self setEnabled:NO andDeleteDataOnDisabled:YES];

      // Notify delegates.
      [self enumerateDelegatesForSelector:@selector(senderDidReceiveFatalError:)
                                withBlock:^(id<MSSenderDelegate> delegate) {
                                  [delegate senderDidReceiveFatalError:self];
                                }];
      break;
    }
    case MSSenderCallResultRecoverableError:

      // Disable and do not delete data. Do not notify the delegates as this will cause data to be deleted.
      [self setEnabled:NO andDeleteDataOnDisabled:NO];
      break;
    case MSSenderCallResultSuccess:
      break;
    }

    // Remove call from pending call. This needs to happen after calling setEnabled:andDeleteDataOnDisabled:
    // FIXME: Refactor dependency between calling setEnabled:andDeleteDataOnDisabled: and suspending the sender.
    NSString *callId = call.callId;
    if (callId.length == 0) {
      MSLogWarning([MSAppCenter logTag], @"Call object is invalid");
      return;
    }
    [self.pendingCalls removeObjectForKey:callId];
    MSLogInfo([MSAppCenter logTag], @"Removed call id:%@ from pending calls:%@", callId,
              [self.pendingCalls description]);
  }
}

#pragma mark - Reachability

- (void)networkStateChanged:(NSNotificationCenter *)notification {
  (void)notification;
  [self networkStateChanged];
}

#pragma mark - Private

- (void)setBaseURL:(NSString *)baseURL {
  @synchronized(self) {
    BOOL success = false;
    NSURLComponents *components;
    _baseURL = baseURL;
    NSURL *partialURL = [NSURL URLWithString:[baseURL stringByAppendingString:self.apiPath]];

    // Merge new parial URL and current full URL.
    if (partialURL) {
      components = [NSURLComponents componentsWithURL:self.sendURL resolvingAgainstBaseURL:NO];
      @try {
        for (u_long i = 0; i < sizeof(kMSPartialURLComponentsName) / sizeof(*kMSPartialURLComponentsName); i++) {
          NSString *propertyName = kMSPartialURLComponentsName[i];
          [components setValue:[partialURL valueForKey:propertyName] forKey:propertyName];
        }
      } @catch (NSException *ex) {
        MSLogInfo([MSAppCenter logTag], @"Error while updating HTTP URL %@ with %@: \n%@", self.sendURL.absoluteString,
                  baseURL, ex);
      }

      // Update full URL.
      if (components.URL) {
        self.sendURL = (NSURL * _Nonnull)components.URL;
        success = true;
      }
    }

    // Notify failure.
    if (!success) {
      MSLogInfo([MSAppCenter logTag], @"Failed to update HTTP URL %@ with %@", self.sendURL.absoluteString, baseURL);
    }
  }
}

- (void)networkStateChanged {
  if ([self.reachability currentReachabilityStatus] == NotReachable) {
    MSLogInfo([MSAppCenter logTag], @"Internet connection is down.");
    [self suspend];
  } else {
    MSLogInfo([MSAppCenter logTag], @"Internet connection is up.");
    [self resume];
  }
}

/**
 * This is an empty method and expect to be overridden in sub classes.
 */
- (NSURLRequest *)createRequest:(NSObject *)data {
  (void)data;
  return nil;
}

- (NSString *)obfuscateHeaderValue:(NSString *)key value:(NSString *)value {
  (void)key;
  return value;
}

- (NSURLSession *)session {
  if (!_session) {
    NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
    sessionConfiguration.timeoutIntervalForRequest = kRequestTimeout;
    sessionConfiguration.HTTPMaximumConnectionsPerHost = self.maxNumberOfConnections;
    _session = [NSURLSession sessionWithConfiguration:sessionConfiguration];

    /*
     * Limit callbacks execution concurrency to avoid race condition. This queue is used only for
     * delegate method calls and completion handlers.
     * See https://developer.apple.com/documentation/foundation/nsurlsession/1411571-delegatequeue
     */
    _session.delegateQueue.maxConcurrentOperationCount = 1;
  }
  return _session;
}

- (void)enumerateDelegatesForSelector:(SEL)selector withBlock:(void (^)(id<MSSenderDelegate> delegate))block {
  for (id<MSSenderDelegate> delegate in self.delegates) {
    if (delegate && [delegate respondsToSelector:selector]) {
      block(delegate);
    }
  }
}

- (NSString *)prettyPrintHeaders:(NSDictionary<NSString *, NSString *> *)headers {
  NSMutableArray<NSString *> *flattenedHeaders = [NSMutableArray<NSString *> new];
  for (NSString *headerKey in headers) {
    [flattenedHeaders
        addObject:[NSString stringWithFormat:@"%@ = %@", headerKey,
                                             [self obfuscateHeaderValue:headerKey value:headers[headerKey]]]];
  }
  return [flattenedHeaders componentsJoinedByString:@", "];
}

- (void)sendAsync:(NSObject *)data callId:(NSString *)callId completionHandler:(MSSendAsyncCompletionHandler)handler {
  @synchronized(self) {

    // Check if call has already been created(retry scenario).
    MSSenderCall *call = self.pendingCalls[callId];
    if (call == nil) {
      call = [[MSSenderCall alloc] initWithRetryIntervals:self.callsRetryIntervals];
      call.delegate = self;
      call.data = data;
      call.callId = callId;
      call.completionHandler = handler;

      // Store call in calls array.
      self.pendingCalls[callId] = call;
    }
    [self sendCallAsync:call];
  }
}

- (void)dealloc {
  [self.reachability stopNotifier];
  [MS_NOTIFICATION_CENTER removeObserver:self name:kMSReachabilityChangedNotification object:nil];
}

@end
