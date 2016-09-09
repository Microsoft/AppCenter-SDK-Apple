/*
 * Copyright (c) Microsoft Corporation. All rights reserved.
 */

#import "SNMCrashesHelper.h"
#import <sys/sysctl.h>

static NSString *const kSNMCrashesDirectory = @"com.microsoft.sonoma/crashes";

@interface SNMCrashesHelper ()

BOOL snm_isDebuggerAttached(void);
BOOL snm_isRunningInAppExtension(void);
NSString *snm_crashesDir(void);

@end

@implementation SNMCrashesHelper

#pragma mark - Public

+ (NSString *)crashesDir {
  static NSString *crashesDir = nil;
  static dispatch_once_t predSettingsDir;

  dispatch_once(&predSettingsDir, ^{
    NSFileManager *fileManager = [[NSFileManager alloc] init];

    // temporary directory for crashes grabbed from PLCrashReporter
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    crashesDir = [[paths objectAtIndex:0] stringByAppendingPathComponent:kSNMCrashesDirectory];

    if (![fileManager fileExistsAtPath:crashesDir]) {
      NSDictionary *attributes =
          [NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedLong:0755] forKey:NSFilePosixPermissions];
      NSError *theError = NULL;

      [fileManager createDirectoryAtPath:crashesDir
             withIntermediateDirectories:YES
                              attributes:attributes
                                   error:&theError];
    }
  });

  return crashesDir;
}

+ (BOOL)isAppExtension {
  static BOOL isRunningInAppExtension = NO;
  static dispatch_once_t checkAppExtension;

  dispatch_once(&checkAppExtension, ^{
    isRunningInAppExtension =
        ([[[NSBundle mainBundle] executablePath] rangeOfString:@".appex/"].location != NSNotFound);
  });

  return isRunningInAppExtension;
}

/**
 * Check if the debugger is attached
 *
 * Taken from
 * https://github.com/plausiblelabs/plcrashreporter/blob/2dd862ce049e6f43feb355308dfc710f3af54c4d/Source/Crash%20Demo/main.m#L96
 *
 * @return `YES` if the debugger is attached to the current process, `NO`
 * otherwise
 */
+ (BOOL)isDebuggerAttached {
  static BOOL debuggerIsAttached = NO;

  static dispatch_once_t debuggerPredicate;
  dispatch_once(&debuggerPredicate, ^{
    struct kinfo_proc info;
    size_t info_size = sizeof(info);
    int name[4];

    name[0] = CTL_KERN;
    name[1] = KERN_PROC;
    name[2] = KERN_PROC_PID;
    name[3] = getpid();

    if (sysctl(name, 4, &info, &info_size, NULL, 0) == -1) {
      NSLog(@"[SNMCrashes] ERROR: Checking for a running debugger via sysctl() "
            @"failed.");
      debuggerIsAttached = false;
    }

    if (!debuggerIsAttached && (info.kp_proc.p_flag & P_TRACED) != 0)
      debuggerIsAttached = true;
  });

  return debuggerIsAttached;
}

@end
