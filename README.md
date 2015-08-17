FOMapping
=======

A simple ORM(Object-Relational-Mapping) extension of [ccgus](https://github.com/ccgus)'s fantastic SQLite  Objective-C wrapper [FMDB](https://github.com/ccgus/fmdb). [FMDB](https://github.com/ccgus/fmdb) is awesome, but it's more convenient to have some object instances to represent what we have in the database.

## Beta status
I develop my iOS Apps with this project when I have to deal with SQLite. If you come accross any problems. Please let me know.

## Requirements
* [FMDB](https://github.com/ccgus/fmdb)

## Table-to-object mapping
Say you have a table named Batter recording some baseball player's batting data.

```SQL
CREATE TABLE batter (
    name	    TEXT NOT NULL,
	avg 	    REAL,
	hr  	    INTEGER,
	birth	    REAL,
	position    BLOB,
	PRIMARY KEY(name)
);
```

Then you just create a class subclassing the **FOObject** class.

```obj-c
#import "FOObject.h"

@interface Batter : FOObject

@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) double avg;
@property (nonatomic, assign) NSInteger hr;
@property (nonatomic) NSData *birth;
@property (nonatomic) NSData *position;

@end
```

And make sure the following happens:

1. The table must have at least 1 primary key used to update or delete a certain row.
2. Override the **+tableName;** class method to specify the corresponding table.

## Property types
* *NSInteger* for INTEGER in SQLite
* *double* for REAL in SQLite
* *NSString* for TEXT in SQLite
* *NSData* for BLOB in SQLite
* *NSDate* for those data represeting dates in SQLite, either in
    1. REAL, the number of seconds since 1970-01-01 00:00:00 UTC
    2. TEXT, comliant to the FMDatabase's date formatter
    
## Query, update and delete
```obj-c
FMResultSet *rs = [db executeQuery:@"SELECT * from batter"];
while ([rs next]) {
    
    Batter *batter = [Batter objectWithResultSet:rs];

    if ([batter.name isEqualToString:@"Lin"]) {
        
        batter.avg = 0.300;
        batter.hr = 20;
        batter.birth = [NSDate dateWithTimeIntervalSinceNow:500515200];
        break;
    }
    else if ([batter.name isEqualToString:@"Hu"]) {
                
        [batter remove:db];    
        break;
    }
}
```

##Insert
```obj-c
Batter *newBatter = [[Batter alloc] init];
newBatter.name = @"Kao";
newBatter.avg = 0.35;
newBatter.hr = 30;
newBatter.birth = [NSDate dateWithTimeIntervalSinceNow:496540800];
[newBatter save:db];
```

##Keep temporary query
Sometimes we need to store a temporary query result which does not have a corresponding class. It's time to use NSDictionary.
```obj-c
FMResultSet *rs = [db executeQuery:@"select name as name1, avg as avg1, hr as hr1 from batter;"];
NSArray *results = [[NSMutableArray allolc] init];
while ([rs next]) {
    
    [results addObject:[FOObject dictionaryWithResultSet:rs]];
}
```

And that's all. Pleasure to have your time.