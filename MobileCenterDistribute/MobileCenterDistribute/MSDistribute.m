#import <Foundation/Foundation.h>
#import <SafariServices/SafariServices.h>

#import "MSDistribute.h"
#import "MSDistributeDelegate.h"
#import "MSDistributeInternal.h"
#import "MSDistributePrivate.h"
#import "MSDistributeUtil.h"
#import "MSErrorDetails.h"
#import "MSKeychainUtil.h"
#import "MSLogger.h"
#import "MSMobileCenterInternal.h"
#import "MSServiceAbstractProtected.h"

/**
 * Service storage key name.
 */
static NSString *const kMSServiceName = @"Distribute";

/**
 * The group ID for storage.
 */
static NSString *const kMSGroupID = @"Distribute";

#pragma mark - URL constants

/**
 * The API path for update token request.
 */
static NSString *const kMSUpdateTokenApiPathFormat = @"/apps/%@/update-setup";

#pragma mark - Error constants

static NSString *const kMSUpdateTokenURLInvalidErrorDescFormat = @"Invalid update token URL:%@";

@implementation MSDistribute

@synthesize channelConfiguration = _channelConfiguration;

#pragma mark - Service initialization

- (instancetype)init {
  if ((self = [super init])) {
    _apiUrl = kMSDefaultApiUrl;
    _installUrl = kMSDefaultInstallUrl;
    _channelConfiguration = [[MSChannelConfiguration alloc] initDefaultConfigurationWithGroupID:[self groupID]];

    /*
     * Delete update token if an application has been uninstalled and try to get a new one from server.
     * For iOS version < 10.3, keychain data won't be automatically deleted by uninstall
     * so we should detect it and clean up keychain data when Distribute service gets initialized.
     */
    NSNumber *flag = [MS_USER_DEFAULTS objectForKey:kMSSDKHasLaunchedWithDistribute];
    if (!flag) {
      MSLogInfo([MSDistribute logTag], @"Delete update token if exists.");
      [MSKeychainUtil deleteStringForKey:kMSUpdateTokenKey];
      [MS_USER_DEFAULTS setObject:@(1) forKey:kMSSDKHasLaunchedWithDistribute];
    }
  }
  return self;
}

#pragma mark - MSServiceInternal

+ (instancetype)sharedInstance {
  static id sharedInstance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedInstance = [[self alloc] init];
  });
  return sharedInstance;
}

+ (NSString *)serviceName {
  return kMSServiceName;
}

+ (NSString *)logTag {
  return @"MobileCenterDistribute";
}

- (NSString *)groupID {
  return kMSGroupID;
}

#pragma mark - MSServiceAbstract

- (void)applyEnabledState:(BOOL)isEnabled {
  [super applyEnabledState:isEnabled];

  // Enabling
  if (isEnabled) {
    MSLogInfo([MSDistribute logTag], @"Distribute service has been enabled.");
    [self startUpdate];
  } else {
    [self dismissEmbeddedSafari];
    [MS_USER_DEFAULTS removeObjectForKey:kMSUpdateTokenRequestIdKey];
    [MS_USER_DEFAULTS removeObjectForKey:kMSMandatoryReleaseKey];
    MSLogInfo([MSDistribute logTag], @"Distribute service has been disabled.");
  }
}

- (void)startWithLogManager:(id<MSLogManager>)logManager appSecret:(NSString *)appSecret {
  [super startWithLogManager:logManager appSecret:appSecret];
  MSLogVerbose([MSDistribute logTag], @"Started Distribute service.");
}

#pragma mark - Public

+ (void)setApiUrl:(NSString *)apiUrl {
  [[self sharedInstance] setApiUrl:apiUrl];
}

+ (void)setInstallUrl:(NSString *)installUrl {
  [[self sharedInstance] setInstallUrl:installUrl];
}

+ (void)openUrl:(NSURL *)url {
  [[self sharedInstance] openUrl:url];
}

+ (void)notifyUserUpdateAction:(MSUserUpdateAction)action {
  [[self sharedInstance] notifyUserUpdateAction:action];
}

+ (void)setDelegate:(id<MSDistributeDelegate>)delegate {
  [[self sharedInstance] setDelegate:delegate];
}

