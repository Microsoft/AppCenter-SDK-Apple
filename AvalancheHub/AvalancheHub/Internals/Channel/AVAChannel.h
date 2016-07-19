/*
 * Copyright (c) Microsoft Corporation. All rights reserved.
 */

#import "AVAChannelConfiguration.h"
#import "AVAConstants+Internal.h"
#import "AVALog.h"
#import "AVASender.h"
#import "AVAStorage.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Defines a channel which manages a queue of log items.
 */
@protocol AVAChannel <NSObject>

/*
 * The configuration used by this channel.
 */
@property(nonatomic, strong) AVAChannelConfiguration *configuration;

@required

/**
 * Initializes a new `AVAChannelDefault` instance.
 *
 * @param sender A sender instance that is used to send batches of log items to
 * the backend.
 * @param storage A storage instance to store and read enqueued log items.
 * @param configuration The configuration used by this channel.
 * @param callbackQueue A queue on which the handler is called on.
 *
 * @return A new `AVAChannelDefault` instance.
 */
- (instancetype)initWithSender:(id<AVASender>)sender
                       storage:(id<AVAStorage>)storage
                 configuration:(AVAChannelConfiguration *)configuration
                 callbackQueue:(dispatch_queue_t)callbackQueue;

/**
 * Enqueues a new log item.
 *
 * param item The log item that should be enqueued
 */
- (void)enqueueItem:(id<AVALog>)item;

@end

NS_ASSUME_NONNULL_END
