// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "MSAuthTokenContext.h"
#import "MSAuthTokenContextDelegate.h"
#import "MSAuthTokenContextPrivate.h"
#import "MSUserInformation.h"

/**
 * Singleton.
 */
static MSAuthTokenContext *sharedInstance;
static dispatch_once_t onceToken;

@interface MSAuthTokenContext ()

/**
 * Cached authorization token.
 */
@property(nullable, atomic, copy) NSString *authTokenCache;

/**
 * Collection of channel delegates.
 */
@property(nonatomic) NSHashTable<id<MSAuthTokenContextDelegate>> *delegates;

/**
 * YES if the current token should be reset.
 */
@property() BOOL resetAuthTokenRequired;

@end

@implementation MSAuthTokenContext

- (instancetype)init {
  self = [super init];
  if (self) {
    _delegates = [NSHashTable new];
    _resetAuthTokenRequired = YES;
  }
  return self;
}

+ (instancetype)sharedInstance {
  dispatch_once(&onceToken, ^{
    if (sharedInstance == nil) {
      sharedInstance = [MSAuthTokenContext new];
    }
  });
  return sharedInstance;
}

+ (void)resetSharedInstance {
  onceToken = 0;
  sharedInstance = nil;
}

- (void)setAuthToken:(nullable NSString *)authToken withAccountId:(nullable NSString *)accountId expiresOn:(nullable NSDate *)expiresOn {
  NSArray *synchronizedDelegates;
  BOOL isNewUser = NO;
  @synchronized(self) {

    // If a nil authToken is passed with non-nil paarmeters, reset them.
    if (!authToken) {
      accountId = nil;
      expiresOn = nil;
    }
    NSMutableArray<MSAuthTokenInfo *> *authTokenHistory = [[self authTokenHistory] mutableCopy];
    MSAuthTokenInfo *lastEntry = authTokenHistory.lastObject;

    // If new token doesn't differ from the last token of array - no need to add it to array.
    if (lastEntry && (authToken == lastEntry.authToken || [authToken isEqualToString:(NSString * __nonnull) lastEntry.authToken])) {
      return;
    }
    isNewUser = !lastEntry || !(accountId == lastEntry.accountId || [accountId isEqualToString:(NSString * __nonnull) lastEntry.accountId]);
    NSDate *newTokenStartDate = [NSDate date];

    // If there is a gap between tokens.
    if (lastEntry.expiresOn && [newTokenStartDate compare:(NSDate * __nonnull) lastEntry.expiresOn] == NSOrderedDescending) {

      // If the account is the same or becomes anonymous.
      if (!isNewUser || authToken == nil) {

        // Apply the new token to this time.
        newTokenStartDate = lastEntry.expiresOn;
      } else {

        // If it's not the same account treat the gap as anonymous.
        MSAuthTokenInfo *newAuthToken = [[MSAuthTokenInfo alloc] initWithAuthToken:nil
                                                                         accountId:nil
                                                                         startTime:lastEntry.expiresOn
                                                                         expiresOn:newTokenStartDate];
        [authTokenHistory addObject:newAuthToken];
      }
    }
    MSAuthTokenInfo *newAuthToken = [[MSAuthTokenInfo alloc] initWithAuthToken:authToken
                                                                     accountId:accountId
                                                                     startTime:newTokenStartDate
                                                                     expiresOn:expiresOn];
    [authTokenHistory addObject:newAuthToken];

    // Cap array size at max available size const (deleting from beginning).
    if ([authTokenHistory count] > kMSMaxAuthTokenArraySize) {
      [authTokenHistory removeObjectsInRange:(NSRange){0, [authTokenHistory count] - kMSMaxAuthTokenArraySize}];
      MSLogDebug([MSAppCenter logTag], @"Size of the token history is exceeded. The oldest token has been removed.");
    }

    // Don't invoke the delegate while locking; it might be locking too and deadlock ourselves.
    synchronizedDelegates = [self.delegates allObjects];

    // Save new array.
    [self setAuthTokenHistory:authTokenHistory];
  }
  for (id<MSAuthTokenContextDelegate> delegate in synchronizedDelegates) {
    if ([delegate respondsToSelector:@selector(authTokenContext:didUpdateAuthToken:)]) {
      [delegate authTokenContext:self didUpdateAuthToken:authToken];
    }
    if (isNewUser && [delegate respondsToSelector:@selector(authTokenContext:didUpdateUserInformation:)]) {
      MSUserInformation *userInfo = nil;
      if (accountId) {
        userInfo = [[MSUserInformation alloc] initWithAccountId:(NSString *)accountId];
      }
      [delegate authTokenContext:self didUpdateUserInformation:userInfo];
    }
  }
}

- (void)addDelegate:(id<MSAuthTokenContextDelegate>)delegate {
  @synchronized(self) {
    [self.delegates addObject:delegate];
  }
}

- (void)removeDelegate:(id<MSAuthTokenContextDelegate>)delegate {
  @synchronized(self) {
    [self.delegates removeObject:delegate];
  }
}

- (nullable NSString *)authToken {
  NSArray<MSAuthTokenInfo *> *authTokenHistory = [self authTokenHistory];
  MSAuthTokenInfo *latestAuthTokenInfo = authTokenHistory.lastObject;
  return latestAuthTokenInfo.authToken;
}

- (nullable NSString *)accountId {
  NSArray<MSAuthTokenInfo *> *authTokenHistory = [self authTokenHistory];
  MSAuthTokenInfo *latestAuthTokenInfo = authTokenHistory.lastObject;
  return latestAuthTokenInfo.accountId;
}

