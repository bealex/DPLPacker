//
// Copyright © by Alexander Babaev, 2013–2016
//
// This software is provided 'as-is', without any express or implied
// warranty.  In no event will the authors be held liable for any damages
// arising from the use of this software.
//

#import "DPLZipFileDB.h"
#import "FMDatabase.h"
#import "FMDatabaseQueue.h"


@implementation DPLZipFileDB {
        FMDatabaseQueue *_databaseQueue;

        BOOL _preparingDataInProgress;
    }

    - (id)initWithZipFile:(NSString *)aZipFilePath doNotUseFileIndex:(BOOL)doNotUseFileIndex {
        self = [super initWithZipFile:aZipFilePath doNotUseFileIndex:YES];
        if (self) {
            self.doNotUseFileIndex = NO;

            NSString *indexFileName = [NSString stringWithFormat:@"%@.db", [self getIndexFileName]];
            BOOL doesFileExists = [[NSFileManager defaultManager] fileExistsAtPath:indexFileName];

//#if TARGET_IPHONE_SIMULATOR && APPLICATION_BUILD
//            doesFileExists = doesFileExists && [[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/Resources/UnitTables/Packs.data_info.db", PROJECT_ROOT_PATH]];
//    #ifdef REBUILD_AND_TEST_EVERYTHING
//            doesFileExists = NO;
//    #endif
//            if (!doesFileExists) {
//                [[NSFileManager defaultManager] removeItemAtPath:indexFileName error:nil];
//                [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/Resources/UnitTables/Packs.data_info.db", PROJECT_ROOT_PATH] error:nil];
//            }
//#endif

            _databaseQueue = [FMDatabaseQueue databaseQueueWithPath:indexFileName flags:SQLITE_OPEN_READONLY];

            if (!doesFileExists) {
                [_databaseQueue close];
                _databaseQueue = [FMDatabaseQueue databaseQueueWithPath:indexFileName];

                _preparingDataInProgress = YES;

                [self createDBStructure];
                [self prepareFileData];

                _preparingDataInProgress = NO;
            }

//#if TARGET_IPHONE_SIMULATOR && APPLICATION_BUILD
//            if (!doesFileExists) {
//                [[NSFileManager defaultManager] copyItemAtPath:indexFileName
//                                                        toPath:[NSString stringWithFormat:@"%@/Resources/UnitTables/Packs.data_info.db", PROJECT_ROOT_PATH]
//                                                         error:nil];
//            }
//#endif
        }

        return self;
    }

    - (void)createDBStructure {
        // string name, ulong num_of_file, ulong pos_in_zip_directory

        [_databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
            [db executeUpdate:@""
                    "CREATE TABLE files("
                        "name TEXT,"
                        "num_of_file INTEGER,"
                        "pos_in_zip_directory INTEGER,"
                        "PRIMARY KEY (name)"
                    ");"];
        }];
    }

    - (BOOL)justLoadPrecreatedIndex {
        return !_preparingDataInProgress;
    }

    - (void)loadFileNameToPositionCacheFrom:(NSString *)aFilePath {
        // do nothing :)
    }

    - (void)saveFileNameToPositionCacheToIndex:(NSString *)aFileName {
        NSMutableDictionary<NSString *, NSArray *> *rawData = [NSMutableDictionary dictionary];
        [self updateDictionary:rawData withDataFrom:_fileNameToPosition prefix:@""];

        [_databaseQueue inTransaction:^(FMDatabase *db, BOOL *rollback) {
            for (NSString *name in rawData) {
                NSArray *value = rawData[name];
                [db executeUpdate:@"INSERT OR REPLACE INTO files(name, num_of_file, pos_in_zip_directory) VALUES (?, ?, ?)",
                                  name, value[0], value[1]];
            }
        }];
    }

    - (void)updateDictionary:(NSMutableDictionary<NSString *, NSArray *> *)aResult withDataFrom:(NSDictionary *)aSourceData prefix:(NSString *)aPrefix {
        for (NSString *namePart in aSourceData) {
            id value = aSourceData[namePart];

            NSString *newPrefix = [NSString stringWithFormat:@"%@%@", aPrefix, [aPrefix length] == 0 ? namePart : [NSString stringWithFormat:@"/%@", namePart]];
            if ([value isKindOfClass:[NSDictionary class]]) {
                [self updateDictionary:aResult withDataFrom:value prefix:newPrefix];
            } else if ([value isKindOfClass:[NSArray class]]) {
                aResult[newPrefix] = value;
            }
        }
    }

    - (NSArray *)getPositionDataForFileName:(NSString *)aFileName {
        __block NSArray *result = nil;

        [_databaseQueue inDatabase:^(FMDatabase *db) {
            NSMutableString *fileName = [NSMutableString stringWithString:aFileName];
            CFStringNormalize((__bridge CFMutableStringRef) fileName, kCFStringNormalizationFormC);

            FMResultSet *resultSet = [db executeQuery:@"SELECT num_of_file, pos_in_zip_directory "
                                                              "FROM files "
                                                              "WHERE name=?", fileName];

            [resultSet next];
            if ([resultSet hasAnotherRow]) {
                result = @[
                        @([resultSet unsignedLongLongIntForColumnIndex:0]),
                        @([resultSet unsignedLongLongIntForColumnIndex:1]),
                ];
            }
            [resultSet close];
        }];

        return result;
    }
@end