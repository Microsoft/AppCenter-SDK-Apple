#import "MSChannelDelegate.h"
#import "MSPush.h"
#import "MSPushDelegate.h"
#import "MSServiceInternal.h"

NS_ASSUME_NONNULL_BEGIN

@interface MSPush () <MSServiceInternal, MSChannelDelegate>

/**
 * Set the delegate
 *
 * Defines the class that implements the optional protocol `MSPushDelegate`
 *
 * @see MSPushDelegate
 *
 * @param delegate Sender's delegate
 */
+ (void)setDelegate:(nullable id <MSPushDelegate>)delegate;

@end

NS_ASSUME_NONNULL_END
