/*
 * Copyright (c) Microsoft Corporation. All rights reserved.
 */

#import "SNMAnalytics.h"
#import "SNMFeatureInternal.h"
#import "SNMSessionTracker.h"
#import "SNMSessionTrackerDelegate.h"

@interface SNMAnalytics () <SNMFeatureInternal, SNMSessionTrackerDelegate>

/**
 *  Session tracking component
 */
@property(nonatomic) SNMSessionTracker *sessionTracker;

@property(nonatomic) BOOL autoPageTrackingEnabled;

@end
