//
/*
 * Copyright (c) Microsoft Corporation. All rights reserved.
 */

#import <Foundation/Foundation.h>
#import "Sonoma+Internal.h"

@class SNMErrorBinaryAttachment;

/*
 * Attachment for error log.
 */
@interface SNMErrorAttachment : NSObject <SNMSerializableObject>

/**
 * Plain text attachment [optional].
 */
@property(nonatomic, nullable) NSString *textAttachment;

/**
 * Binary attachment [optional].
 */
@property(nonatomic, nullable) SNMErrorBinaryAttachment *binaryAttachment;

+ (nonnull SNMErrorAttachment *)attachmentWithText:(nonnull NSString *)text;

+ (nonnull SNMErrorAttachment *)attachmentWithBinaryData:(nonnull NSData *)data filename:(nonnull NSString *)filename mimeType:(nonnull NSString *)mimeType;

+ (nonnull SNMErrorAttachment *)attachmentWithText:(nonnull NSString *)text andBinaryData:(nonnull NSData *)data filename:(nonnull NSString *)filename mimeType:(nonnull NSString *)mimeType;

+ (nonnull SNMErrorAttachment *)attachmentWithURL:(nonnull NSURL *)file mimeType:(nullable NSString *)mimeType;

@end
