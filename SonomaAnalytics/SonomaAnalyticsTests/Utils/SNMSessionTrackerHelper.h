/*
 * Copyright (c) Microsoft Corporation. All rights reserved.
 */

#import <Foundation/Foundation.h>

@interface SNMSessionTrackerHelper : NSObject

+ (void)simulateDidEnterBackgroundNotification;
+ (void)simulateWillEnterForegroundNotification;

@end
