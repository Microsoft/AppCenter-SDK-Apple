/*
 * Copyright (c) Microsoft Corporation. All rights reserved.
 */

#import "SNMSonomaInternal.h"
#import "SNMAppleErrorLog.h"
#import "SNMCrashesCXXExceptionWrapperException.h"
#import "SNMCrashesHelper.h"
#import "SNMErrorLogFormatter.h"
#import "SNMCrashesPrivate.h"
#import "Sonoma+Internal.h"
#import <CrashReporter/CrashReporter.h>

/**
 *  Feature name.
 */
static NSString *const kSNMFeatureName = @"Crashes";
static NSString *const kSNMAnalyzerFilename = @"SNMCrashes.analyzer";

#pragma mark - Callbacks Setup

static SNMCrashesCallbacks snmCrashesCallbacks = {.context = NULL, .handleSignal = NULL};

/** Proxy implementation for PLCrashReporter to keep our interface stable while
 *  this can change.
 */
static void plcr_post_crash_callback(siginfo_t *info, ucontext_t *uap, void *context) {
  if (snmCrashesCallbacks.handleSignal != NULL) {
    snmCrashesCallbacks.handleSignal(context);
  }
}

static PLCrashReporterCallbacks plCrashCallbacks = {
    .version = 0, .context = NULL, .handleSignal = plcr_post_crash_callback};

/**
 * C++ Exception Handler
 */
static void uncaught_cxx_exception_handler(const SNMCrashesUncaughtCXXExceptionInfo *info) {
  // This relies on a LOT of sneaky internal knowledge of how PLCR works and
  // should not be considered a long-term solution.
  NSGetUncaughtExceptionHandler()([[SNMCrashesCXXExceptionWrapperException alloc] initWithCXXExceptionInfo:info]);
  abort();
}

@implementation SNMCrashes

@synthesize delegate = _delegate;
@synthesize logManger = _logManger;
@synthesize initializationDate = _initializationDate;

#pragma mark - Public Methods

+ (BOOL)isDebuggerAttached {
  // TODO actual implementation
  return NO;
}

+ (void)generateTestCrash {
  if ([[self sharedInstance] canBeUsed]) {
    if ([SNMEnvironmentHelper currentAppEnvironment] != SNMEnvironmentAppStore) {
      if ([self isDebuggerAttached]) {
        SNMLogWarning(
            @"[SNMCrashes] Error: The debugger is attached. The following crash cannot be detected by the SDK!");
      }

      __builtin_trap();
    }
  } else {
    SNMLogWarning(@"[SNMCrashes] WARNING: generateTestCrash was just called in an App Store environment. The call will "
                  @"be ignored");
  }
}

+ (BOOL)hasCrashedInLastSession {
  // TODO actual implementation

  return NO;
}

+ (void)setUserConfirmationHandler:(_Nullable SNMUserConfirmationHandler)userConfitmationHandler {
  // TODO actual implementation
}

+ (void)notifyWithUserConfirmation:(SNMUserConfirmation)userConfirmation {
  // TODO actual implementation
}

+ (SNMErrorReport *_Nullable)lastSessionCrashDetails {
  // TODO actual implementation

  return nil;
}

+ (void)setCrashesDelegate:(_Nullable id<SNMCrashesDelegate>)crashesDelegate {
  // TODO actual implementation
}

#pragma mark - Module initialization

- (instancetype)init {
  if ((self = [super init])) {
    _fileManager = [[NSFileManager alloc] init];
    _crashFiles = [[NSMutableArray alloc] init];
    _crashesDir = [SNMCrashesHelper crashesDir];
    _analyzerInProgressFile = [_crashesDir stringByAppendingPathComponent:kSNMAnalyzerFilename];
    _initializationDate = [NSDate new];
  }
  return self;
}

#pragma mark - SNMFeatureAbstract

- (void)setEnabled:(BOOL)isEnabled {
  //TODO do something here?!
//  isEnabled ? [self.logManger addListener:self.sessionTracker] : [self.logManger removeListener:self.sessionTracker];
  [super setEnabled:isEnabled];
}

#pragma mark - SNMFeatureInternal

+ (instancetype)sharedInstance {
  static id sharedInstance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedInstance = [[self alloc] init];
  });
  return sharedInstance;
}