#pragma mark - Private

- (void)startUpdate {
  if ([self isEnabled]) {
    self.releaseDetails = nil;
    NSString *updateToken = [MSKeychainUtil stringForKey:kMSUpdateTokenKey];
    NSString *releaseHash = MSPackageHash();
    if (releaseHash) {
      if (updateToken) {
        [self checkLatestRelease:updateToken releaseHash:releaseHash];
      } else {
        [self requestUpdateToken:releaseHash];
      }
    } else {
      MSLogError([MSDistribute logTag], @"Failed to get a release hash.");
    }
  }
}
- (void)notifyUserUpdateAction:(MSUserUpdateAction)action {
  switch (action) {
  case MSUserUpdateActionUpdate:
#if TARGET_IPHONE_SIMULATOR

    /*
     * iOS simulator doesn't support "itms-services" scheme, simulator will consider the scheme
     * as an invalid address. Skip download process if the application is running on simulator.
     */
    MSLogWarning([MSDistribute logTag], @"Couldn't download a new release on simulator.");
#else
    if ([self isEnabled]) {
      MSLogDebug([MSDistribute logTag], @"Start download and update the release.");
      [self startDownload:self.releaseDetails];
    } else {
      MSLogDebug([MSDistribute logTag], @"Distribute was disabled.");
      [self showDistributeDisabledAlert];
    }
#endif
    break;
  case MSUserUpdateActionPostpone:
    MSLogDebug([MSDistribute logTag], @"Postpone the update for now.");
    break;
  }
}

- (void)requestUpdateToken:(NSString *)releaseHash {

  // Check if it's okay to check for updates.
  if ([self checkForUpdatesAllowed]) {

    // Check if the device has internet connection to get update token.
    if ([MS_Reachability reachabilityForInternetConnection].currentReachabilityStatus == NotReachable) {
      MSLogWarning(
          [MSDistribute logTag],
          @"The device lost its internet connection. The SDK will retry to get an update token in the next launch.");
      return;
    }
    NSURL *url;
    MSLogInfo([MSDistribute logTag], @"Request Distribute update token.");

    // Most failures here require an app update. Thus, it will be retried only on next App instance.
    url = [self buildTokenRequestURLWithAppSecret:self.appSecret releaseHash:releaseHash];
    if (url) {

/*
 * iOS 9+ only, check for `SFSafariViewController` availability. `SafariServices` framework MUST be weakly linked.
 * We can't use `NSClassFromString` here to avoid the warning.
 * It doesn't detect the class correctly unless the application explicitly imports the related framework.
 */
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
      Class clazz = [SFSafariViewController class];
#pragma clang diagnostic pop
      if (clazz) {

        // Manipulate App UI on the main queue.
        dispatch_async(dispatch_get_main_queue(), ^{
          [self openURLInEmbeddedSafari:url fromClass:clazz];
        });
      } else {

        // iOS 8.x.
        [self openURLInSafariApp:url];
      }
    }
  } else {

    // Log a message to notify the user why the SDK didn't check for updates.
    MSLogDebug(
        [MSDistribute logTag],
        @"Distribute won't try to obtain an update token because of one of the following reasons: 1. A debugger is"
         "attached. 2. You are running the debug configuration. 3. The app is running in a non-adhoc environment."
         "Detach the debugger and restart the app and/or run the app with the release configuration to enable the"
         "feature.");
  }
}

