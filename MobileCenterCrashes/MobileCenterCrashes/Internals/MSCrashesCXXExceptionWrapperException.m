/*
 * Copyright (c) Microsoft Corporation. All rights reserved.
 */

#import "MSCrashesCXXExceptionWrapperException.h"

@implementation MSCrashesCXXExceptionWrapperException {
  const MSCrashesUncaughtCXXExceptionInfo *_info;
}

- (instancetype)initWithCXXExceptionInfo:(const MSCrashesUncaughtCXXExceptionInfo *)info {
  extern char *__cxa_demangle(const char *mangled_name, char *output_buffer, size_t *length, int *status);
  char *demangled_name = &__cxa_demangle ? __cxa_demangle(info->exception_type_name ?: "", NULL, NULL, NULL) : NULL;

  if ((self = [super initWithName:[NSString stringWithUTF8String:demangled_name ?: info->exception_type_name ?: ""]
                           reason:[NSString stringWithUTF8String:info->exception_message ?: ""]
                         userInfo:nil])) {
    _info = info;
  }
  return self;
}

/*
 * This method overrides [NSThread callStackReturnAddresses] and is crucial to report CXX exceptions. This is one of the
 * "sneaky" things that require knowledge of how PLCrashReporter works internally.
 */
- (NSArray *)callStackReturnAddresses {
  NSMutableArray *cxxFrames = [NSMutableArray arrayWithCapacity:_info->exception_frames_count];

  for (uint32_t i = 0; i < _info->exception_frames_count; ++i) {
    [cxxFrames addObject:[NSNumber numberWithUnsignedLongLong:_info->exception_frames[i]]];
  }

  return cxxFrames;
}


@end
