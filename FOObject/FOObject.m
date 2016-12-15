//
//  FOObject.m
//  FOMapping
//
//  Created by tradevan on 2015/7/17.
//  Copyright (c) 2015年 tradevan. All rights reserved.
//

#import <objc/message.h>
#import <sqlite3.h>
#import "FOObject.h"

@interface FOObject() {
    
    id _persistentObj;
}
@end

@implementation FOObject

+(NSString *)tableName {
    
    NSString *reason = @"Override this method to specify the table name.";
    NSException* exception = [NSException exceptionWithName:@"TableNameNotSpecifiedException"
                                                     reason:reason userInfo:nil];
    @throw exception;
}

+(NSArray *)pks:(FMDatabase *)db {
    
    Class selfClass = [self class];
    NSString *tableName = [selfClass tableName];
    
    FMResultSet *rs = [db executeQuery:[NSString stringWithFormat:@"pragma table_info(%@);", tableName]];
    
    NSMutableArray *result = [[NSMutableArray alloc] init];
    while ([rs next]) {
        
        NSString *colName = [rs stringForColumn:@"name"];
        
        if (!class_getProperty(selfClass, [colName UTF8String])) {
            
            NSString *reason = [NSString stringWithFormat:@"Property '%@' not found in class %@.", colName, NSStringFromClass(selfClass)];
            NSException* exception = [NSException exceptionWithName:@"PropertyNotFoundException"
                                                             reason:reason userInfo:nil];
            @throw exception;
        }
        
        if ([rs boolForColumn:@"pk"]) {
            
            [result addObject:colName];
        }
    }
    
    if (result.count < 1) {
        
        NSString *reason = [NSString stringWithFormat:@"%@ should have at least 1 primary key.", tableName];
        NSException* exception = [NSException exceptionWithName:@"PrimaryKeyNotFoundException"
                                                         reason:reason userInfo:nil];
        @throw exception;
        
    }
    
    return [result copy];
}


typedef NS_ENUM(NSInteger, FOPropertyType) {
    FOPropertyTypeNumber,
    FOPropertyTypeString,
    FOPropertyTypeDate,
    FOPropertyTypeData
};

+(FOPropertyType)typeOfProperty:(objc_property_t)property {
    
    NSString *propertyAttrsString = [NSString stringWithUTF8String:property_getAttributes(property)];
    NSString *typeString = [propertyAttrsString componentsSeparatedByString:@","].firstObject;
    
    // NSInteger(Ti, Tq), NSUInteger(TI, TQ)
    if ([typeString isEqualToString:@"Ti"]
        ||[typeString isEqualToString:@"Tq"]
        || [typeString isEqualToString:@"TI"]
        || [typeString isEqualToString:@"TQ"]) {
        
        return FOPropertyTypeNumber;
    }
    // BOOL(Tc, TB)
    else if ([typeString isEqualToString:@"Tc"] || [typeString isEqualToString:@"TB"]) {
        
        return FOPropertyTypeNumber;
    }
    // double
    else if ([typeString isEqualToString:@"Td"]) {
        
        return FOPropertyTypeNumber;
    }
    // NSString *
    else if ([typeString isEqualToString:@"T@\"NSString\""]) {
        
        return FOPropertyTypeString;
    }
    // NSDate *
    else if ([typeString isEqualToString:@"T@\"NSDate\""]) {
        
        return FOPropertyTypeDate;
    }
    // NSData *
    else if ([typeString isEqualToString:@"T@\"NSData\""]) {
        
        return FOPropertyTypeData;
    }
    else {
        
        NSString *reason = [NSString stringWithFormat:@"FOPropertyType cannot be determined."];
        NSException* exception = [NSException exceptionWithName:@"InvalidFOPropertyTypeException"
                                                         reason:reason userInfo:nil];
        @throw exception;
    }
}

+(NSArray *)objectsFromResultSet:(FMResultSet *)rs {
    
    NSMutableArray *objects = [NSMutableArray array];
    
    while ([rs next]) {
        
        id object = [[[self class] alloc] init];
        
        int columnCount = sqlite3_column_count(rs.statement.statement);
        
        for (int i = 0; i < columnCount; i++) {
            
            // if NULL for this column
            if ([rs columnIndexIsNull:i]) {
                
                continue;
            }
            
            NSString *columnName = [rs columnNameForIndex:i];
            
            objc_property_t property = class_getProperty(self, [columnName UTF8String]);
            
            id columnValue = [rs objectForColumnIndex:i];
            
            // NSDate
            if ([self typeOfProperty:property] == FOPropertyTypeDate) {
                
                [object setValue:[rs dateForColumnIndex:i] forKey:columnName];
            }
            // other types(classes)
            else {
                
                [object setValue:columnValue forKey:columnName];
            }
        }
        
        [object sync];
        [objects addObject:object];
    }
    
    return (objects.count) ? (objects) : (nil);
}