- (void)checkLatestRelease:(NSString *)updateToken releaseHash:(NSString *)releaseHash {

  // Check if it's okay to check for updates.
  if ([self checkForUpdatesAllowed]) {

    // Use persisted mandatory update while network is down.
    if ([MS_Reachability reachabilityForInternetConnection].currentReachabilityStatus == NotReachable) {
      MSReleaseDetails *details =
          [[MSReleaseDetails alloc] initWithDictionary:[MS_USER_DEFAULTS objectForKey:kMSMandatoryReleaseKey]];
      if (!details || ![self handleUpdate:details]) {

        // This release is no more a candidate for update, deleting it.
        [MS_USER_DEFAULTS removeObjectForKey:kMSMandatoryReleaseKey];
      }
    }

    // Check if sender is still waiting for a response of the previous request.
    if (self.sender == nil) {
      self.sender = [[MSDistributeSender alloc] initWithBaseUrl:self.apiUrl
                                                      appSecret:self.appSecret
                                                    updateToken:updateToken
                                                   queryStrings:@{kMSURLQueryReleaseHashKey : releaseHash}];
      [self.sender
                  sendAsync:nil
          completionHandler:^(__attribute__((unused)) NSString *callId, NSUInteger statusCode, NSData *data,
                              __attribute__((unused)) NSError *error) {

            // Release sender instance.
            self.sender = nil;

            // Ignore the response if the service is disabled.
            if (![self isEnabled]) {
              return;
            }

            // Error instance for JSON parsing.
            NSError *jsonError = nil;

            // Success.
            if (statusCode == MSHTTPCodesNo200OK) {
              id dictionary =
                  [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
              MSReleaseDetails *details = [[MSReleaseDetails alloc] initWithDictionary:dictionary];
              if (!details) {
                MSLogError([MSDistribute logTag], @"Couldn't parse response payload.");
              } else {
                NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dictionary
                                                                   options:NSJSONWritingPrettyPrinted
                                                                     error:&jsonError];
                NSString *jsonString = nil;
                if (!jsonData || jsonError) {
                  jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                } else {

                  // NSJSONSerialization escapes paths by default so we replace them.
                  jsonString = [[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]
                      stringByReplacingOccurrencesOfString:@"\\/"
                                                withString:@"/"];
                }
                MSLogDebug([MSDistribute logTag], @"Received a response of update request:\n%@", jsonString);

                /*
                 * Handle this update.
                 *
                 * NOTE: There is one glitch when this release is the same than the currently displayed mandatory
                 * release. In this case the current UI will be dismissed then redisplayed with the same UI content.
                 * This is an edge case since it's only happening if there was no network at app start then network
                 * came back along with the same mandatory release from the server. In addition to that and even though
                 * the releases are the same, the URL links gerenarted by the server will be different.
                 * Thus, there is the overhead of updating the currently displayed download action with the new URL.
                 * In the end fixing this edge case adds too much complexity for no worthy advantages,
                 * keeping it as it is for now.
                 */
                [self handleUpdate:details];
              }
            }

            // Failure.
            else {
              MSLogDebug([MSDistribute logTag], @"Failed to get an update response, status code:%lu",
                         (unsigned long)statusCode);
              NSString *jsonString = nil;
              id dictionary =
                  [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&jsonError];

              // Failure can deliver non-JSON format of payload.
              if (!jsonError) {
                NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dictionary
                                                                   options:NSJSONWritingPrettyPrinted
                                                                     error:&jsonError];
                if (jsonData && !jsonError) {

                  // NSJSONSerialization escapes paths by default so we replace them.
                  jsonString = [[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]
                      stringByReplacingOccurrencesOfString:@"\\/"
                                                withString:@"/"];
                }
              }

              // Check the status code to clean up Distribute data for an unrecoverable error.
              if (![MSSenderUtil isRecoverableError:statusCode]) {

                // Deserialize payload to check if it contains error details.
                MSErrorDetails *details = nil;
                if (dictionary) {
                  details = [[MSErrorDetails alloc] initWithDictionary:dictionary];
                }

                // If the response payload is MSErrorDetails, consider it as a recoverable error.
                if (!details || ![kMSErrorCodeNoReleasesForUser isEqualToString:details.code]) {
                  [MSKeychainUtil deleteStringForKey:kMSUpdateTokenKey];
                  [MS_USER_DEFAULTS removeObjectForKey:kMSSDKHasLaunchedWithDistribute];
                  [MS_USER_DEFAULTS removeObjectForKey:kMSUpdateTokenRequestIdKey];
                }
              }
              if (!jsonString) {
                jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
              }
              MSLogError([MSDistribute logTag], @"Response:\n%@", jsonString ? jsonString : @"No payload");
            }
          }];
    }
  } else {

    // Log a message to notify the user why the SDK didn't check for updates.
    MSLogDebug(
        [MSDistribute logTag],
        @"Distribute won't check if a new release is available because of one of the following reasons: 1. A debugger "
         "is attached. 2. You are running the debug configuration. 3. The app is running in a non-adhoc environment."
         "Detach the debugger and restart the app and/or run the app with the release configuration to enable the"
         "feature.");
  }
}

