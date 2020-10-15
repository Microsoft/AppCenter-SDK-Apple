// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#ifndef MSAC_SERVICE_H
#define MSAC_SERVICE_H

#import <Foundation/Foundation.h>

/**
 * Protocol declaring service logic.
 */
@protocol MSACService <NSObject>

/**
 * Indicates whether this service is enabled.
 * The state is persisted in the device's storage across application launches.
 */
@property(class, atomic, setter=setEnabled:) BOOL isEnabled NS_SWIFT_NAME(enabled);

@end

#endif
