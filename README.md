# DPLPacker
DPLPacker is a library that allows packing resources in a zip-file and accessing them from within iOS applications.

It is useful when your project contains thousands of small resource files. After packing in a smaller file, installation time on a device speeds up a lot. Also, it is possible to use compressed zip-files to same some space.

## Usage:
 1. add sources to the project
 2. if you need DB-based index file, add FMDB https://github.com/ccgus/fmdb
 3. Prepare zip file with something like `zip -0 -r pack *`. I recommend this option because it does not use compression and very fast.


Basic classes description.
 - `DPLPackedURLProtocol` allows usage `packed:` protocol for accessing files in an archive. Just initialize it with `[DPLPackedURLProtocol enablePackedProtocol]`
 - If you need to access packed files manually, you can use `DPLZipFile`.
 — For faster, random access to the files, you can use index file that can be prepared with `saveFileNameToPositionCacheToIndex`
 — If you need, you can use SQLite-based (`DPLZipFileDB`) index instead of JSON-based. It is slightly better for memory use. Speed is almost the same.
 