#pragma mark - Private

- (BOOL)checkURLSchemeRegistered:(NSString *)urlScheme {
  NSArray *schemes;
  NSArray *types = [MS_APP_MAIN_BUNDLE objectForInfoDictionaryKey:@"CFBundleURLTypes"];
  for (NSDictionary *urlType in types) {
    schemes = urlType[@"CFBundleURLSchemes"];
    for (NSString *scheme in schemes) {
      if ([scheme isEqualToString:urlScheme]) {
        return YES;
      }
    }
  }
  return NO;
}

- (NSURL *)buildTokenRequestURLWithAppSecret:(NSString *)appSecret releaseHash:(NSString *)releaseHash {

  // Create the request ID string.
  NSString *requestId = MS_UUID_STRING;

  // Compute URL path string.
  NSString *urlPath = [NSString stringWithFormat:kMSUpdateTokenApiPathFormat, appSecret];

  // Build URL string.
  NSString *urlString = [self.installUrl stringByAppendingString:urlPath];
  NSURLComponents *components = [NSURLComponents componentsWithString:urlString];

  // Check URL validity so far.
  if (!components) {
    MSLogError([MSDistribute logTag], kMSUpdateTokenURLInvalidErrorDescFormat, urlString);
    return nil;
  }

  // Check custom scheme is registered.
  NSString *scheme = [NSString stringWithFormat:kMSDefaultCustomSchemeFormat, appSecret];
  if (![self checkURLSchemeRegistered:scheme]) {
    MSLogError([MSDistribute logTag], @"Custom URL scheme for Distribute not found.");
    return nil;
  }

  // Set URL query parameters.
  NSMutableArray *items = [NSMutableArray array];
  [items addObject:[NSURLQueryItem queryItemWithName:kMSURLQueryReleaseHashKey value:releaseHash]];
  [items addObject:[NSURLQueryItem queryItemWithName:kMSURLQueryRedirectIdKey value:scheme]];
  [items addObject:[NSURLQueryItem queryItemWithName:kMSURLQueryRequestIdKey value:requestId]];
  [items addObject:[NSURLQueryItem queryItemWithName:kMSURLQueryPlatformKey value:kMSURLQueryPlatformValue]];
  components.queryItems = items;

  // Check URL validity.
  if (components.URL) {

    // Persist the request ID.
    [MS_USER_DEFAULTS setObject:requestId forKey:kMSUpdateTokenRequestIdKey];
  } else {
    MSLogError([MSDistribute logTag], kMSUpdateTokenURLInvalidErrorDescFormat, components);
    return nil;
  }
  return components.URL;
}

- (void)openURLInEmbeddedSafari:(NSURL *)url fromClass:(Class)clazz {
  MSLogDebug([MSDistribute logTag], @"Using SFSafariViewController to open URL: %@", url);

  // Init safari controller with the install URL.
  id safari = [[clazz alloc] initWithURL:url];

  // Create an empty window + viewController to host the Safari UI.
  self.safariHostingViewController = [[UIViewController alloc] init];
  UIWindow *window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  window.rootViewController = self.safariHostingViewController;

  // Place it at the highest level within the stack.
  window.windowLevel = +CGFLOAT_MAX;

  // Run it.
  [window makeKeyAndVisible];
  [self.safariHostingViewController presentViewController:safari animated:YES completion:nil];
}

- (void)dismissEmbeddedSafari {
  __weak typeof(self) weakSelf = self;
  dispatch_async(dispatch_get_main_queue(), ^{
    typeof(self) strongSelf = weakSelf;
    if (strongSelf && strongSelf.safariHostingViewController &&
        !strongSelf.safariHostingViewController.isBeingDismissed) {
      [strongSelf.safariHostingViewController dismissViewControllerAnimated:YES completion:nil];
    }
  });
}