- (void)startFeature {
  [super startFeature];

  SNMLogVerbose(@"[SNMCrashes] VERBOSE: Started crash module");

  [self configureCrashReporter];

  if ([self.plCrashReporter hasPendingCrashReport]) {
    [self persistLatestCrashReport];
  }

  _crashFiles = [self persistedCrashReports];
  if (self.crashFiles.count > 0) {
    [self startDelayedCrashProcessing];
  }
}

- (NSString *)featureName {
  return kSNMFeatureName;
}

#pragma mark - Crash reporter configuration

- (void)configureCrashReporter {
  PLCrashReporterSignalHandlerType signalHandlerType = PLCrashReporterSignalHandlerTypeBSD;
  PLCrashReporterSymbolicationStrategy symbolicationStrategy = PLCrashReporterSymbolicationStrategyNone;
  SNMPLCrashReporterConfig *config = [[SNMPLCrashReporterConfig alloc] initWithSignalHandlerType:signalHandlerType
                                                                           symbolicationStrategy:symbolicationStrategy];
  _plCrashReporter = [[SNMPLCrashReporter alloc] initWithConfiguration:config];

  /**
   The actual signal and mach handlers are only registered when invoking
   `enableCrashReporterAndReturnError`, so it is safe enough to only disable
   the following part when a debugger is attached no matter which signal
   handler type is set.
   */
  if ([SNMCrashesHelper isDebuggerAttached]) {
    SNMLogWarning(@"[SNMCrashes] WARNING: Detecting crashes is NOT "
                  @"enabled due to running the app with a debugger "
                  @"attached.");
  } else {

    /**
     * Multiple exception handlers can be set, but we can only query the top
     * level error handler (uncaught exception handler). To check if
     * PLCrashReporter's error handler is successfully added, we compare the top
     * level one that is set before and the one after PLCrashReporter sets up
     * its own. With delayed processing we can then check if another error
     * handler was set up afterwards and can show a debug warning log message,
     * that the dev has to make sure the "newer" error handler doesn't exit the
     * process itself, because then all subsequent handlers would never be
     * invoked. Note: ANY error handler setup BEFORE SDK initialization
     * will not be processed!
     */
    NSUncaughtExceptionHandler *initialHandler = NSGetUncaughtExceptionHandler();

    NSError *error = NULL;
    [self.plCrashReporter setCrashCallbacks:&plCrashCallbacks];
    if (![self.plCrashReporter enableCrashReporterAndReturnError:&error])
      SNMLogError(@"[SNMCrashes] ERROR: Could not enable crash reporter: %@", [error localizedDescription]);
    NSUncaughtExceptionHandler *currentHandler = NSGetUncaughtExceptionHandler();
    if (currentHandler && currentHandler != initialHandler) {
      self.exceptionHandler = currentHandler;

      SNMLogDebug(@"[SNMCrashes] INFO: Exception handler successfully initialized.");
    } else {
      SNMLogError(@"[SNMCrashes] ERROR: Exception handler could not be "
                  @"set. Make sure there is no other exception "
                  @"handler set up!");
    }
    [SNMCrashesUncaughtCXXExceptionHandlerManager addCXXExceptionHandler:uncaught_cxx_exception_handler];
  }
}

#pragma mark - Crash processing

- (void)startDelayedCrashProcessing {
  [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(startCrashProcessing) object:nil];
  [self performSelector:@selector(startCrashProcessing) withObject:nil afterDelay:0.5];
}

- (void)startCrashProcessing {
  if (![SNMCrashesHelper isAppExtension] &&
      [[UIApplication sharedApplication] applicationState] != UIApplicationStateActive) {
    return;
  }

  SNMLogDebug(@"[SNMCrashes] INFO: Start delayed CrashManager processing");

  // Was our own exception handler successfully added?
  if (self.exceptionHandler) {

    // Get the current top level error handler
    NSUncaughtExceptionHandler *currentHandler = NSGetUncaughtExceptionHandler();

    /* If the top level error handler differs from our own, then at least
     * another one was added.
     * This could cause exception crashes not to be reported to AppHub. See
     * log message for details.
     */
    if (self.exceptionHandler != currentHandler) {
      SNMLogWarning(@"[SNMCrashes] WARNING: Another exception handler was "
                    @"added. If this invokes any kind exit() after processing "
                    @"the exception, which causes any subsequent error "
                    @"handler not to be invoked, these crashes will NOT be "
                    @"reported to AppHub!");
    }
  }
  if (!self.sendingInProgress && self.crashFiles.count > 0) {

    // TODO: Send and clean next crash report
    SNMPLCrashReport *report = [self nextCrashReport];
    SNMLogVerbose(@"[SNMCrashes] VERBOSE: Crash report found: %@ ", report.debugDescription);
  }
}

