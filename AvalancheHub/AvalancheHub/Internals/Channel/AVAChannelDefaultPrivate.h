/*
 * Copyright (c) Microsoft Corporation. All rights reserved.
 */

#import "AVAChannelDefault.h"
#import "AVASender.h"
#import "AVAStorage.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^completionBlock)(BOOL);

@interface AVAChannelDefault ()

/**
 *  A sender instance that is used to send batches of log items to the backend.
 */
@property(nonatomic, strong, nullable) id<AVASender> sender;

/**
 *  A storage instance to store and read enqueued log items.
 */
@property(nonatomic, strong, nullable) id<AVAStorage> storage;

/**
 *  A timer source which is used to flush the queue after a certain amount of
 * time.
 */
@property(nonatomic, strong, nullable) dispatch_source_t timerSource;

/**
 *  A queue which makes adding new items thread safe.
 */
@property(nonatomic, strong) dispatch_queue_t dataItemsOperations;

/**
 *  A counter that keeps tracks of the number of log items added to the queue.
 */
@property(nonatomic, assign) NSUInteger itemsCount;

/**
 * Enqueues a new log item.
 *
 * param item The log item that should be enqueued
 * param completion A completion block that gets called after the item was
 * enqueued
 */
- (void)enqueueItem:(id<AVALog>)item
     withCompletion:(nullable completionBlock)completion;

@end

NS_ASSUME_NONNULL_END
