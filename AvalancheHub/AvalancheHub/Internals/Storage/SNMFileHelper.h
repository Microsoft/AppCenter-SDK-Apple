/*
 * Copyright (c) Microsoft Corporation. All rights reserved.
 */

#import "SNMFile.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 A class which abstracts file i/o operations.
 */
@interface SNMFileHelper : NSObject

/**
 * Returns the `NSFileManager` instance used for reading and writing
 * directories.
 *
 * @returns
 */
+ (NSFileManager *)fileManager;

/**
 * Sets a custom `NSFileManager` instance. By default, the `defaultManager` will
 * be used.
 *
 * @param fileManager the `NSFileManager` instance to use
 */
+ (void)setFileManager:(nullable NSFileManager *)fileManager;

/**
 * Writes data to a file.
 *
 * @param data the data that should be written to disk
 * @param file the file metadata representing the target file
 *
 * @return true if writing data to the given file was successful
 */
+ (BOOL)writeData:(NSData *)data toFile:(SNMFile *)file;

/**
 * Delete a file.
 *
 * @param file the file metadata representing the target file
 *
 * @return true if deleting the file was successful
 */
+ (BOOL)deleteFile:(SNMFile *)file;

/**
 * Returns all file metadata of a given directory.
 *
 * @param directoryPath the absolute path to the directory
 * @param fileExtension a file extension that should be used to filter the
 * results
 *
 * @return a list with file metadata
 */
+ (NSArray<SNMFile *> *)filesForDirectory:(NSString *)directoryPath withFileExtension:(NSString *)fileExtension;

NS_ASSUME_NONNULL_END

/**
 * Returns the content of a file.
 *
 * @param file the file metadata representing the target file
 *
 * @return the content data of the file
 */
+ (nullable NSData *)dataForFile:(nonnull SNMFile *)file;

@end
