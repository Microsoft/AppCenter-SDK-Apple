#import "MSAnalytics.h"
#import "MSAnalyticsCategory.h"
#import "MSAnalyticsInternal.h"
#import "MSAnalyticsPrivate.h"
#import "MSAnalyticsTransmissionTargetInternal.h"
#import "MSChannelGroupProtocol.h"
#import "MSChannelUnitConfiguration.h"
#import "MSChannelUnitProtocol.h"
#import "MSEventLog.h"
#import "MSPageLog.h"
#import "MSServiceAbstractProtected.h"

// Service name for initialization.
static NSString *const kMSServiceName = @"Analytics";

// The group Id for storage.
static NSString *const kMSGroupId = @"Analytics";

// Singleton
static MSAnalytics *sharedInstance = nil;
static dispatch_once_t onceToken;

// Events values limitations
static const int minEventNameLength = 1;
static const int maxEventNameLength = 256;
static const int maxPropertiesPerEvent = 20;
static const int minPropertyKeyLength = 1;
static const int maxPropertyKeyLength = 125;
static const int maxPropertyValueLength = 125;

@implementation MSAnalytics

@synthesize autoPageTrackingEnabled = _autoPageTrackingEnabled;
@synthesize channelUnitConfiguration = _channelUnitConfiguration;

#pragma mark - Service initialization

- (instancetype)init {
  if ((self = [super init])) {

    // Set defaults.
    _autoPageTrackingEnabled = NO;

    // Init session tracker.
    _sessionTracker = [[MSSessionTracker alloc] init];
    _sessionTracker.delegate = self;

    // Init channel configuration.
    _channelUnitConfiguration = [[MSChannelUnitConfiguration alloc] initDefaultConfigurationWithGroupId:[self groupId]];

    // Set up transmission target dictionary.
    _transmissionTargets = [NSMutableDictionary new];
  }
  return self;
}

#pragma mark - MSServiceInternal

+ (instancetype)sharedInstance {
  dispatch_once(&onceToken, ^{
    if (sharedInstance == nil) {
      sharedInstance = [[self alloc] init];
    }
  });
  return sharedInstance;
}

+ (NSString *)serviceName {
  return kMSServiceName;
}

- (void)startWithChannelGroup:(id<MSChannelGroupProtocol>)channelGroup appSecret:(nullable NSString *)appSecret transmissionTargetToken:(nullable NSString *)token  {
  [super startWithChannelGroup:channelGroup appSecret:appSecret transmissionTargetToken:token];
  if (token) {
    self.defaultTransmissionTarget = [self transmissionTargetFor:(NSString *)token];
  }

  // Set up swizzling for auto page tracking.
  [MSAnalyticsCategory activateCategory];
  MSLogVerbose([MSAnalytics logTag], @"Started Analytics service.");
}

+ (NSString *)logTag {
  return @"AppCenterAnalytics";
}

- (NSString *)groupId {
  return kMSGroupId;
}

#pragma mark - MSServiceAbstract

- (void)applyEnabledState:(BOOL)isEnabled {
  [super applyEnabledState:isEnabled];
  if (isEnabled) {

    // Start session tracker.
    [self.sessionTracker start];

    // Add delegates to log manager.
    [self.channelGroup addDelegate:self.sessionTracker];
    [self.channelGroup addDelegate:self];

    // Report current page while auto page tracking is on.
    if (self.autoPageTrackingEnabled) {

      // Track on the main queue to avoid race condition with page swizzling.
      dispatch_async(dispatch_get_main_queue(), ^{
        if ([[MSAnalyticsCategory missedPageViewName] length] > 0) {
          [[self class] trackPage:(NSString * _Nonnull)[MSAnalyticsCategory missedPageViewName]];
        }
      });
    }

    MSLogInfo([MSAnalytics logTag], @"Analytics service has been enabled.");
  } else {
    [self.channelGroup removeDelegate:self.sessionTracker];
    [self.channelGroup removeDelegate:self];
    [self.sessionTracker stop];
    MSLogInfo([MSAnalytics logTag], @"Analytics service has been disabled.");
  }
}

