/*
 * Copyright (c) Microsoft Corporation. All rights reserved.
 */

@import Foundation;

#import "MSChannel.h"
#import "MSDeviceTracker.h"
#import "MSEnable.h"
#import "MSLogManager.h"
#import "MSLogManagerDelegate.h"
#import "MSSender.h"
#import "MSStorage.h"

NS_ASSUME_NONNULL_BEGIN

/**
 A log manager which triggers and manages the processing of log items on
 different channels. All items will be immediately passed to the persistence
 layer in order to make the queue crash safe. Once a maximum number of items
 have been enqueued or the internal timer finished running, events will be
 forwarded to the sender. Furthermore, its responsibility is to tell the
 persistence layer what to do with a pending batch based on the status code
 returned by the sender
 */
@interface MSLogManagerDefault : NSObject <MSLogManager>

/**
 * Initializes a new `MSLogManager` instance.
 *
 * @param sender A sender instance that is used to send batches of log items to
 * the backend.
 * @param storage A storage instance to store and read enqueued log items.
 *
 * @return A new `MSLogManager` instance.
 */
- (instancetype)initWithSender:(id<MSSender>)sender storage:(id<MSStorage>)storage;

/**
 *  Hash table of log manager delegate.
 */
@property(nonatomic) NSHashTable<id<MSLogManagerDelegate>> *delegates;

/**
 *  A sender instance that is used to send batches of log items to the backend.
 */
@property(nonatomic, strong, nullable) id<MSSender> sender;

/**
 *  A storage instance to store and read enqueued log items.
 */
@property(nonatomic, strong, nullable) id<MSStorage> storage;

/**
 *  A queue which makes adding new items thread safe.
 */
@property(nonatomic, strong) dispatch_queue_t logsDispatchQueue;

/**
 * A dictionary containing priority keys and their channel.
 */
@property(nonatomic, copy) NSMutableDictionary<NSNumber *, id<MSChannel>> *channels;

/**
 *  Device tracker provides device information.
 */
@property(nonatomic) MSDeviceTracker *deviceTracker;

@end

NS_ASSUME_NONNULL_END
