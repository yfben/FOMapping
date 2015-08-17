//
//  FOObject.m
//  FOMapping
//
//  Created by tradevan on 2015/7/17.
//  Copyright (c) 2015年 tradevan. All rights reserved.
//

#import <objc/message.h>
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

static NSArray *_pks = NULL;
+(NSArray *)pks:(FMDatabase *)db {
    
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        
        Class selfClass = [self class];
        NSString *tableName = [selfClass tableName];
        
        if (![db open]) {
            
            NSString *reason = [NSString stringWithFormat:@"Fail to open database at path:%@.", db.databasePath];
            NSException* exception = [NSException exceptionWithName:@"FailToOpenDBException"
                                                             reason:reason userInfo:nil];
            @throw exception;
        }
        
        FMResultSet *rs = [db executeQuery:[NSString stringWithFormat:@"pragma table_info(%@);", tableName]];
        
        NSMutableArray *pks = [[NSMutableArray alloc] init];
        while ([rs next]) {
            
            NSString *colName = [rs stringForColumn:@"name"];
            
            if (!class_getProperty(selfClass, [colName UTF8String])) {
                
                NSString *reason = [NSString stringWithFormat:@"Property '%@' not found in class %@.", colName, NSStringFromClass(selfClass)];
                NSException* exception = [NSException exceptionWithName:@"PropertyNotFoundException"
                                                                 reason:reason userInfo:nil];
                @throw exception;
            }
            
            if ([rs boolForColumn:@"pk"]) {
                
                [pks addObject:colName];
            }
        }
        
        if (pks.count < 1) {
            
            NSString *reason = [NSString stringWithFormat:@"%@ should have at least 1 primary key.", tableName];
            NSException* exception = [NSException exceptionWithName:@"PrimaryKeyNotFoundException"
                                                             reason:reason userInfo:nil];
            @throw exception;
            
        }
        
        _pks = [pks copy];
    });
    
    return _pks;
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
    
    // NSInteger or NSUInteger
    if ([typeString isEqualToString:@"Ti"] || [typeString isEqualToString:@"TI"]) {
        
        return FOPropertyTypeNumber;
    }
    // double or float
    else if ([typeString isEqualToString:@"Td"] || [typeString isEqualToString:@"Tf"]) {
        
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
        NSException* exception = [NSException exceptionWithName:@"FOPropertyTypeNotDeterminedException"
                                                         reason:reason userInfo:nil];
        @throw exception;
    }
}

+(instancetype)objectWithResultSet:(FMResultSet *)rs {
    
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
    
    return object;
}

+(NSDictionary *)dictionaryWithResultSet:(FMResultSet *)rs {
    
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    
    int columnCount = sqlite3_column_count(rs.statement.statement);
    
    for (int i = 0; i < columnCount; i++) {
        
        // if NULL for this column
        if ([rs columnIndexIsNull:i]) {
            
            continue;
        }
        
        [dict setObject:[rs objectForColumnIndex:i] forKey:[rs columnNameForIndex:i]];
    }
    
    return [dict copy];
}

-(BOOL)update:(FMDatabase *)db {
    
    Class selfClass = [self class];
    NSMutableString *sql = [NSMutableString stringWithFormat:@"update %@", [selfClass tableName]];
    NSMutableArray *args = [[NSMutableArray alloc] init];
    
    // assign clause
    NSArray *changedProps = [self changedProps];
    for (NSUInteger i = 0 ; i < changedProps.count ; i++) {
        
        NSString *propName = [changedProps objectAtIndex:i];
        [args addObject:[self valueForKey:propName]];
        
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

-(BOOL)save:(FMDatabase *)db {
    
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
        
        [args addObject:[self valueForKey:propName]];
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