#pragma mark - Service methods

+ (void)trackEvent:(NSString *)eventName {
  [self trackEvent:eventName withProperties:nil];
}

+ (void)trackEvent:(NSString *)eventName withProperties:(nullable NSDictionary<NSString *, NSString *> *)properties {
  [self trackEvent:eventName withProperties:properties forTransmissionTarget:nil];
}

/**
 * Track an event.
 *
 * @param eventName  event name.
 * @param transmissionTarget  the transmission target to associate to this event.
 */
+ (void)trackEvent:(NSString *)eventName forTransmissionTarget:(MSAnalyticsTransmissionTarget *)transmissionTarget {
  [self trackEvent:eventName withProperties:nil forTransmissionTarget:transmissionTarget];
}

/**
 * Track an event.
 *
 * @param eventName  event name.
 * @param properties dictionary of properties.
 * @param transmissionTarget  the transmission target to associate to this event.
 */
+ (void)trackEvent:(NSString *)eventName withProperties:(nullable NSDictionary<NSString *, NSString *> *)properties forTransmissionTarget:(nullable MSAnalyticsTransmissionTarget *)transmissionTarget {
  @synchronized(self) {
    if ([[self sharedInstance] canBeUsed]) {
      [[self sharedInstance] trackEvent:eventName withProperties:properties forTransmissionTarget:transmissionTarget];
    }
  }
}

+ (void)trackPage:(NSString *)pageName {
  [self trackPage:pageName withProperties:nil];
}

+ (void)trackPage:(NSString *)pageName withProperties:(nullable NSDictionary<NSString *, NSString *> *)properties {
  @synchronized(self) {
    if ([[self sharedInstance] canBeUsed]) {
      [[self sharedInstance] trackPage:pageName withProperties:properties];
    }
  }
}

+ (void)setAutoPageTrackingEnabled:(BOOL)isEnabled {
  @synchronized(self) {
    [[self sharedInstance] setAutoPageTrackingEnabled:isEnabled];
  }
}

+ (BOOL)isAutoPageTrackingEnabled {
  @synchronized(self) {
    return [[self sharedInstance] isAutoPageTrackingEnabled];
  }
}

#pragma mark - Private methods

- (nullable NSString *)validateEventName:(NSString *)eventName forLogType:(NSString *)logType {
  if (!eventName || [eventName length] < minEventNameLength) {
    MSLogError([MSAnalytics logTag], @"%@ name cannot be null or empty", logType);
    return nil;
  }
  if ([eventName length] > maxEventNameLength) {
    MSLogWarning([MSAnalytics logTag],
                 @"%@ '%@' : name length cannot be longer than %d characters. Name will be truncated.", logType,
                 eventName, maxEventNameLength);
    eventName = [eventName substringToIndex:maxEventNameLength];
  }
  return eventName;
}

