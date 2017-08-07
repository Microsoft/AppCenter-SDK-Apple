#import "MSAnalyticsInternal.h"
#import "MSSessionTracker.h"
#import "MSStartSessionLog.h"
#import "MSStartServiceLog.h"
#import "MSUtility+Date.h"

static NSTimeInterval const kMSSessionTimeOut = 20;
static NSString *const kMSPastSessionsKey = @"pastSessionsKey";
static NSUInteger const kMSMaxSessionHistoryCount = 5;

@interface MSSessionTracker ()

/**
 * Current session id.
 */
@property(nonatomic, copy) NSString *sessionId;

/**
 * Flag to indicate if session tracking has started or not.
 */
@property(nonatomic) BOOL started;

/**
 * Check if current session has timed out.
 *
 * @return YES if current session has timed out, NO otherwise.
 */
- (BOOL)hasSessionTimedOut;

@end

@implementation MSSessionTracker

- (instancetype)init {
  if ((self = [super init])) {
    _sessionTimeout = kMSSessionTimeOut;

    // Restore past sessions from NSUserDefaults.
    NSData *sessions = [MS_USER_DEFAULTS objectForKey:kMSPastSessionsKey];
    if (sessions != nil) {
      NSArray *arrayFromData = [NSKeyedUnarchiver unarchiveObjectWithData:sessions];

      // If array is not nil, create a mutable version.
      if (arrayFromData)
        _pastSessions = [NSMutableArray arrayWithArray:arrayFromData];
    }

    // Create new array.
    if (_pastSessions == nil)
      _pastSessions = [NSMutableArray<MSSessionHistoryInfo *> new];

    // Session tracking is not started by default.
    _started = NO;
  }
  return self;
}

- (NSString *)sessionId {
  @synchronized(self) {

    // Check if new session id is required.
    if (_sessionId == nil || [self hasSessionTimedOut]) {
      _sessionId = MS_UUID_STRING;

      // Record session.
      MSSessionHistoryInfo *sessionInfo = [[MSSessionHistoryInfo alloc] init];
      sessionInfo.sessionId = _sessionId;
      sessionInfo.toffset = [NSNumber numberWithDouble:[MSUtility nowInMilliseconds]];

      // Insert new MSSessionHistoryInfo at the proper index to keep pastSessions sorted.
      NSUInteger newIndex = [self.pastSessions indexOfObject:sessionInfo
          inSortedRange:(NSRange) { 0, [self.pastSessions count] }
          options:NSBinarySearchingInsertionIndex
          usingComparator:^(id a, id b) {
            return [((MSSessionHistoryInfo *)a).toffset compare:((MSSessionHistoryInfo *)b).toffset];
          }];
      [self.pastSessions insertObject:sessionInfo atIndex:newIndex];

      // Remove first (the oldest) item if reached max limit.
      if ([self.pastSessions count] > kMSMaxSessionHistoryCount)
        [self.pastSessions removeObjectAtIndex:0];

      // Persist the session history in NSData format.
      [MS_USER_DEFAULTS setObject:[NSKeyedArchiver archivedDataWithRootObject:self.pastSessions]
                           forKey:kMSPastSessionsKey];
      NSString *session = _sessionId;
      MSLogInfo([MSAnalytics logTag], @"New session ID: %@", session);

      // Create a start session log.
      MSStartSessionLog *log = [[MSStartSessionLog alloc] init];
      log.sid = _sessionId;
      [self.delegate sessionTracker:self processLog:log];
    }
    return _sessionId;
  }
}

- (void)start {
  if (!self.started) {

    // Request a new session id depending on the application state.
    if ([MSUtility applicationState] == MSApplicationStateInactive ||
        [MSUtility applicationState] == MSApplicationStateActive) {
      [self sessionId];
    }

    // Hookup to application events.
    [MS_NOTIFICATION_CENTER addObserver:self
                               selector:@selector(applicationDidEnterBackground)
#if TARGET_OS_OSX
                                   name:NSApplicationDidResignActiveNotification
#else
                                   name:UIApplicationDidEnterBackgroundNotification
#endif
                                 object:nil];
    [MS_NOTIFICATION_CENTER addObserver:self
                               selector:@selector(applicationWillEnterForeground)
#if TARGET_OS_OSX
                                   name:NSApplicationWillBecomeActiveNotification
#else
                                   name:UIApplicationWillEnterForegroundNotification
#endif
                                 object:nil];
    self.started = YES;
  }
}

