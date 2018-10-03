#import <Foundation/Foundation.h>

#import "MSAnalyticsTransmissionTarget.h"
#import "MSChannelDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface MSPropertyConfigurator () <MSChannelDelegate>

/**
 * The application version to be overwritten.
 */
@property(nonatomic, copy) NSString *appVersion;

/**
 * The application name to be overwritten.
 */
@property(nonatomic, copy) NSString *appName;

/**
 * The application locale to be overwritten.
 */
@property(nonatomic, copy) NSString *appLocale;

/**
 * The transmission target which will have overwritten properties.
 */
@property(nonatomic, weak) MSAnalyticsTransmissionTarget *transmissionTarget;

/**
 * Event properties attached to events tracked by this target.
 */
@property(nonatomic, nullable) NSMutableDictionary<NSString *, NSString *> *eventProperties;

/**
 * The device id to send with common schema logs. If nil, nothing is sent.
 */
@property(nonatomic, copy) NSString *deviceId;

/**
 * Initialize property configurator with a transmission target.
 */
- (instancetype)initWithTransmissionTarget:(MSAnalyticsTransmissionTarget *)transmissionTarget;

@end

NS_ASSUME_NONNULL_END
