//
// Copyright © by Alexander Babaev, 2013–2016
//
// This software is provided 'as-is', without any express or implied
// warranty.  In no event will the authors be held liable for any damages
// arising from the use of this software.
//


#import "DPLPackedURLProtocol.h"
#import "DPLZipFile.h"


#pragma clang diagnostic push
#pragma ide diagnostic ignored "OCUnusedMethodInspection"

static NSMutableDictionary *gZIP_FILES = nil;
static NSMutableDictionary *gZIP_FILE_ALIASES = nil;


@interface DPLPackedURLProtocol()
    + (NSURL *)retinaImageURL:(NSURL *)aURL;
@end


@implementation NSURL(DPLPackedURLProtocolAdditions)
    + (NSURL *)packedURLForZip:(NSString *)aZipFileName andPath:(NSString *)aPathInsideZip {
        static dispatch_once_t predicate = 0;
        dispatch_once(&predicate, ^{
            if (gZIP_FILE_ALIASES == nil) {
                gZIP_FILE_ALIASES = [NSMutableDictionary dictionary];
            }
        });

        NSURL *result = nil;

        NSString *zipFilePath = aZipFileName;
        if (gZIP_FILES[zipFilePath] == nil) {
            zipFilePath = gZIP_FILE_ALIASES[aZipFileName];

            if (zipFilePath == nil) {
                zipFilePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:aZipFileName];
                gZIP_FILE_ALIASES[aZipFileName] = zipFilePath;
            }
        }

        result = [[NSURL alloc] initWithScheme:@"packed" host:@"" path:[NSString stringWithFormat:@"%@?%@", zipFilePath, aPathInsideZip]];

        return result;
    }
@end


#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE

@implementation UIImage(DPLPackedURLProtocolAdditions)
    + (UIImage *)imageForPackedURL:(NSURL *)aURL {
        CGFloat scale = 1;
        NSData *imageData = nil;
        NSURL *imageURL = aURL;

        if ([UIScreen mainScreen].scale > 1.9) {
            NSURL *retinaURL = [DPLPackedURLProtocol retinaImageURL:aURL];
            if (retinaURL != nil) {
                imageURL = retinaURL;
                scale = 2;
            }
        }

        imageData = [NSData dataWithContentsOfURL:imageURL];

        CGDataProviderRef dataProvider = CGDataProviderCreateWithCFData((__bridge CFDataRef) imageData);
        CGImageRef cgImage = CGImageCreateWithPNGDataProvider(dataProvider, NULL, NO, kCGRenderingIntentDefault);

        UIImage *image = [UIImage imageWithCGImage:cgImage scale:scale orientation:UIImageOrientationUp];

        CGDataProviderRelease(dataProvider);
        CGImageRelease(cgImage);

        return image;
    }
@end

#endif


@implementation DPLPackedURLProtocol {
        NSString *_zipName;
        NSString *_filePath;
    }

    + (void)enablePackedProtocol {
        [NSURLProtocol registerClass:self];
    }

    + (void)disablePackedProtocol {
        [NSURLProtocol unregisterClass:self];
    }

    + (BOOL)canInitWithRequest:(NSURLRequest *)request {
        return [request.URL.scheme isEqualToString:@"packed"];
    }

    + (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
        return request;
    }

    + (DPLZipFile *)getZipFileForName:(NSString *)zipName {
        DPLZipFile *zipFile = gZIP_FILES[zipName];
        if (zipFile == nil) {
            zipFile = [[DPLZipFile alloc] initWithZipFile:zipName];
            gZIP_FILES[zipName] = zipFile;
            NSString *fileName = [zipName lastPathComponent];
            if (![[gZIP_FILES allKeys] containsObject:fileName]) {
                gZIP_FILES[fileName] = zipFile;
            }
        }
        return zipFile;
    }

    + (NSURL *)retinaImageURL:(NSURL *)aURL {
        NSURL *result = nil;

        NSString *zipName = aURL.path;
        NSString *filePath = [aURL.query stringByReplacingPercentEscapesUsingEncoding:NSASCIIStringEncoding];

        if ([[filePath lowercaseString] hasSuffix:@"@2x.png"]) {
            result = aURL;
        } else if ([[filePath lowercaseString] hasSuffix:@".png"]) {
            filePath = [filePath stringByReplacingOccurrencesOfString:@".png" withString:@"@2x.png"];

            DPLZipFile *file = [self getZipFileForName:zipName];
            if ([file fileExistsForPath:filePath]) {
                result = [NSURL packedURLForZip:zipName andPath:filePath];
            }
        }

        return result;
    }

    - (id)initWithRequest:(NSURLRequest *)request cachedResponse:(NSCachedURLResponse *)cachedResponse client:(id<NSURLProtocolClient>)client {
        self = [super initWithRequest:request cachedResponse:cachedResponse client:client];
        if (self) {
            static dispatch_once_t predicate = 0;
            dispatch_once(&predicate, ^{
                if (gZIP_FILES == nil) {
                    gZIP_FILES = [NSMutableDictionary dictionary];
                }
            });

            _zipName = self.request.URL.path;
            _filePath = [self.request.URL.query stringByReplacingPercentEscapesUsingEncoding:NSASCIIStringEncoding];
        }

        return self;
    }

    - (void)startLoading {
        DPLZipFile *zipFile = [DPLPackedURLProtocol getZipFileForName:_zipName];
        NSData *data = [zipFile dataForPath:_filePath];

        [self.client URLProtocol:self didReceiveResponse:[[NSURLResponse alloc] init] cacheStoragePolicy:NSURLCacheStorageNotAllowed];

        if (data != nil) {
            [self.client URLProtocol:self didLoadData:data];
            [self.client URLProtocolDidFinishLoading:self];
        } else {
            NSError *error = [NSError errorWithDomain:@"DPLPackedURLProtocol" code:-1 userInfo:@{@"file" : self.request.URL.path}];
            [self.client URLProtocol:self didFailWithError:error];
        }
    }

    - (void)stopLoading {
    }
@end

#pragma clang diagnostic pop
