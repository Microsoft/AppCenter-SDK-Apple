#import <Foundation/Foundation.h>

#import "MSAppDelegateForwarder.h"

NS_ASSUME_NONNULL_BEGIN

@interface MSAppDelegateForwarder ()

/**
 * Hash table containing all the delegates as weak references.
 */
@property(nonatomic, class) NSHashTable<id<MSAppDelegate>> *delegates;

/**
 * Keep track of original selectors to swizzle.
 */
@property(nonatomic, class, readonly) NSMutableSet<NSString *> *selectorsToSwizzle;

/**
 * List of original selectors not to override if already implemented in the original application delegate.
 */
@property(nonatomic, class, readonly) NSArray<NSString *> *selectorsNotToOverride;

/**
 * Keep track of the original delegate's method implementations.
 */
@property(nonatomic, class, readonly) NSMutableDictionary<NSString *, NSValue *> *originalImplementations;

/**
 * Trace buffer storing debbuging traces.
 */
@property(nonatomic, class, readonly) NSMutableArray<dispatch_block_t> *traceBuffer;

#if TARGET_OS_OSX
/**
 * Hold the original @see NSApplication#setDelegate: implementation.
 */
#else
/**
 * Hold the original @see UIApplication#setDelegate: implementation.
 */
#endif
@property(nonatomic, class) IMP originalSetDelegateImp;

/**
 * Register swizzling for the given original application delegate.
 *
 * @param originalDelegate The original application delegate.
 */
+ (void)swizzleOriginalDelegate:(id<MSApplicationDelegate>)originalDelegate;

@end

NS_ASSUME_NONNULL_END
