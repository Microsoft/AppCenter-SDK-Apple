// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSCrashesCategory.h"
#import "MSAppCenterInternal.h"
#import "MSCrashesPrivate.h"
#import "MSUtility+Application.h"
#import <objc/runtime.h>

#if TARGET_OS_OSX

/**
 * The flag to allow crashing on uncaught exceptions thrown on the main thread.
 */
static NSString *const kMSCrashOnExceptionsKey = @"NSApplicationCrashOnExceptions";

static IMP reportExceptionOriginalImp;
static IMP sendEventOriginalImp;

/*
 * `NSApplication` subclass to catch additional exceptions
 *
 * On OS X runtime, not all uncaught exceptions end in a custom `NSUncaughtExceptionHandler`.
 * In addition "sometimes" exceptions don't even cause the app to crash, depending on where and
 * when they happen.
 *
 * Here are the known scenarios:
 *
 *   1. Custom `NSUncaughtExceptionHandler` don't start working until after `NSApplication` has finished
 *      calling all of its delegate methods!
 *
 *      Example:
 *        - (void)applicationDidFinishLaunching:(NSNotification *)note {
 *          ...
 *          [NSException raise:@"ExceptionAtStartup" format:@"This will not be recognized!"];
 *          ...
 *        }
 *
 *
 *   2. The default `NSUncaughtExceptionHandler` in `NSApplication` only logs exceptions to the console and
 *      ends their processing. Resulting in exceptions that occur in the `NSApplication` "scope" not
 *      occurring in a registered custom `NSUncaughtExceptionHandler`.
 *
 *      Example:
 *        - (void)applicationDidFinishLaunching:(NSNotification *)note {
 *          ...
 *           [self performSelector:@selector(delayedException) withObject:nil afterDelay:5];
 *          ...
 *        }
 *
 *        - (void)delayedException {
 *          NSArray *array = [NSArray array];
 *          [array objectAtIndex:23];
 *        }
 *
 *   3. Any exceptions occurring in IBAction or other GUI does not even reach the NSApplication default
 *      UncaughtExceptionHandler.
 *
 *      Example:
 *        - (IBAction)doExceptionCrash:(id)sender {
 *          NSArray *array = [NSArray array];
 *          [array objectAtIndex:23];
 *        }
 *
 *
 * Solution A:
 *
 *   Implement `NSExceptionHandler` and set the `ExceptionHandlingMask` to `NSLogAndHandleEveryExceptionMask`
 *
 *   Benefits:
 *
 *     1. Solves all of the above scenarios
 *
 *     2. Clean solution using a standard Cocoa System specifically meant for this purpose.
 *
 *     3. Safe. Doesn't use private API.
 *
 *   Problems:
 *
 *     1. To catch all exceptions the `NSExceptionHandlers` mask has to include `NSLogOtherExceptionMask` and
 *        `NSHandleOtherExceptionMask`. But this will result in @catch blocks to be called after the exception
 *        handler processed the exception and likely lets the app crash and create a crash report.
 *        This makes the @catch block basically not work at all.
 *
 *     2. If anywhere in the app a custom `NSUncaughtExceptionHandler` will be registered, e.g. in a closed source
 *        library the developer has to use, the complete mechanism will stop working
 *
 *     3. Not clear if this solves all scenarios there can be.
 *
 *     4. Requires to adjust PLCrashReporter not to register its `NSUncaughtExceptionHandler` which is not a good idea,
 *        since it would require the `NSExceptionHandler` would catch *all* exceptions and that would cause
 *        PLCrashReporter to stop all running threads every time an exception occurs even if it will be handled right
 *        away, e.g. by a system framework.
 *
 *
 * Solution B:
 *
 *   Overwrite and extend specific methods of `NSApplication`. Can be implemented via subclassing NSApplication or
 *   by using a category.
 *
 *   Benefits:
 *
 *     1. Solves scenarios 2 (by overwriting `reportException:`) and 3 (by overwriting `sendEvent:`)
 *
 *     2. Subclassing approach isn't enforcing the mechanism onto apps and lets developers opt-in.
 *        (Category approach would enforce it and rather be a problem of this soltuion.)
 *
 *     3. Safe. Doesn't use private API.
 *
 *  Problems:
 *
 *     1. Does not automatically solve scenario 1. Developer would have to put all that code into @try @catch blocks
 *
 *     2. Not a clean implementation, rather feels like a workaround.
 *
 *     3. Not clear if this solves all scenarios there can be.
 *
 *
 * References:
 *   https://developer.apple.com/library/mac/documentation/cocoa/Conceptual/Exceptions/Tasks/ControllingAppResponse.html#//apple_ref/doc/uid/20000473-BBCHGJIJ
 *   http://stackoverflow.com/a/4199717/474794
 *   http://stackoverflow.com/a/3419073/474794
 *   http://macdevcenter.com/pub/a/mac/2007/07/31/understanding-exceptions-and-handlers-in-cocoa.html
 *
 */