+(NSArray *)customObjectsFromResultSet:(FMResultSet *)rs class:(Class)objClass {
    
    NSMutableArray *objects = [NSMutableArray array];
    
    while ([rs next]) {
        
        id object = [[objClass alloc] init];
        
        int columnCount = sqlite3_column_count(rs.statement.statement);
        
        for (int i = 0; i < columnCount; i++) {
            
            // if NULL for this column
            if ([rs columnIndexIsNull:i]) {
                
                continue;
            }
            
            NSString *columnName = [rs columnNameForIndex:i];
            
            objc_property_t property = class_getProperty(objClass, [columnName UTF8String]);
            
            id columnValue = [rs objectForColumnIndex:i];
            
            // NSDate
            if ([self typeOfProperty:property] == FOPropertyTypeDate) {
                
                [object setValue:[rs dateForColumnIndex:i] forKey:columnName];
            }
            // other types(classes)
            else {
                
                [object setValue:columnValue forKey:columnName];
            }
        }
        
        [objects addObject:object];
    }
    
    return (objects.count) ? (objects) : (nil);
}

+(NSArray *)dictionariesFromResultSet:(FMResultSet *)rs {
    
    NSMutableArray *dics = [NSMutableArray array];
    while ([rs next]) {
        
        NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
        
        int columnCount = sqlite3_column_count(rs.statement.statement);
        
        for (int i = 0; i < columnCount; i++) {
            
            // if NULL for this column
            if ([rs columnIndexIsNull:i]) {
                
                continue;
            }
            
            [dic setObject:[rs objectForColumnIndex:i] forKey:[rs columnNameForIndex:i]];
        }
        
        [dics addObject:dic];
    }
    
    return (dics.count) ? ([dics copy]) : (nil);
}

-(void)loadPersistentObj:(FMDatabase *)db {
    
    Class selfClass = [self class];
    NSMutableString *sql = [NSMutableString stringWithFormat:@"select * from %@", [selfClass tableName]];
    NSMutableArray *args = [[NSMutableArray alloc] init];
    
    NSArray *pkNames = [selfClass pks:db];
    for (NSUInteger i = 0 ; i < pkNames.count ; i++) {
        
        NSString *pkName = [pkNames objectAtIndex:i];
        [args addObject:[self valueForKey:pkName]];
        
        if (i == 0) {
            
            [sql appendFormat:@" where %@=?", pkName];
        }
        else if (i < pkNames.count - 1) {
            
            [sql appendFormat:@" and %@=?", pkName];
        }
        else {
            [sql appendFormat:@" and %@=?;", pkName];
        }
    }
    
    FMResultSet *rs = [db executeQuery:[sql copy] withArgumentsInArray:[args copy]];
    _persistentObj = [[selfClass objectsFromResultSet:rs] firstObject];
}

-(BOOL)update:(FMDatabase *)db {
    
    Class selfClass = [self class];
    NSMutableString *sql = [NSMutableString stringWithFormat:@"update %@", [selfClass tableName]];
    NSMutableArray *args = [[NSMutableArray alloc] init];
    
    // assign clause
    NSArray *changedProps = [self changedProps];
    for (NSUInteger i = 0 ; i < changedProps.count ; i++) {
        
        NSString *propName = [changedProps objectAtIndex:i];
        id propValue = [self valueForKey:propName];
        
        if (propValue) {
            [args addObject:propValue];
        }
        else {
            [args addObject:[NSNull null]];
        }
        
        
        if (i == 0) {
            
            [sql appendFormat:@" set %@=?", propName];
        }
        else {
            
            [sql appendFormat:@", %@=?", propName];
        }
    }
    
    // where clause
    NSArray *pkNames = [selfClass pks:db];
    for (NSUInteger i = 0 ; i < pkNames.count ; i++) {
        
        NSString *pkName = [pkNames objectAtIndex:i];
        [args addObject:[_persistentObj valueForKey:pkName]];
        
        if (i == 0) {
            
            [sql appendFormat:@" where %@=?", pkName];
        }
        else if (i < pkNames.count - 1) {
            
            [sql appendFormat:@" and %@=?", pkName];
        }
        else {
            [sql appendFormat:@" and %@=?;", pkName];
        }
    }

    BOOL result = [db executeUpdate:[sql copy] withArgumentsInArray:[args copy]];
    if (result) {
        
        [self sync];
    }
    
    return result;
}