- (void)stop {
  if (self.started) {
    [MS_NOTIFICATION_CENTER removeObserver:self];
    self.started = NO;
  }
}

- (void)clearSessions {
  @synchronized(self) {

    // Clear persistence.
    [MS_USER_DEFAULTS removeObjectForKey:kMSPastSessionsKey];

    // Clear cache.
    self.sessionId = nil;
    [self.pastSessions removeAllObjects];
  }
}

#pragma mark - private methods

- (BOOL)hasSessionTimedOut {

  @synchronized(self) {
    NSDate *now = [NSDate date];

    // Verify if a log has already been sent and if it was sent a longer time ago than the session timeout.
    BOOL noLogSentForLong =
        !self.lastCreatedLogTime || [now timeIntervalSinceDate:self.lastCreatedLogTime] >= self.sessionTimeout;

    // FIXME: There is no life cycle for app extensions yet so ignoring the background tests for now.
    if (MS_IS_APP_EXTENSION)
      return noLogSentForLong;

    // Verify if app is currently in the background for a longer time than the session timeout.
    BOOL isBackgroundForLong =
        (self.lastEnteredBackgroundTime && self.lastEnteredForegroundTime) &&
        ([self.lastEnteredBackgroundTime compare:self.lastEnteredForegroundTime] == NSOrderedDescending) &&
        ([now timeIntervalSinceDate:self.lastEnteredBackgroundTime] >= self.sessionTimeout);

    // Verify if app was in the background for a longer time than the session
    // timeout time.
    BOOL wasBackgroundForLong = (self.lastEnteredBackgroundTime)
                                    ? [self.lastEnteredForegroundTime
                                          timeIntervalSinceDate:self.lastEnteredBackgroundTime] >= self.sessionTimeout
                                    : false;
    return noLogSentForLong && (isBackgroundForLong || wasBackgroundForLong);
  }
}

- (void)applicationDidEnterBackground {
  self.lastEnteredBackgroundTime = [NSDate date];
}

- (void)applicationWillEnterForeground {
  self.lastEnteredForegroundTime = [NSDate date];

  // Trigger session renewal.
  [self sessionId];
}

#pragma mark - MSLogManagerDelegate

- (void)onEnqueuingLog:(id<MSLog>)log withInternalId:(NSString *)internalId {
  (void)internalId;

  /*
   * Start session log is created in this method, therefore, skip in order to avoid infinite loop.
   * Also skip start service log as it's always sent and should not trigger a session.
   */
  if ([((NSObject *)log) isKindOfClass:[MSStartSessionLog class]] ||
      [((NSObject *)log) isKindOfClass:[MSStartServiceLog class]])
    return;

  // Attach corresponding session id.
  if (log.toffset) {
    MSSessionHistoryInfo *find = [[MSSessionHistoryInfo alloc] initWithTOffset:log.toffset andSessionId:nil];
    NSUInteger index =
        [self.pastSessions indexOfObject:find
                           inSortedRange:NSMakeRange(0, self.pastSessions.count)
                                 options:(NSBinarySearchingFirstEqual | NSBinarySearchingInsertionIndex)
                         usingComparator:^(id a, id b) {
                           return [((MSSessionHistoryInfo *)a).toffset compare:((MSSessionHistoryInfo *)b).toffset];
                         }];

    // All toffsets are larger.
    if (index == 0) {
      log.sid = self.sessionId;
    }

    // All toffsets are smaller.
    else if (index == self.pastSessions.count) {
      log.sid = [self.pastSessions lastObject].sessionId;
    }

    // Either the pastSessions contains the exact toffset or we pick the smallest delta.
    else {
      long long leftDifference = [log.toffset longLongValue] - [self.pastSessions[index - 1].toffset longLongValue];
      long long rightDifference = [self.pastSessions[index].toffset longLongValue] - [log.toffset longLongValue];
      if (leftDifference < rightDifference) {
        --index;
      }
      log.sid = self.pastSessions[index].sessionId;
    }
  }

  // If log is not correlated to a past session.
  if (log.sid == nil) {
    log.sid = self.sessionId;
  }

  // Update last created log time stamp.
  self.lastCreatedLogTime = [NSDate date];
}

@end
