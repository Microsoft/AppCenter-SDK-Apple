/*
 * Copyright (c) Microsoft Corporation. All rights reserved.
 */

#ifndef SNMUtils_h
#define SNMUtils_h

#define mustOverride() NSAssert(NO, @"Method '%@' must be overriden in a subclass", NSStringFromSelector(_cmd))
#define kSNMUserDefaults [SNMUserDefaults shared]
#define kSNMNotificationCenter [NSNotificationCenter defaultCenter]
#define kSNMDevice [UIDevice currentDevice]
#define kSNMApplication [UIApplication sharedApplication]
#define kSNMUUIDString [[NSUUID UUID] UUIDString]
#define kSNMUUIDFromString(uuidString) [[NSUUID alloc] initWithUUIDString:uuidString]
#define kSNMLocale [NSLocale currentLocale]
#endif /* SNMUtils_h */
