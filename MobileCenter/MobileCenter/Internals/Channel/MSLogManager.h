#import "../Model/MSLog.h"
#import "MSEnable.h"
#import "MSLogManagerDelegate.h"
#import <Foundation/Foundation.h>

@protocol MSChannelDelegate;

NS_ASSUME_NONNULL_BEGIN

/**
 * Defines A log manager which triggers and manages the processing of log items on different channels.
 */
@protocol MSLogManager <NSObject, MSEnable>

@optional

/**
 *  Add delegate.
 *
 *  @param delegate delegate.
 */
- (void)addDelegate:(id<MSLogManagerDelegate>)delegate;

/**
 *  Remove delegate.
 *
 *  @param delegate delegate.
 */
- (void)removeDelegate:(id<MSLogManagerDelegate>)delegate;

@required

/**
 * Change the base URL (schema + authority + port only) used to communicate with the backend.
 *
 * @param logUrl base URL to use for backend communication.
 */
- (void)setLogUrl:(NSString *)logUrl;

/**
 * Triggers processing of a new log item.
 *
 * @param log The log item that should be enqueued.
 * @param priority The priority for processing the log.
 * @param groupID The groupID for processing the log.
 */
- (void)processLog:(id<MSLog>)log withPriority:(MSPriority)priority andGroupID:(NSString *)groupID;

/**
 *  Enable/disable this instance and delete data on disabled state.
 *
 *  @param isEnabled  A boolean value set to YES to enable the instance or NO to disable it.
 *  @param deleteData A boolean value set to YES to delete data or NO to keep it.
 *  @param groupID A groupID to enable/disable.
 *  @param priority The priority of the groupID to enable/disable.
 */
- (void)setEnabled:(BOOL)isEnabled
    andDeleteDataOnDisabled:(BOOL)deleteData
                 forGroupID:(NSString *)groupID
               withPriority:(MSPriority)priority;

/**
 * Add a delegate to each channel that has a certain priority.
 *
 * @param channelDelegate A delegate for the channel.
 * @param groupID The groupID of a channel.
 * @param priority The priority of a channel.
 */
- (void)addChannelDelegate:(id<MSChannelDelegate>)channelDelegate
                forGroupID:(NSString *)groupID
              withPriority:(MSPriority)priority;

/**
 * Remove a delegate to each channel that has a certain priority.
 *
 * @param channelDelegate A delegate for the channel.
 * @param groupID The groupID of a channel.
 * @param priority The priority of a channel.
 */
- (void)removeChannelDelegate:(id<MSChannelDelegate>)channelDelegate
                   forGroupID:(NSString *)groupID
                 withPriority:(MSPriority)priority;

@end

NS_ASSUME_NONNULL_END
