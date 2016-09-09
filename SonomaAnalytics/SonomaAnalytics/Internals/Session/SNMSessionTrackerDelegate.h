/*
 * Copyright (c) Microsoft Corporation. All rights reserved.
 */

#import "Sonoma+Internal.h"
#import <Foundation/Foundation.h>

@protocol SNMSessionTrackerDelegate <NSObject>

@required

- (void)sessionTracker:(id)sessionTracker processLog:(id<SNMLog>)log withPriority:(SNMPriority)priority;

@end
