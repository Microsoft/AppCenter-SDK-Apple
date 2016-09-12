/*
 * Copyright (c) Microsoft Corporation. All rights reserved.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 A class that represents a file on the file system.
 */
@interface SNMFile : NSObject

/**
 * The creation date of the file.
 */
@property(nonatomic, strong) NSDate *creationDate;

/**
 * The unique identifier for this file.
 */
@property(nonatomic, copy) NSString *fileId;

/**
 * The path to the file.
 */
@property(nonatomic, copy) NSString *filePath;

/**
 * Returns a new `SNMFile` instance with a given file id and creation date.
 *
 * @param filePath the path to the file
 * @param fileId a unique file identifier
 * @param creationDate the creation date of the file
 *
 * @return a new `SNMFile` instance
 */
- (instancetype)initWithPath:(NSString *)filePath fileId:(NSString *)fileId creationDate:(NSDate *)creationDate;

@end

NS_ASSUME_NONNULL_END
