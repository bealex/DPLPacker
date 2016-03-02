//
// Copyright © by Alexander Babaev, 2013–2016
//
// This software is provided 'as-is', without any express or implied
// warranty.  In no event will the authors be held liable for any damages
// arising from the use of this software.
//

#define NOCRYPT
#define NOUNCRYPT

#ifndef TARGET_OS_IPHONE
    #import <UIKit/UIKit.h>
#endif

@interface DPLZipFile : NSObject {
    @protected
        NSMutableDictionary *_fileNameToPosition;
    }

    // Полезно, если очень сильные ограничения по памяти.
    // Может быть медленнее на пару порядков в случае частых обращений к файлам.
    @property (nonatomic) BOOL doNotUseFileIndex;

    - (id)initWithZipFile:(NSString *)aZipFilePath;
    - (id)initWithZipFile:(NSString *)aZipFilePath doNotUseFileIndex:(BOOL)doNotUseFileIndex;

    - (BOOL)fileExistsForPath:(NSString *)aFilePath;
    - (NSData *)dataForPath:(NSString *)aFilePath;

    - (NSArray *)fileListForPath:(NSString *)aDirectoryPath;

    - (NSString *)getIndexFileName;
    - (NSString *)getCachedIndexFileName;

    // please do not call these :)
    - (void)prepareFileData;

    // These methods are for overriding. This class uses plain files. Faster subclass uses SQLite.
    - (BOOL)justLoadPrecreatedIndex;
    - (void)saveFileNameToPositionCacheToIndex:(NSString *)aFileName;
    - (void)loadFileNameToPositionCacheFrom:(NSString *)aFilePath;
    - (NSArray *)getPositionDataForFileName:(NSString *)aFileName;
@end
