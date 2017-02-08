/*
 * Copyright (c) Microsoft Corporation. All rights reserved.
 */

#import "MobileCenter+Internal.h"
@import Foundation;

@interface MSStackFrame : NSObject <MSSerializableObject>

/*
 * Frame address [optional].
 */
@property(nonatomic, copy, nullable) NSString *address;

/*
 * Symbolized code line [optional].
 */
@property(nonatomic, copy, nullable) NSString *code;

/*
 * The fully qualified name of the Class containing the execution point represented by this stack trace element
 * [optional].
 */
@property(nonatomic, copy, nullable) NSString *className;

/*
 * The name of the method containing the execution point represented by this stack trace element [optional].
 */
@property(nonatomic, copy, nullable) NSString *methodName;

/*
 * The line number of the source line containing the execution point represented by this stack trace element [optional].
 */
@property(nonatomic, copy, nullable) NSNumber *lineNumber;

/*
 * The name of the file containing the execution point represented by this stack trace element [optional].
 */
@property(nonatomic, copy, nullable) NSString *fileName;

/**
 * Is equal to another stack frame
 *
 * @param frame Stack frame
 *
 * @return Return YES if equal and NO if not equal
 */
- (BOOL)isEqual:(nullable MSStackFrame *)frame;

@end