- (void)openURLInSafariApp:(NSURL *)url {
  MSLogDebug([MSDistribute logTag], @"Using Safari browser to open URL: %@", url);
  [MSUtility sharedAppOpenUrl:url options:@{} completionHandler:nil];
}

- (BOOL)handleUpdate:(MSReleaseDetails *)details {

  // Step 1. Validate release details.
  if (!details || ![details isValid]) {
    MSLogError([MSDistribute logTag], @"Received invalid release details.");
    return NO;
  }

  // Step 2. Check status of the release. TODO: This will be deprecated soon.
  if (![details.status isEqualToString:@"available"]) {
    MSLogError([MSDistribute logTag], @"The new release is not available, skip update.");
    return NO;
  }

  // Step 3. Check min OS version.
  if ([MS_DEVICE.systemVersion compare:details.minOs options:NSNumericSearch] == NSOrderedAscending) {
    MSLogDebug([MSDistribute logTag], @"The new release doesn't support this iOS version: %@, skip update.",
               MS_DEVICE.systemVersion);
    return NO;
  }

  // Step 4. Check version/hash to identify a newer version.
  if (![self isNewerVersion:details]) {
    MSLogDebug([MSDistribute logTag], @"The application is already up-to-date.");
    return NO;
  }

  // Step 5. Persist mandatory update to cover offline scenario.
  if (details.mandatoryUpdate) {

    // Persist this mandatory update now.
    [MS_USER_DEFAULTS setObject:[details serializeToDictionary] forKey:kMSMandatoryReleaseKey];
  } else {

    // Clean up mandatory release cache.
    [MS_USER_DEFAULTS removeObjectForKey:kMSMandatoryReleaseKey];
  }

  // Step 6. Call the delegate and process update based on selection.
  if (!self.releaseDetails) {
    self.releaseDetails = details;
    id<MSDistributeDelegate> strongDelegate = self.delegate;
    if (strongDelegate && [strongDelegate respondsToSelector:@selector(onNewUpdateAvailable:)]) {

      dispatch_async(dispatch_get_main_queue(), ^{
        BOOL customized = [strongDelegate onNewUpdateAvailable:details];
        MSLogDebug([MSDistribute logTag], @"onNewUpdateAvailable delegate returned %@.", customized ? @"YES" : @"NO");
        if (!customized) {
          [self showConfirmationAlert:details];
        }
      });
    } else {
      [self showConfirmationAlert:details];
    }
  }
  return YES;
}

- (BOOL)checkForUpdatesAllowed {

  // Check if we are not in AppStore or TestFlight environments.
  BOOL environmentOkay = [MSUtility currentAppEnvironment] == MSEnvironmentOther;

  // Check if a debugger is attached.
  BOOL noDebuggerAttached = ![MSMobileCenter isDebuggerAttached];
  return environmentOkay && noDebuggerAttached;
}

- (BOOL)isNewerVersion:(MSReleaseDetails *)details {
  return MSCompareCurrentReleaseWithRelease(details) == NSOrderedAscending;
}

- (void)showConfirmationAlert:(MSReleaseDetails *)details {

  // Displaying alert dialog. Running on main thread.
  dispatch_async(dispatch_get_main_queue(), ^{

    // Init the alert controller.
    NSString *releaseNotes =
        details.releaseNotes ? details.releaseNotes : MSDistributeLocalizedString(@"No release notes");
    MSAlertController *alertController =
        [MSAlertController alertControllerWithTitle:MSDistributeLocalizedString(@"Update available")
                                            message:releaseNotes];
    if (!details.mandatoryUpdate) {

      // Add a "Postpone"-Button
      [alertController addDefaultActionWithTitle:MSDistributeLocalizedString(@"Postpone")
                                         handler:^(__attribute__((unused)) UIAlertAction *action) {
                                           [self notifyUserUpdateAction:MSUserUpdateActionPostpone];
                                         }];
    }

    // Add a "Update"-Button
    [alertController addCancelActionWithTitle:MSDistributeLocalizedString(@"Update")
                                      handler:^(__attribute__((unused)) UIAlertAction *action) {
                                        [self notifyUserUpdateAction:MSUserUpdateActionUpdate];
                                      }];

    /*
     * Show the alert controller.
     * It will replace any previous release alert. This happens when the network was down so the persisted release
     * was displayed but the network came back with a fresh release.
     */
    MSLogDebug([MSDistribute logTag], @"Show update dialog.");
    [alertController replaceAlert:self.updateAlertController];
    self.updateAlertController = alertController;
  });
}

