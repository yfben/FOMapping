//
//  FOObject.h
//  FOMapping
//
//  Created by tradevan on 2015/7/17.
//  Copyright (c) 2015年 tradevan. All rights reserved.
//

#import <FMDB/FMDB.h>

@protocol FOObject

/*!
 Override this method to indicate the corresponding table name.
 */
+(NSString *)tableName;

@end


/*!
 Subclass this class and add properties to map to a table. The table must define its primary key(s).
 The type or class can be determined according to the following rules:<br>
 1. INTEGER: NSInteger<br>
 2. REAL: double<br>
 3. TEXT: NSString *<br>
 4. BLOB: NSData *<br>
 5. DATE: NSDate *<br>
 <br>
 If you don't set the date formatter of the FMDatabase object, FOObject will assume you store a date in REAL, which means the number of seconds since 1970-01-01 00:00:00 UTC. Otherwise FOObject will use the date formatter to parse a date in TEXT.
 */
@interface FOObject : NSObject<FOObject, NSCopying>


/*!
 Create an instance of FOObject by using an FMResultSet object.
 @code
 FMDatabase *db = [FMDatabase databaseWithPath:dbPath];
 if ([db open]) {
    FMResultSet *rs = [db executeQuery:@"SELECT * from aTable"];
    while ([rs next]) {
        FOObject *anObj = [FOObject objectWithResultSet:rs];
    }
 }
 @endcode
 @param rs
 An array of containing the query result with type FOObjects.
 @return An instance of FOObject.
 */
+(NSArray *)objectsFromResultSet:(FMResultSet *)rs;

+(NSArray *)customObjectsFromResultSet:(FMResultSet *)rs class:(Class)objClass;

/*!
 Create an instance of NSDictionary to store a temporary query result which does not have a corresponding class by using an FMResultSet object. This dictionary will not contain any NSDate object because there is no way to learn whether a column value is for date or not.
 @code
 FMDatabase *db = [FMDatabase databaseWithPath:dbPath];
 if ([db open]) {
    FMResultSet *rs = [db executeQuery:@"SELECT col1 as temp1, col2 as temp2 from aTable"];
    while ([rs next]) {
        NSDictionary *aDic = [FOObject dictionaryWithResultSet:rs];
    }
 }
 @endcode
 @param rs
 An array of containing the query result with type NSDictionary.
 @return An instance of FOObject.
 */
+(NSArray *)dictionariesFromResultSet:(FMResultSet *)rs;


/*!
 Persists a row with the receiver's properties in the corresponding table in a given database connection.
 @see -(BOOL)remove:(FMDatabase *)db;
 @param db
 An FMDatabase connection.
 @return YES upon success; NO upon failure.
 */
-(BOOL)persist:(FMDatabase *)db;


/*!
 Delete the row in the corresponding table in a given database connection.
 @see -(BOOL)save:(FMDatabase *)db;
 @see -(BOOL)update:(FMDatabase *)db;
 @param db
 An FMDatabase connection.
 @return YES upon success; NO upon failure.
 */
-(BOOL)remove:(FMDatabase *)db;

@end
