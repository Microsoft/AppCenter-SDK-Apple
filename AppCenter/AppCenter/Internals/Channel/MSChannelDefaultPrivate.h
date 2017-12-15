#import "MSChannelDefault.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Private declarations.
 */
@interface MSChannelDefault ()

/**
 * A boolean value set to YES if the channel is enabled or NO otherwise.
 * Enable/disable does resume/suspend the channel as needed under the hood.
 * When a channel is disabled with data deletion it deletes persisted logs and discards incoming logs.
 */
@property(nonatomic) BOOL enabled;

/**
 * A boolean value set to YES if the channel is suspended or NO otherwise.
 * A channel is suspended when it becomes disabled or when its sender becomes suspended itself.
 * A suspended channel doesn't forward logs to the sender.
 * A suspended state doesn't impact the current enabled state.
 */
@property(nonatomic) BOOL suspended;

/**
 * A boolean value set to YES if logs are discarded (not persisted) or NO otherwise.
 * Logs are discarded when the related service is disabled or an unrecoverable error happened.
 */
@property(nonatomic) BOOL discardLogs;

/**
 * Completion block executed when stopped flushing logs.
 */
@property(nonatomic, nullable) MSForceFlushCompletionBlock forceFlushCompletion;

/**
 * Trigger flushing the queue, which will result in logs being sent.
 */
- (void)flushQueue;

@end

NS_ASSUME_NONNULL_END