- (void)showDistributeDisabledAlert {
  dispatch_async(dispatch_get_main_queue(), ^{
    MSAlertController *alertController =
        [MSAlertController alertControllerWithTitle:MSDistributeLocalizedString(@"In-app-updates are disabled.")
                                            message:nil];
    [alertController addCancelActionWithTitle:MSDistributeLocalizedString(@"Close") handler:nil];
    [alertController show];
  });
}

- (void)startDownload:(MSReleaseDetails *)details {
  [MSUtility sharedAppOpenUrl:details.installUrl
      options:@{}
      completionHandler:^(MSOpenURLState state) {
        switch (state) {
        case MSOpenURLStateSucceed:
          MSLogDebug([MSDistribute logTag], @"Start updating the application.");
          break;
        case MSOpenURLStateFailed:
          MSLogError([MSDistribute logTag], @"System couldn't open the URL. Aborting update.");
          return;
        case MSOpenURLStateUnknown:

          /*
           * FIXME: We've observed a behavior in iOS 10+ that openURL and openURL:options:completionHandler don't say
           * the operation is succeeded even though it successfully opens the URL.
           * Log the result of openURL and openURL:options:completionHandler and keep moving forward for update.
           */
          MSLogWarning([MSDistribute logTag], @"System returned NO for update but processing.");
          break;
        }

        /*
         * We've seen the behavior on iOS 8.x devices in HockeyApp that it doesn't download until the application
         * goes in background by pressing home button. Simply exit the app to start the update process.
         * For iOS version >= 9.0, we still need to exit the app if it is a mandatory update.
         */
        if ((floor(NSFoundationVersionNumber) < NSFoundationVersionNumber_iOS_9_0) || details.mandatoryUpdate) {
          [self closeApp];
        }
      }];
}

- (void)closeApp __attribute__((noreturn)) {
  exit(0);
}

- (void)openUrl:(NSURL *)url {
  if ([self isEnabled]) {

    // If the request is not for Mobile Center Distribute, ignore.
    if (![[url scheme] isEqualToString:[NSString stringWithFormat:kMSDefaultCustomSchemeFormat, self.appSecret]]) {
      return;
    }

    // Parse query parameters
    NSString *requestedId = [MS_USER_DEFAULTS objectForKey:kMSUpdateTokenRequestIdKey];
    NSString *queryRequestId = nil;
    NSString *queryUpdateToken = nil;
    NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];

    // Read mandatory parameters from URL query string.
    for (NSURLQueryItem *item in components.queryItems) {
      if ([item.name isEqualToString:kMSURLQueryRequestIdKey]) {
        queryRequestId = item.value;
      } else if ([item.name isEqualToString:kMSURLQueryUpdateTokenKey]) {
        queryUpdateToken = item.value;
      }
    }

    // If the request ID doesn't match, ignore.
    if (!(requestedId && queryRequestId && [requestedId isEqualToString:queryRequestId])) {
      return;
    }

    // Dismiss the embedded Safari view.
    [self dismissEmbeddedSafari];

    // Delete stored request ID
    [MS_USER_DEFAULTS removeObjectForKey:kMSUpdateTokenRequestIdKey];

    // Store update token
    if (queryUpdateToken) {
      MSLogDebug([MSDistribute logTag],
                 @"Update token has been successfully retrieved. Store the token to secure storage.");

      // Storing the update token to keychain since the update token is considered as a sensitive information.
      [MSKeychainUtil storeString:queryUpdateToken forKey:kMSUpdateTokenKey];
      [self checkLatestRelease:queryUpdateToken releaseHash:MSPackageHash()];
    }
  } else {
    MSLogDebug([MSDistribute logTag], @"Distribute service has been disabled, ignore request.");
  }
}

@end