- (NSDictionary<NSString *, NSString *> *)validateProperties:(NSDictionary<NSString *, NSString *> *)properties
                                                  forLogName:(NSString *)logName
                                                     andType:(NSString *)logType {
  NSMutableDictionary<NSString *, NSString *> *validProperties = [NSMutableDictionary new];
  for (id key in properties) {

    // Don't send more properties than we can.
    if ([validProperties count] >= maxPropertiesPerEvent) {
      MSLogWarning([MSAnalytics logTag],
                   @"%@ '%@' : properties cannot contain more than %d items. Skipping other properties.", logType,
                   logName, maxPropertiesPerEvent);
      break;
    }
    if (![key isKindOfClass:[NSString class]] || ![properties[key] isKindOfClass:[NSString class]]) {
      continue;
    }

    // Validate key.
    NSString *strKey = key;
    if ([strKey length] < minPropertyKeyLength) {
      MSLogWarning([MSAnalytics logTag], @"%@ '%@' : a property key cannot be null or empty. Property will be skipped.",
                   logType, logName);
      continue;
    }
    if ([strKey length] > maxPropertyKeyLength) {
      MSLogWarning([MSAnalytics logTag], @"%@ '%@' : property %@ : property key length cannot be longer than %d "
                                         @"characters. Property key will be truncated.",
                   logType, logName, strKey, maxPropertyKeyLength);
      strKey = [strKey substringToIndex:maxPropertyKeyLength];
    }

    // Validate value.
    NSString *value = properties[key];
    if ([value length] > maxPropertyValueLength) {
      MSLogWarning([MSAnalytics logTag], @"%@ '%@' : property '%@' : property value cannot be longer than %d "
                                         @"characters. Property value will be truncated.",
                   logType, logName, strKey, maxPropertyValueLength);
      value = [value substringToIndex:maxPropertyValueLength];
    }

    // Save valid properties.
    [validProperties setObject:value forKey:strKey];
  }
  return validProperties;
}

- (void)trackEvent:(NSString *)eventName withProperties:(NSDictionary<NSString *, NSString *> *)properties forTransmissionTarget:(MSAnalyticsTransmissionTarget *)transmissionTarget {
  if (![self isEnabled])
    return;

  // Use default transmission target if no transmission target was provided.
  if (transmissionTarget == nil) {
    transmissionTarget = self.defaultTransmissionTarget;
  }

  // Create an event log.
  MSEventLog *log = [MSEventLog new];

  // Validate event name.
  NSString *validName = [self validateEventName:eventName forLogType:log.type];
  if (!validName) {
    return;
  }

  // Set properties of the event log.
  log.name = validName;
  log.eventId = MS_UUID_STRING;
  if (properties && properties.count > 0) {

    // Send only valid properties.
    log.properties = [self validateProperties:properties forLogName:log.name andType:log.type];
  }

  // Add transmission targets.
  if (transmissionTarget) {
    [log addTransmissionTargetToken:[transmissionTarget transmissionTargetToken]];
    // TODO: support adding multiple transmission targets
  }

  // Send log to log manager.
  [self sendLog:log];
}

- (void)trackPage:(NSString *)pageName withProperties:(NSDictionary<NSString *, NSString *> *)properties {
  if (![self isEnabled])
    return;

  // Create an event log.
  MSPageLog *log = [MSPageLog new];

  // Validate event name.
  NSString *validName = [self validateEventName:pageName forLogType:log.type];
  if (!validName) {
    return;
  }

  // Set properties of the event log.
  log.name = validName;
  if (properties && properties.count > 0) {

    // Send only valid properties.
    log.properties = [self validateProperties:properties forLogName:log.name andType:log.type];
  }

  // Send log to log manager.
  [self sendLog:log];
}

- (void)setAutoPageTrackingEnabled:(BOOL)isEnabled {
  _autoPageTrackingEnabled = isEnabled;
}

- (BOOL)isAutoPageTrackingEnabled {
  return self.autoPageTrackingEnabled;
}

- (void)sendLog:(id<MSLog>)log {

  // Send log to log manager.
  [self.channelUnit enqueueItem:log];
}

/**
 * Get a transmission target.
 *
 * @param transmissionTargetToken token of the transmission target to retrieve.
 *
 * @returns The transmission target object.
 */
- (MSAnalyticsTransmissionTarget *)transmissionTargetFor:(NSString *)transmissionTargetToken {
  MSAnalyticsTransmissionTarget *transmissionTarget= [self.transmissionTargets objectForKey:transmissionTargetToken];
  if (transmissionTarget) {
    MSLogDebug([MSAnalytics logTag], @"Returning transmission target found with id %@.", transmissionTargetToken);
    return transmissionTarget;
  }
  transmissionTarget = [[MSAnalyticsTransmissionTarget alloc] initWithTransmissionTargetToken:transmissionTargetToken];
  MSLogDebug([MSAnalytics logTag], @"Created transmission target with id %@.", transmissionTargetToken);
  [self.transmissionTargets setObject:transmissionTarget forKey:transmissionTargetToken];
  // TODO: Start service if not already.
  // Scenario: getTransmissionTarget gets called before App Center has an app secret or transmission target but start
  // has been called for this service.
  return transmissionTarget;
}