@implementation NSApplication (MSAppCenterCrashException)

/*
 * Solution for Scenario 2
 *
 * Catch all exceptions that are being logged to the console and forward them to our
 * custom UncaughtExceptionHandler
 */
- (void)ms_reportException:(NSException *)exception {

  // Don't invoke the registered UncaughtExceptionHandler if we are currently debugging this app!
  if (![MSAppCenter isDebuggerAttached] && exception) {

    /*
     * We forward this exception to PLCrashReporters UncaughtExceptionHandler.
     * If the developer has implemented their own exception handler and that one is invoked before PLCrashReporters exception handler and
     * the developers exception handler is invoking this method it will not finish its tasks after this call but directly jump into
     * PLCrashReporters exception handler. If we wouldn't do this, this call would lead to an infinite loop.
     */
    NSUncaughtExceptionHandler *plcrExceptionHandler = [MSCrashes sharedInstance].exceptionHandler;
    if (plcrExceptionHandler) {
      plcrExceptionHandler(exception);
    }
  }

  // Forward to the original implementation.
  ((void (*)(id, SEL, NSException *))reportExceptionOriginalImp)(self, _cmd, exception);
}

/*
 * Solution for Scenario 3
 *
 * Exceptions that happen inside an IBAction implementation do not trigger a call to
 * [NSApp reportException:] and it does not trigger a registered UncaughtExceptionHandler
 * Hence we need to catch these ourselves, e.g. by overwriting sendEvent: as done right here
 *
 * On 64bit systems the @try @catch block doesn't even cost any performance.
 */
- (void)ms_sendEvent:(NSEvent *)theEvent {
  @try {

    // Forward to the original implementation.
    ((void (*)(id, SEL, NSEvent *))sendEventOriginalImp)(self, _cmd, theEvent);
  } @catch (NSException *exception) {
    [self reportException:exception];
  }
}

@end

#endif

@implementation MSCrashesCategory

+ (void)activateCategory {
#if TARGET_OS_OSX
  NSNumber *crashOnExceptions = [MS_USER_DEFAULTS objectForKey:kMSCrashOnExceptionsKey];
  if ([crashOnExceptions boolValue]) {
    [MSCrashesCategory swizzleReportException];
    [MSCrashesCategory swizzleSendEvent];
  }
#endif
}

#if TARGET_OS_OSX

+ (void)swizzleReportException {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    Class class = [NSApplication class];
    Method originalMethod = class_getInstanceMethod(class, @selector(reportException:));
    IMP swizzledImp = class_getMethodImplementation(class, @selector(ms_reportException:));
    reportExceptionOriginalImp = method_setImplementation(originalMethod, swizzledImp);
  });
}

+ (void)swizzleSendEvent {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    Class class = [NSApplication class];
    Method originalMethod = class_getInstanceMethod(class, @selector(reportException:));
    IMP swizzledImp = class_getMethodImplementation(class, @selector(ms_reportException:));
    sendEventOriginalImp = method_setImplementation(originalMethod, swizzledImp);
  });
}

#endif

@end