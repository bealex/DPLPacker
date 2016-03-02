//
// Copyright © by Alexander Babaev, 2013–2016
//
// This software is provided 'as-is', without any express or implied
// warranty.  In no event will the authors be held liable for any damages
// arising from the use of this software.
//

#import "DPLZipFile.h"
#import "unzip.h"

// zip -0 -r test *

@implementation DPLZipFile {
        NSString *_zipFileName;
        NSMutableDictionary *_sameFilesWithDifferentWidthSymbols;
    }

    - (id)initWithZipFile:(NSString *)aZipFilePath {
        return [self initWithZipFile:aZipFilePath doNotUseFileIndex:NO];
    }

    - (id)initWithZipFile:(NSString *)aZipFilePath doNotUseFileIndex:(BOOL)doNotUseFileIndex {
        self = [super init];
        if (self) {
            _doNotUseFileIndex = doNotUseFileIndex;

            _zipFileName = aZipFilePath;
            aZipFilePath = [aZipFilePath stringByExpandingTildeInPath];
            aZipFilePath = [aZipFilePath stringByResolvingSymlinksInPath];
            aZipFilePath = [aZipFilePath stringByStandardizingPath];

            if (![aZipFilePath hasPrefix:@"/"]) {
                NSFileManager *fileManager = [NSFileManager defaultManager];
                NSString *currentDirectory = [fileManager currentDirectoryPath];
                aZipFilePath = [NSString stringWithFormat:@"%@/%@", currentDirectory, aZipFilePath];
            }

            _zipFileName = aZipFilePath;

            if (!_doNotUseFileIndex) {
                [self prepareFileData];
            }
        }
        return self;
    }

    - (NSString *)getIndexFileName {
        return [_zipFileName stringByAppendingString:@"_info"];
    }

    - (NSString *)getCachedIndexFileName {
        NSFileManager *fileManager = [NSFileManager defaultManager];

        NSString *zipFileName = [_zipFileName lastPathComponent];
        NSArray *cacheDirectories = [fileManager URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask];

        return [NSString stringWithFormat:@"%@/%@_info", [[cacheDirectories[0] absoluteURL] path], zipFileName];
    }

    - (BOOL)justLoadPrecreatedIndex {
        return [[NSFileManager defaultManager] fileExistsAtPath:[self getIndexFileName]];
    }

    - (void)saveFileNameToPositionCacheToIndex:(NSString *)aFileName {
        NSError *error = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:_fileNameToPosition options:0 error:&error];
        [data writeToFile:aFileName atomically:YES];
    }

    - (void)loadFileNameToPositionCacheFrom:(NSString *)aFilePath {
        NSData *data = [NSData dataWithContentsOfFile:aFilePath];
        NSError *error = nil;
        _fileNameToPosition = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    }

    - (void)prepareFileData {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *pathFileInfo = [self getIndexFileName];

//        if (NO) {
        if ([self justLoadPrecreatedIndex]) {
            [self loadFileNameToPositionCacheFrom:pathFileInfo];
        } else {
#if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR
            pathFileInfo = [self getCachedIndexFileName];

//            if (NO) {
            if ([fileManager fileExistsAtPath:pathFileInfo]) {
                [self loadFileNameToPositionCacheFrom:pathFileInfo];
            } else {
#endif
                _fileNameToPosition = [NSMutableDictionary dictionary];

                int returnValue = 0;

                unzFile _zipFile = unzOpen([_zipFileName cStringUsingEncoding:NSUTF8StringEncoding]);
                returnValue = unzGoToFirstFile(_zipFile);

                if (returnValue == UNZ_OK) {
                    int iterationReturnValue = UNZ_OK;

                    do {
                        iterationReturnValue = unzOpenCurrentFile(_zipFile);

                        if (iterationReturnValue == UNZ_OK) {
                            // reading data and write to file
                            unz_file_info fileInfo = {0};
                            iterationReturnValue = unzGetCurrentFileInfo(_zipFile, &fileInfo, NULL, 0, NULL, 0, NULL, 0);
                            if (iterationReturnValue == UNZ_OK) {
                                char *filename = (char *) malloc(fileInfo.size_filename + 1);
                                unzGetCurrentFileInfo(_zipFile, &fileInfo, filename, fileInfo.size_filename + 1, NULL, 0, NULL, 0);
                                filename[fileInfo.size_filename] = '\0';
                                NSString *strPath = [NSString stringWithCString:filename encoding:NSUTF8StringEncoding];
                                free(filename);

                                if ([strPath rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"/\\"]].location != NSNotFound) {
                                    // contains a path
                                    strPath = [strPath stringByReplacingOccurrencesOfString:@"\\" withString:@"/"];
                                }

                                // Copy name to array
                                NSString *fileName = [strPath copy];

                                [self saveFileInfoForRandomAccess:fileName inZipFile:_zipFile];
                            } else {
                                NSLog(@"Error occured during getting info for a file (Error %d)", iterationReturnValue);
                                unzCloseCurrentFile(_zipFile);
                                break;
                            }
                        }

                        unzCloseCurrentFile(_zipFile);
                        iterationReturnValue = unzGoToNextFile(_zipFile);
                        if (iterationReturnValue != UNZ_OK && iterationReturnValue != UNZ_END_OF_LIST_OF_FILE) {
                            NSLog(@"Error occured during going to next file (Error %d)", iterationReturnValue);
                        }
                    } while (iterationReturnValue == UNZ_OK && UNZ_OK != UNZ_END_OF_LIST_OF_FILE);

                    [self saveFileNameToPositionCacheToIndex:pathFileInfo];

                    unzClose(_zipFile);
                } else {
                    NSLog(@"Something (%@; %@) was not found O_O in zip file (Error %d)", _zipFileName, pathFileInfo, returnValue);
                }
#if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR
            }
#endif
        }
    }

    - (void)saveFileInfoForRandomAccess:(NSString *)aFileName inZipFile:(unzFile)aZipFile {
        unz_file_pos filePos;
        int result = unzGetFilePos(aZipFile, &filePos);
        if (result != UNZ_OK) {
            NSLog(@"Error (%d) getting file position: %@", result, aFileName);
        }

        NSMutableString *fileName = [NSMutableString stringWithString:aFileName];
        CFStringNormalize((__bridge CFMutableStringRef) fileName, kCFStringNormalizationFormC);

        NSArray *pathParts = [fileName componentsSeparatedByString:@"/"];
        NSUInteger currentPartIndex = 0;
        NSMutableDictionary *cache = _fileNameToPosition;
        while (currentPartIndex < [pathParts count] - 1) {
            NSMutableDictionary *cacheNext = cache[pathParts[currentPartIndex]];
            if (cacheNext == nil) {
                cacheNext = [NSMutableDictionary dictionary];
                cache[pathParts[currentPartIndex]] = cacheNext;
            }

            cache = cacheNext;
            currentPartIndex++;
        }

        cache[[pathParts lastObject]] = @[
                @(filePos.num_of_file),
                @(filePos.pos_in_zip_directory)
        ];
    }

    - (BOOL)restoreFileInfoForRandomAccess:(NSString *)aFileName inZipFile:(unzFile)aZipFile {
        BOOL fileFound = NO;

        if (_doNotUseFileIndex) {
            int result = unzGoToFirstFile(aZipFile);
            if (result != UNZ_OK) {
                NSLog(@"Error (%d) going to first file (searching for: %@)", result, aFileName);
            } else {
                while (true) {
                    char filename_inzip[256] = {0};
                    unz_file_info file_info = {0};
                    result = unzGetCurrentFileInfo(aZipFile, &file_info, filename_inzip, sizeof(filename_inzip), NULL, 0, NULL, 0);
                    if (result != UNZ_OK) {
                        NSLog(@"error %d with zipfile in unzGetCurrentFileInfo (searching for: %@)", result, aFileName);
                        break;
                    }

                    NSString *fileName = [NSString stringWithCString:filename_inzip encoding:NSUTF8StringEncoding];
                    if ([fileName isEqualToString:aFileName]) {
                        fileFound = YES;
                        break;
                    }

                    result = unzGoToNextFile(aZipFile);
                    if (result != UNZ_OK) {
                        if (result != UNZ_END_OF_LIST_OF_FILE) {
                            NSLog(@"Error (%d) going to next file (searching for: %@)", result, aFileName);
                        }

                        break;
                    }
                }
            }
        } else {
            NSArray *savedData = [self getPositionDataForFileName:aFileName];

            unz_file_pos filePos;
            filePos.num_of_file = [savedData[0] unsignedLongValue];
            filePos.pos_in_zip_directory = [savedData[1] unsignedLongValue];

            int result = unzGoToFilePos(aZipFile, &filePos);
            if (result != UNZ_OK) {
                NSLog(@"Error (%d) setting file position: %@", result, aFileName);
            } else {
                fileFound = YES;
            }
        }

        return fileFound;
    }

    - (NSArray *)getPositionDataForFileName:(NSString *)aFileName {
        if (aFileName == nil) {
            return @[];
        } else {
            NSMutableString *fileName = [NSMutableString stringWithString:aFileName];
            CFStringNormalize((__bridge CFMutableStringRef) fileName, kCFStringNormalizationFormC);

            NSArray *pathParts = [fileName componentsSeparatedByString:@"/"];
            NSUInteger currentPartIndex = 0;
            NSMutableDictionary *cache = _fileNameToPosition;
            while (currentPartIndex != [pathParts count] - 1) {
                NSMutableDictionary *cacheNext = cache[pathParts[currentPartIndex]];
                if (cacheNext == nil) {
                    cache = nil;
                    break;
                }

                cache = cacheNext;
                currentPartIndex++;
            }

            NSArray *savedData = cache[[pathParts lastObject]];
            return savedData;
        }
    }

    - (BOOL)fileExistsForPath:(NSString *)aFilePath {
        BOOL result = NO;

        if (_doNotUseFileIndex) {
            unzFile _zipFile = unzOpen([_zipFileName cStringUsingEncoding:NSUTF8StringEncoding]);
            result = [self restoreFileInfoForRandomAccess:aFilePath inZipFile:_zipFile];
            unzClose(_zipFile);
        } else {
            NSArray *savedData = [self getPositionDataForFileName:aFilePath];
            result = (savedData != nil);
        }

        return result;
    }

    - (NSData *)dataForPath:(NSString *)aFilePath {
        //ToDo: update for concurrent access
        if (aFilePath == nil || (!_doNotUseFileIndex && ![self fileExistsForPath:aFilePath])) {
            return nil;
        }

        NSString *correctPath = _sameFilesWithDifferentWidthSymbols[aFilePath];
        if (correctPath != nil) {
            aFilePath = correctPath;
        }

        NSMutableData *data = nil;

        unzFile _zipFile = unzOpen([_zipFileName cStringUsingEncoding:NSUTF8StringEncoding]);

        BOOL fileWasFound = [self restoreFileInfoForRandomAccess:aFilePath inZipFile:_zipFile];
        if (fileWasFound) {
            int returnValue = 0;
            returnValue = unzOpenCurrentFile(_zipFile);

            if (returnValue != UNZ_OK ) {
                NSLog(@"Error during opening file %@ in zip (%d)", aFilePath, returnValue);
            } else {
                // reading data and write to file
                unz_file_info fileInfo = {0};
                returnValue = unzGetCurrentFileInfo(_zipFile, &fileInfo, NULL, 0, NULL, 0, NULL, 0);

                if (returnValue != UNZ_OK) {
                    NSLog(@"Error occurs while getting file %@ info (%d)", aFilePath, returnValue);
                } else {
                    data = [[NSMutableData alloc] initWithLength:fileInfo.uncompressed_size];

                    void *buffer = data.mutableBytes;
                    int read = 0;
                    while (YES) {
                        //ToDo: тут максимальный размер файла, который можно прочитать — 2Гб.
                        read = unzReadCurrentFile(_zipFile, buffer, (uint) fileInfo.uncompressed_size);

                        if (read > 0) {
                            buffer += read;
                        } else if (read < 0) {
                            NSLog(@"Error during reading file %@ in zip (%d)", aFilePath, read);
                            break;
                        } else {
                            break;
                        }
                    }
                }
            }
        }

        unzClose(_zipFile);

        return data;
    }

    - (NSArray *)fileListForPath:(NSString *)aDirectoryPath {
        if (![aDirectoryPath hasSuffix:@"/"]) {
            aDirectoryPath = [NSString stringWithFormat:@"%@/", aDirectoryPath];
        }

        NSMutableArray *files = [NSMutableArray array];

        unzFile aZipFile = unzOpen([_zipFileName cStringUsingEncoding:NSUTF8StringEncoding]);

        NSString *directoryPath = [aDirectoryPath decomposedStringWithCanonicalMapping];

        int result = unzGoToFirstFile(aZipFile);
        if (result != UNZ_OK) {
            NSLog(@"Error (%d) going to first file (searching for: %@)", result, aDirectoryPath);
        } else {
            while (true) {
                char filename_inzip[256] = {0};
                unz_file_info file_info = {0};
                result = unzGetCurrentFileInfo(aZipFile, &file_info, filename_inzip, sizeof(filename_inzip), NULL, 0, NULL, 0);
                if (result != UNZ_OK) {
                    NSLog(@"error %d with zipfile in unzGetCurrentFileInfo (searching for: %@)", result, aDirectoryPath);
                    break;
                }

                NSString *fileName = [NSString stringWithCString:filename_inzip encoding:NSUTF8StringEncoding];
                if ([[fileName decomposedStringWithCanonicalMapping] hasPrefix:directoryPath]) {
                    [files addObject:fileName];
                }

                result = unzGoToNextFile(aZipFile);
                if (result != UNZ_OK) {
                    if (result != UNZ_END_OF_LIST_OF_FILE) {
                        NSLog(@"Error (%d) going to next file (searching for: %@)", result, aDirectoryPath);
                    }

                    break;
                }
            }
        }

        unzClose(aZipFile);

        return [files copy];
    }

@end


