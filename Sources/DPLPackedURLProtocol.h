//
// Copyright © by Alexander Babaev, 2013–2016
//
// This software is provided 'as-is', without any express or implied
// warranty.  In no event will the authors be held liable for any damages
// arising from the use of this software.
//


#import <Foundation/Foundation.h>
#if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR
    #import <UIKit/UIKit.h>
#endif

#pragma clang diagnostic push
#pragma ide diagnostic ignored "OCUnusedMethodInspection"

@interface NSURL (DPLPackedURLProtocolAdditions)
    + (NSURL*)packedURLForZip:(NSString*)aZipFileName andPath:(NSString*)aPathInsideZip;
@end


#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE

@interface UIImage (DPLPackedURLProtocolAdditions)
    + (UIImage*)imageForPackedURL:(NSURL*)aURL;
@end

#endif

@interface DPLPackedURLProtocol : NSURLProtocol
    + (void)enablePackedProtocol;
    + (void)disablePackedProtocol;
@end

#pragma clang diagnostic pop