- (NSMutableArray<MSAuthTokenValidityInfo *> *)authTokenValidityArray {
  NSMutableArray<MSAuthTokenInfo *> *__nullable tokenArray =
      (NSMutableArray<MSAuthTokenInfo *> * __nullable)[MSKeychainUtil arrayForKey:kMSAuthTokenHistoryKey];
  NSMutableArray<MSAuthTokenValidityInfo *> *resultArray = [NSMutableArray<MSAuthTokenValidityInfo *> new];
  if (!tokenArray || tokenArray.count == 0) {
    [resultArray addObject:[[MSAuthTokenValidityInfo alloc] initWithAuthToken:nil startTime:nil endTime:nil]];
    return resultArray;
  }
  for (NSUInteger i = 0; i < tokenArray.count; i++) {
    MSAuthTokenInfo *currentAuthTokenInfo = tokenArray[i];
    NSDate *expiresOn = currentAuthTokenInfo.expiresOn;
    NSDate *nextTokenStartTime = i + 1 < tokenArray.count ? tokenArray[i + 1].startTime : nil;
    if (nextTokenStartTime && expiresOn && [nextTokenStartTime laterDate:expiresOn]) {
      expiresOn = nextTokenStartTime;
    } else if (!expiresOn && nextTokenStartTime) {
      expiresOn = nextTokenStartTime;
    }
    [resultArray addObject:[[MSAuthTokenValidityInfo alloc] initWithAuthToken:currentAuthTokenInfo.authToken
                                                                    startTime:currentAuthTokenInfo.startTime
                                                                      endTime:expiresOn]];
  }
  return resultArray;
}

- (void)removeAuthToken:(nullable NSString *)authToken {
  @synchronized(self) {

    // Read token array from storage.
    NSMutableArray<MSAuthTokenInfo *> *tokenArray = [[self authTokenHistory] mutableCopy];

    // Do nothing if there's just one entry in the history or no history at all.
    if (!tokenArray || tokenArray.count <= 1) {
      MSLogDebug([MSAppCenter logTag], @"Couldn't remove token from history; token history is empty or contains only current one.");
      return;
    }

    // Check oldest entry, delete if it matches.
    if (authToken != nil && tokenArray[0].authToken != nil && [authToken isEqualToString:(NSString * __nonnull) tokenArray[0].authToken]) {
      [tokenArray removeObjectAtIndex:0];
    } else {
      MSLogDebug([MSAppCenter logTag], @"Couldn't remove token from history; the token isn't oldest or is already removed.");
    }

    // Save new array after changes.
    [self setAuthTokenHistory:tokenArray];
    MSLogDebug([MSAppCenter logTag], @"The token has been removed from the history.");
  }
}

- (NSArray<MSAuthTokenInfo *> *)authTokenHistory {
  if (self.authTokenHistoryArray != nil) {
    return (NSArray<MSAuthTokenInfo *> *)self.authTokenHistoryArray;
  }
  NSArray<MSAuthTokenInfo *> *history = [MSKeychainUtil arrayForKey:kMSAuthTokenHistoryKey];
  if (history) {
    MSLogDebug([MSAppCenter logTag], @"Retrieved history state from the keychain.");
  } else {
    MSLogWarning([MSAppCenter logTag], @"Failed to retrieve history state from the keychain or none was found.");
    history = [NSArray<MSAuthTokenInfo *> new];
  }
  self.authTokenHistoryArray = history;
  return (NSArray<MSAuthTokenInfo *> *)self.authTokenHistoryArray;
}

- (void)setAuthTokenHistory:(nullable NSArray<MSAuthTokenInfo *> *)authTokenHistory {
  if ([MSKeychainUtil storeArray:(NSArray * __nonnull) authTokenHistory forKey:kMSAuthTokenHistoryKey]) {
    MSLogDebug([MSAppCenter logTag], @"Saved new history state in the keychain.");
    self.authTokenHistoryArray = authTokenHistory;
  } else {
    MSLogWarning([MSAppCenter logTag], @"Failed to save new history state in the keychain.");
  }
}

- (void)checkIfTokenNeedsToBeRefreshed:(MSAuthTokenValidityInfo *)tokenValidityInfo {
  NSArray *synchronizedDelegates;
  MSAuthTokenInfo *lastEntry;
  @synchronized(self) {
    lastEntry = [self authTokenHistory].lastObject;

    // Don't invoke refresh on old tokens - only on the latest one, if it's soon to be expired.
    if (![lastEntry.authToken isEqual:tokenValidityInfo.authToken]) {
      return;
    }
    if (![tokenValidityInfo expiresSoon]) {
      return;
    }

    // Don't invoke the delegate while locking; it might be locking too and deadlock ourselves.
    synchronizedDelegates = [self.delegates allObjects];
  }
  for (id<MSAuthTokenContextDelegate> delegate in synchronizedDelegates) {
    MSLogInfo([MSAppCenter logTag], @"The token needs to be refreshed.");
    if ([delegate respondsToSelector:@selector(authTokenContext:refreshAuthTokenForAccountId:)]) {
      [delegate authTokenContext:self refreshAuthTokenForAccountId:lastEntry.accountId];
    }
  }
}

- (void)finishInitialize {
    if (!self.resetAuthTokenRequired) {
      return;
    }
    self.resetAuthTokenRequired = NO;
    [self setAuthToken:nil withAccountId:nil expiresOn:nil];
}

- (void)preventResetAuthTokenAfterStart {
  self.resetAuthTokenRequired = NO;
}

@end