+ (void)resetSharedInstance {

  // resets the once_token so dispatch_once will run again.
  onceToken = 0;
  sharedInstance = nil;
}

#pragma mark - MSSessionTracker

- (void)sessionTracker:(id)sessionTracker processLog:(id<MSLog>)log {
  (void)sessionTracker;
  [self sendLog:log];
}

+ (void)setDelegate:(nullable id<MSAnalyticsDelegate>)delegate {
  [[self sharedInstance] setDelegate:delegate];
}

#pragma mark - MSChannelDelegate

- (void)channel:(id<MSChannelProtocol>)channel willSendLog:(id<MSLog>)log {
  (void)channel;
  if (!self.delegate) {
    return;
  }
  NSObject *logObject = (NSObject *)log;
  if ([logObject isKindOfClass:[MSEventLog class]] &&
      [self.delegate respondsToSelector:@selector(analytics:willSendEventLog:)]) {
    MSEventLog *eventLog = (MSEventLog *)log;
    [self.delegate analytics:self willSendEventLog:eventLog];
  } else if ([logObject isKindOfClass:[MSPageLog class]] &&
             [self.delegate respondsToSelector:@selector(analytics:willSendPageLog:)]) {
    MSPageLog *pageLog = (MSPageLog *)log;
    [self.delegate analytics:self willSendPageLog:pageLog];
  }
}

- (void)channel:(id<MSChannelProtocol>)channel didSucceedSendingLog:(id<MSLog>)log {
  (void)channel;
  if (!self.delegate) {
    return;
  }
  NSObject *logObject = (NSObject *)log;
  if ([logObject isKindOfClass:[MSEventLog class]] &&
      [self.delegate respondsToSelector:@selector(analytics:didSucceedSendingEventLog:)]) {
    MSEventLog *eventLog = (MSEventLog *)log;
    [self.delegate analytics:self didSucceedSendingEventLog:eventLog];
  } else if ([logObject isKindOfClass:[MSPageLog class]] &&
             [self.delegate respondsToSelector:@selector(analytics:didSucceedSendingPageLog:)]) {
    MSPageLog *pageLog = (MSPageLog *)log;
    [self.delegate analytics:self didSucceedSendingPageLog:pageLog];
  }
}

- (void)channel:(id<MSChannelProtocol>)channel didFailSendingLog:(id<MSLog>)log withError:(NSError *)error {
  (void)channel;
  if (!self.delegate) {
    return;
  }
  NSObject *logObject = (NSObject *)log;
  if ([logObject isKindOfClass:[MSEventLog class]] &&
      [self.delegate respondsToSelector:@selector(analytics:didFailSendingEventLog:withError:)]) {
    MSEventLog *eventLog = (MSEventLog *)log;
    [self.delegate analytics:self didFailSendingEventLog:eventLog withError:error];
  } else if ([logObject isKindOfClass:[MSPageLog class]] &&
             [self.delegate respondsToSelector:@selector(analytics:didFailSendingPageLog:withError:)]) {
    MSPageLog *pageLog = (MSPageLog *)log;
    [self.delegate analytics:self didFailSendingPageLog:pageLog withError:error];
  }
}

#pragma mark Transmission Target

/**
 * Get a transmission target.
 *
 * @param transmissionTargetToken token of the transmission target to retrieve.
 *
 * @returns The transmissionTarget object.
 */
+ (MSAnalyticsTransmissionTarget *)transmissionTargetForToken:(NSString *)transmissionTargetToken {
  return [[self sharedInstance] transmissionTargetFor:transmissionTargetToken];
}

@end