-(BOOL)insert:(FMDatabase *)db {
    
    Class selfClass = [self class];
    NSMutableString *sql = [NSMutableString stringWithFormat:@"insert into %@", [selfClass tableName]];
    NSMutableString *sqlCols = [[NSMutableString alloc] init];
    NSMutableString *sqlVals = [[NSMutableString alloc] init];
    NSMutableArray *args = [[NSMutableArray alloc] init];
    
    unsigned int outCount;
    objc_property_t *properties = class_copyPropertyList([self class], &outCount);
    for (unsigned int i = 0; i < outCount; i++) {
        
        objc_property_t property = properties[i];
        NSString *propName = [NSString stringWithUTF8String:property_getName(property)];
        id propValue = [self valueForKey:propName];
        
        if (!propValue) {
            if (i == outCount - 1) {
                [sqlCols appendFormat:@")"];
                [sqlVals appendFormat:@");"];
            }
            continue;
        }
        
        [args addObject:propValue];
        
        if (i == 0) {
            
            [sqlCols appendFormat:@" (%@", propName];
            [sqlVals appendFormat:@" values (?"];
        }
        else if (i < outCount - 1) {
            
            [sqlCols appendFormat:@", %@", propName];
            [sqlVals appendFormat:@", ?"];
        }
        else {
            
            [sqlCols appendFormat:@", %@)", propName];
            [sqlVals appendFormat:@", ?);"];
        }
    }
    free(properties);
    
    [sql appendString:sqlCols];
    [sql appendString:sqlVals];
    
    BOOL result = [db executeUpdate:[sql copy] withArgumentsInArray:[args copy]];
    if (result) {
        
        [self sync];
    }
    
    return result;
}

-(BOOL)remove:(FMDatabase *)db {
    
    Class selfClass = [self class];
    NSMutableString *sql = [NSMutableString stringWithFormat:@"delete from %@", [selfClass tableName]];
    NSMutableArray *args = [[NSMutableArray alloc] init];
    
    NSArray *pkNames = [selfClass pks:db];
    for (NSUInteger i = 0 ; i < pkNames.count ; i++) {
        
        NSString *pkName = [pkNames objectAtIndex:i];
        [args addObject:[_persistentObj valueForKey:pkName]];
        
        if (i == 0) {
            
            [sql appendFormat:@" where %@=?", pkName];
        }
        else if (i < pkNames.count - 1) {
            
            [sql appendFormat:@" and %@=?", pkName];
        }
        else {
            [sql appendFormat:@" and %@=?;", pkName];
        }
    }
    
    BOOL result = [db executeUpdate:[sql copy] withArgumentsInArray:[args copy]];
    if (result) {
        
        [self detach];
    }
    
    return result;
}

-(BOOL)persist:(FMDatabase *)db {
    
    if (!_persistentObj) {
        
        [self loadPersistentObj:db];
    }
    
    if (_persistentObj) {
        
        return [self update:db];
    }
    else {
        
        return [self insert:db];
    }
}

-(NSString *)description {

    NSMutableDictionary *descDict = [NSMutableDictionary dictionary];
    unsigned int outCount;
    objc_property_t *properties = class_copyPropertyList([self class], &outCount);
    for (unsigned int i = 0; i < outCount; i++) {
        objc_property_t property = properties[i];
        NSString *propName = [NSString stringWithUTF8String:property_getName(property)];
        id propValue = [self valueForKey:propName];
        [descDict setValue:propValue forKey:propName];
    }

    free(properties);
    
    return [NSString stringWithCString:[[descDict description] UTF8String] encoding:NSNonLossyASCIIStringEncoding];
}

-(id)copyWithZone:(NSZone *)zone {
    
    Class selfClass = [self class];
    id copy = [[selfClass allocWithZone:zone] init];
    
    unsigned int outCount;
    objc_property_t *properties = class_copyPropertyList(selfClass, &outCount);
    for (unsigned int i = 0; i < outCount; i++) {
        objc_property_t property = properties[i];
        NSString *propName = [NSString stringWithUTF8String:property_getName(property)];
        id propValue = [self valueForKey:propName];
        [copy setValue:propValue forKey:propName];
    }
    
    free(properties);
    
    return copy;
}

-(void)sync {
    
    _persistentObj = [self copy];
}

-(void)detach {
    
    _persistentObj = nil;
}

-(NSArray *)changedProps {
    
    NSMutableArray *changedProps = [[NSMutableArray alloc] init];
    Class selfClass = [self class];
    
    unsigned int outCount;
    objc_property_t *properties = class_copyPropertyList(selfClass, &outCount);
    for (unsigned int i = 0; i < outCount; i++) {
        objc_property_t property = properties[i];
        NSString *propName = [NSString stringWithUTF8String:property_getName(property)];
        id curValue = [self valueForKey:propName];
        id oriValue = [_persistentObj valueForKey:propName];
        
        switch ([selfClass typeOfProperty:property]) {
                
            case FOPropertyTypeNumber:
                if (![curValue isEqualToNumber:oriValue]) {
                    [changedProps addObject:propName];
                }
                break;
                
            case FOPropertyTypeString:
                if (![curValue isEqualToString:oriValue]) {
                    [changedProps addObject:propName];
                }
                break;
                
            case FOPropertyTypeDate:
                if (![curValue isEqualToDate:oriValue]) {
                    [changedProps addObject:propName];
                }
                break;
                
            case FOPropertyTypeData:
                if (![curValue isEqualToData:oriValue]) {
                    [changedProps addObject:propName];
                }
                break;
        }
    }
    
    free(properties);
    
    return [changedProps copy];
}

@end