- (SNMPLCrashReport *)nextCrashReport {
  NSError *error = NULL;
  SNMPLCrashReport *report;

  NSArray *tempCrashesFiles = [NSArray arrayWithArray:self.crashFiles];
  for (NSString *filePath in tempCrashesFiles) {
    // we start sending always with the oldest pending one
    NSData *crashFileData = [NSData dataWithContentsOfFile:filePath];
    if ([crashFileData length] > 0) {
      report = [[SNMPLCrashReport alloc] initWithData:crashFileData error:&error];
      SNMAppleErrorLog *log = [SNMErrorLogFormatter errorLogFromCrashReport:report];
      [self.delegate feature:self didCreateLog:log withPriority:SNMPriorityHigh]; //TODO work on this part!!!
      [self deleteCrashReportWithFilePath:filePath];
      [self.crashFiles removeObject:filePath];
    }
  }
  return report;
}

#pragma mark - Helper

- (void)deleteCrashReportWithFilePath:(NSString *)filePath {
  NSError *error = NULL;
  if ([self.fileManager fileExistsAtPath:filePath]) {
    [self.fileManager removeItemAtPath:filePath error:&error];
  }
}

- (void)persistLatestCrashReport {
  NSError *error = NULL;

  // Check if the next call ran successfully the last time
  if (![self.fileManager fileExistsAtPath:self.analyzerInProgressFile]) {

    // Mark the start of the routine
    [self createAnalyzerFile];

    // Try loading the crash report
    NSData *crashData =
        [[NSData alloc] initWithData:[self.plCrashReporter loadPendingCrashReportDataAndReturnError:&error]];
    NSString *cacheFilename = [NSString stringWithFormat:@"%.0f", [NSDate timeIntervalSinceReferenceDate]];

    if (crashData == nil) {
      SNMLogError(@"[SNMCrashes] ERROR: Could not load crash report: %@", error);
    } else {

      // Get data of PLCrashReport and write it to SDK directory
      SNMPLCrashReport *report = [[SNMPLCrashReport alloc] initWithData:crashData error:&error];
      if (report) {
        [crashData writeToFile:[self.crashesDir stringByAppendingPathComponent:cacheFilename] atomically:YES];
      } else {
        SNMLogWarning(@"[SNMCrashes] WARNING: Could not parse crash report");
      }
    }

    // Purge the report mark at the end of the routine
    [self removeAnalyzerFile];
  }

  [self.plCrashReporter purgePendingCrashReport];
}

- (NSMutableArray *)persistedCrashReports {
  NSMutableArray *persitedCrashReports = [NSMutableArray new];
  if ([self.fileManager fileExistsAtPath:self.crashesDir]) {
    NSError *error;
    NSArray *dirArray = [self.fileManager contentsOfDirectoryAtPath:self.crashesDir error:&error];

    for (NSString *file in dirArray) {
      NSString *filePath = [self.crashesDir stringByAppendingPathComponent:file];
      NSDictionary *fileAttributes = [self.fileManager attributesOfItemAtPath:filePath error:&error];

      if ([[fileAttributes objectForKey:NSFileType] isEqualToString:NSFileTypeRegular] &&
          [[fileAttributes objectForKey:NSFileSize] intValue] > 0 && ![file hasSuffix:@".DS_Store"] &&
          ![file hasSuffix:@".analyzer"] && ![file hasSuffix:@".plist"] && ![file hasSuffix:@".data"] &&
          ![file hasSuffix:@".meta"] && ![file hasSuffix:@".desc"]) {
        [persitedCrashReports addObject:filePath];
      }
    }
  }
  return persitedCrashReports;
}

- (void)removeAnalyzerFile {
  if ([self.fileManager fileExistsAtPath:self.analyzerInProgressFile]) {
    NSError *error = nil;
    if (![self.fileManager removeItemAtPath:self.analyzerInProgressFile error:&error]) {
      SNMLogError(@"[SNMCrashes] ERROR: Couldn't remove analzer file at %@: ", self.analyzerInProgressFile);
    }
  }
}

- (void)createAnalyzerFile {
  if (![self.fileManager fileExistsAtPath:self.analyzerInProgressFile]) {
    [self.fileManager createFileAtPath:self.analyzerInProgressFile contents:nil attributes:nil];
  }
}

@end
