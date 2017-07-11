#import "MSAnalyticsInternal.h"
#import "MSUtility+Date.h"
#import "MSSessionTracker.h"
#import "MSStartSessionLog.h"
#import "MSStartServiceLog.h"

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
      sessionInfo.timestamp = [NSDate date];

      // Insert at the beginning of the list.
      [self.pastSessions insertObject:sessionInfo atIndex:0];

      // Remove last item if reached max limit.
      if ([self.pastSessions count] > kMSMaxSessionHistoryCount)
        [self.pastSessions removeLastObject];

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
                                   name:UIApplicationDidEnterBackgroundNotification
                                 object:nil];
    [MS_NOTIFICATION_CENTER addObserver:self
                               selector:@selector(applicationWillEnterForeground)
                                   name:UIApplicationWillEnterForegroundNotification
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
  if ([((NSObject *)log) isKindOfClass:[MSStartSessionLog class]] || [((NSObject *)log) isKindOfClass:[MSStartServiceLog class]])
    return;

  // Attach corresponding session id.
  if (log.timestamp) {
    MSSessionHistoryInfo *find = [[MSSessionHistoryInfo alloc] initWithTimestamp:log.timestamp andSessionId:nil];
    NSUInteger index =
        [self.pastSessions indexOfObject:find
                           inSortedRange:NSMakeRange(0, self.pastSessions.count)
                                 options:(NSBinarySearchingFirstEqual | NSBinarySearchingInsertionIndex)
                         usingComparator:^(MSSessionHistoryInfo *a, MSSessionHistoryInfo *b) {
                           return [a.timestamp compare:b.timestamp];
                         }];

    // All timestamps are larger.
    if (index == 0) {
      log.sid = self.sessionId;
    }

    // All timestamps are smaller.
    else if (index == self.pastSessions.count) {
      log.sid = [self.pastSessions lastObject].sessionId;
    }

    // Either the pastSessions contains the exact timestamp or we pick the smallest delta.
    else {
      NSTimeInterval leftDifference = [log.timestamp timeIntervalSinceDate:self.pastSessions[index - 1].timestamp];
      NSTimeInterval rightDifference = [self.pastSessions[index].timestamp timeIntervalSinceDate:log.timestamp];
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
