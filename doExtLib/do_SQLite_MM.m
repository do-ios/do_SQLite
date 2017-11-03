//
//  do_SQLite_MM.m
//  DoExt_MM
//
//  Created by @userName on @time.
//  Copyright (c) 2015年 DoExt. All rights reserved.
//

#import "do_SQLite_MM.h"

#import "doScriptEngineHelper.h"
#import "doIScriptEngine.h"
#import "doInvokeResult.h"
#import <sqlite3.h>
#import "doJsonHelper.h"
#import "doIScriptEngine.h"
#import "doIApp.h"
#import "doIDataFS.h"
#import "doIOHelper.h"
#import "doServiceContainer.h"
#import "doILogEngine.h"

@implementation do_SQLite_MM
{
    @private
    sqlite3 *dbConnection;
}
#pragma mark - 注册属性（--属性定义--）
/*
 [self RegistProperty:[[doProperty alloc]init:@"属性名" :属性类型 :@"默认值" : BOOL:是否支持代码修改属性]];
 */
-(void)OnInit
{
    [super OnInit];
    //注册属性
}

//销毁所有的全局对象
-(void)Dispose
{
    sqlite3_close(dbConnection);
    dbConnection = nil;
}
#pragma mark -
#pragma mark - 同步异步方法的实现
/*
 1.参数节点
 NSDictionary *_dictParas = [parms objectAtIndex:0];
 a.在节点中，获取对应的参数
 NSString *title = [doJsonHelper GetOneText: _dictParas :@"title" :@"" ];
 说明：第一个参数为对象名，第二为默认值
 
 2.脚本运行时的引擎
 id<doIScriptEngine> _scritEngine = [parms objectAtIndex:1];
 
 同步：
 3.同步回调对象(有回调需要添加如下代码)
 doInvokeResult *_invokeResult = [parms objectAtIndex:2];
 回调信息
 如：（回调一个字符串信息）
 [_invokeResult SetResultText:((doUIModule *)_model).UniqueKey];
 异步：
 3.获取回调函数名(异步方法都有回调)
 NSString *_callbackName = [parms objectAtIndex:2];
 在合适的地方进行下面的代码，完成回调
 新建一个回调对象
 doInvokeResult *_invokeResult = [[doInvokeResult alloc] init];
 填入对应的信息
 如：（回调一个字符串）
 [_invokeResult SetResultText: @"异步方法完成"];
 [_scritEngine Callback:_callbackName :_invokeResult];
 */
//同步
 - (void)close:(NSArray *)parms
 {
     sqlite3_close(dbConnection);
     dbConnection = nil;
     doInvokeResult *_invokeResult = [parms objectAtIndex:2];
     if (!dbConnection) {
         [_invokeResult SetResultBoolean:YES];
     }
     else
     {
         [_invokeResult SetResultBoolean:NO];
     }
     //自己的代码实现
 }
 - (void)open:(NSArray *)parms
 {
     NSDictionary *_dictParas = [parms objectAtIndex:0];
     id<doIScriptEngine> _scritEngine = [parms objectAtIndex:1];
     doInvokeResult *_invokeResult = [parms objectAtIndex:2];
     
     NSString* dbPath = [doJsonHelper GetOneText: _dictParas :@"path" :@":memory:" ];
     NSString* dbName = dbPath;
     //只支持:memory: 或者data://打头
     if(![dbPath isEqualToString:@":memory:"])
     {
         dbName = [_scritEngine.CurrentApp.DataFS GetFileFullPathByName:dbPath];
     }
     NSString* path = [dbName stringByDeletingLastPathComponent];
     if(![doIOHelper ExistDirectory:path] )
        [doIOHelper CreateDirectory:path];
     int result = sqlite3_open_v2([dbName UTF8String], &dbConnection,SQLITE_OPEN_FULLMUTEX | SQLITE_OPEN_READWRITE|SQLITE_OPEN_CREATE,NULL);
     if (result == SQLITE_OK) {
         // 创建打开成功
         [_invokeResult SetResultBoolean:YES];
     }else{
         //创建或者打开失败
         [_invokeResult SetResultBoolean:NO];
     }
 }
#pragma mark - execute

//同步
- (void)executeSync:(NSArray *)parms
{
    [self executeSql:parms :YES];
}
//同步，支持事务
- (void)executeSync1:(NSArray *)parms
{
    [self executeSql1:parms :YES];
}
//异步
- (void)execute:(NSArray *)parms
{
    [self executeSql:parms :NO];
}
//异步，支持事务
- (void)execute1:(NSArray *)parms
{
    //异步耗时操作，但是不需要启动线程，框架会自动加载一个后台线程处理这个函数
    [self executeSql1:parms :NO];
}

- (void)executeSql:(NSArray *)parms :(BOOL)isSync
{
    NSDictionary *_dictParas = [parms objectAtIndex:0];
    doInvokeResult *_invokeResult;
    if (isSync) {
        _invokeResult = [parms objectAtIndex:2];
    }else
        _invokeResult = [doInvokeResult new];
    
    //自己的代码实现
    NSString* sqlString = [doJsonHelper GetOneText: _dictParas :@"sql" :@"" ];
    NSArray *bind = [doJsonHelper GetOneArray:_dictParas :@"bind"];
    int result;
    if (bind.count >0) {
        sqlite3_stmt *stmt;
        if (sqlite3_prepare_v2(dbConnection, [sqlString UTF8String], -1, &stmt, NULL) == SQLITE_OK) {
            [self bind:bind withStmt:stmt];
        }
        result = sqlite3_step(stmt);
        sqlite3_finalize(stmt);
    }
    else
    {
        result = sqlite3_exec(dbConnection, [sqlString UTF8String], NULL, NULL, NULL);
    }
    if (result == SQLITE_OK) {
        //sql 执行成功
        [_invokeResult SetResultBoolean:YES];
    }
    else if (result == SQLITE_DONE)
    {
        [_invokeResult SetResultBoolean:YES];
    }
    else if (result == SQLITE_CONSTRAINT)
    {
        sqlite3_exec(dbConnection, "rollback", NULL, NULL, NULL);
    }
    else{
        //sql 执行失败
        [_invokeResult SetResultBoolean:NO];
    }
    if (!isSync) {
        [self fireEvent:parms :_invokeResult];
    }
}
- (void)bind:(NSArray *)parms withStmt:(sqlite3_stmt *)pStmt
{
    int idx = 1;//参数绑定从1开始
    for (id obj in parms) {
        if ((!obj) || ((NSNull *)obj == [NSNull null])) {
            sqlite3_bind_null(pStmt, idx);
        }
        else if ([obj isKindOfClass:[NSData class]]) {
            const void *bytes = [obj bytes];
            if (!bytes) {
                // it's an empty NSData object, aka [NSData data].
                // Don't pass a NULL pointer, or sqlite will bind a SQL null instead of a blob.
                bytes = "";
            }
            sqlite3_bind_blob(pStmt, idx, bytes, (int)[obj length], SQLITE_STATIC);
        }
        else if ([obj isKindOfClass:[NSDate class]]) {
//            if (self.hasDateFormatter)
//                sqlite3_bind_text(pStmt, idx, [[self stringFromDate:obj] UTF8String], -1, SQLITE_STATIC);
//            else
                sqlite3_bind_double(pStmt, idx, [obj timeIntervalSince1970]);
        }
        else if ([obj isKindOfClass:[NSNumber class]]) {
            
            if (strcmp([obj objCType], @encode(char)) == 0) {
                sqlite3_bind_int(pStmt, idx, [obj charValue]);
            }
            else if (strcmp([obj objCType], @encode(unsigned char)) == 0) {
                sqlite3_bind_int(pStmt, idx, [obj unsignedCharValue]);
            }
            else if (strcmp([obj objCType], @encode(short)) == 0) {
                sqlite3_bind_int(pStmt, idx, [obj shortValue]);
            }
            else if (strcmp([obj objCType], @encode(unsigned short)) == 0) {
                sqlite3_bind_int(pStmt, idx, [obj unsignedShortValue]);
            }
            else if (strcmp([obj objCType], @encode(int)) == 0) {
                sqlite3_bind_int(pStmt, idx, [obj intValue]);
            }
            else if (strcmp([obj objCType], @encode(unsigned int)) == 0) {
                sqlite3_bind_int64(pStmt, idx, (long long)[obj unsignedIntValue]);
            }
            else if (strcmp([obj objCType], @encode(long)) == 0) {
                sqlite3_bind_int64(pStmt, idx, [obj longValue]);
            }
            else if (strcmp([obj objCType], @encode(unsigned long)) == 0) {
                sqlite3_bind_int64(pStmt, idx, (long long)[obj unsignedLongValue]);
            }
            else if (strcmp([obj objCType], @encode(long long)) == 0) {
                sqlite3_bind_int64(pStmt, idx, [obj longLongValue]);
            }
            else if (strcmp([obj objCType], @encode(unsigned long long)) == 0) {
                sqlite3_bind_int64(pStmt, idx, (long long)[obj unsignedLongLongValue]);
            }
            else if (strcmp([obj objCType], @encode(float)) == 0) {
                sqlite3_bind_double(pStmt, idx, [obj floatValue]);
            }
            else if (strcmp([obj objCType], @encode(double)) == 0) {
                sqlite3_bind_double(pStmt, idx, [obj doubleValue]);
            }
            else if (strcmp([obj objCType], @encode(BOOL)) == 0) {
                sqlite3_bind_int(pStmt, idx, ([obj boolValue] ? 1 : 0));
            }
            else {
                sqlite3_bind_text(pStmt, idx, [[obj description] UTF8String], -1, SQLITE_STATIC);
            }
        }
        else {
            sqlite3_bind_text(pStmt, idx, [[obj description] UTF8String], -1, SQLITE_STATIC);
        }
        idx ++;
    }
}

#pragma mark - query

- (void)query:(NSArray *)parms
{
    [self queryData:parms :NO];
}

- (void)querySync:(NSArray *)parms
{
    [self queryData:parms :YES];
}

- (void)queryData:(NSArray *)parms :(BOOL)isSync
{
    NSDictionary *_dictParas = [parms objectAtIndex:0];
    doInvokeResult *_invokeResult ;
    if (isSync) {
        _invokeResult = [parms objectAtIndex:2];
    }else
        _invokeResult = [doInvokeResult new];
      
    //自己的代码实现
    NSString* sqlString = [doJsonHelper GetOneText: _dictParas :@"sql" :@"" ];
    NSArray *bind = [doJsonHelper GetOneArray:_dictParas :@"bind"];
    sqlite3_stmt *statement;
    NSMutableArray* _array = [[NSMutableArray alloc] initWithCapacity:0];
    @try {
        int result = sqlite3_prepare_v2(dbConnection, [sqlString UTF8String], -1, &statement, nil);
        if (result == SQLITE_OK) {
            //绑定参数
            if (bind.count > 0) {
                [self bind:bind withStmt:statement];
            }
            //查询成功
            int columnCount = sqlite3_column_count(statement);
            while (sqlite3_step(statement) == SQLITE_ROW)
            {
                NSMutableDictionary * node = [[NSMutableDictionary alloc]init];
                for(int i = 0;i<columnCount;i++){
                    const char *_columnName=sqlite3_column_name(statement, i);
                    NSString *columnName=[[NSString alloc] initWithUTF8String:_columnName];
                    
                    char *_rowData = (char *)sqlite3_column_text(statement, i);
                    if (_rowData) {
                        NSString *rowData = [[NSString alloc] initWithUTF8String:_rowData];
                        [node setObject:rowData forKey:columnName];
                    }
                }
                [_array addObject:node];
            }
            [_invokeResult SetResultArray:_array];
        }else{
            [[doServiceContainer Instance].LogEngine WriteError:nil : @"表不存在或数据库打开失败"];
        }
    }
    @catch (NSException *exception) {
        [[doServiceContainer Instance].LogEngine WriteError:exception : @"SQLite查询失败"];
        [_invokeResult SetException:exception];
    }
    @finally {
        sqlite3_finalize(statement);
    }
    if (!isSync) {
        [self fireEvent:parms :_invokeResult];
    }
}



#pragma mark -私有方法

- (void)fireEvent:(NSArray *)parms :(doInvokeResult *)_invokeResult
{
    NSString *_callbackName = [parms objectAtIndex:2];
    id<doIScriptEngine> _scritEngine = [parms objectAtIndex:1];
    [_scritEngine Callback:_callbackName :_invokeResult];
}
- (BOOL)insertTable:(NSString *)sqlStr
{
    NSArray *sqlS = [sqlStr componentsSeparatedByString:@";"];
    @try{
        char *errorMsg;
        if (sqlite3_exec(dbConnection, "BEGIN", NULL, NULL, &errorMsg)==SQLITE_OK)
        {
            NSLog(@"启动事务成功");
            sqlite3_free(errorMsg);
            sqlite3_stmt *statement;
            for (NSString *sql in sqlS)
            {
                NSLog(@"sqlStr====%@",sql);
                if(!sql || sql.length==0)
                    continue;
                if (sqlite3_prepare_v2(dbConnection,[sql UTF8String], -1, &statement,NULL)==SQLITE_OK)
                {
                    if (sqlite3_step(statement)!=SQLITE_DONE)
                    {
                        sqlite3_finalize(statement);
                        NSException *ex = [[NSException alloc]initWithName:@"inser执行错误" reason:nil userInfo:nil];
                        @throw (ex);
                    }
                }
            }
        }
        else{
            sqlite3_free(errorMsg);
            return NO;
        }
        if (sqlite3_exec(dbConnection, "COMMIT", NULL, NULL, &errorMsg)==SQLITE_OK)
        {
            NSLog(@"提交事务成功");
            sqlite3_free(errorMsg);
            return YES;
        }
    }
    @catch(NSException *e)
    {
        char *errorMsg;
        if (sqlite3_exec(dbConnection, "ROLLBACK", NULL, NULL, &errorMsg)==SQLITE_OK)  NSLog(@"回滚事务成功");
        sqlite3_free(errorMsg);
        return NO;
    }
}
//执行sql语句，支持事务
- (void)executeSql1:(NSArray *)parms :(BOOL)isSync
{
    NSDictionary *_dictParas = [parms objectAtIndex:0];
    doInvokeResult *_invokeResult;
    if (isSync)
    {
        _invokeResult = [parms objectAtIndex:2];
    }
    else
    {
        _invokeResult = [doInvokeResult new];
    }
    NSArray *sqls = [doJsonHelper GetOneArray:_dictParas :@"sqls"];
    BOOL isTransaction = [doJsonHelper GetOneBoolean:_dictParas :@"isTransaction" :NO];
    char *errorMsg;
    int affectedRows = 0;
    //支持事务
    if (isTransaction)
    {
        @try {
            int result = sqlite3_exec(dbConnection, "BEGIN", NULL, NULL, &errorMsg);
            if (result == SQLITE_OK)
            {
                sqlite3_free(errorMsg);
                sqlite3_stmt *statement;
                for (NSString *sql in sqls) {
                    if(!sql || sql.length==0)
                        continue;
                    if (sqlite3_prepare_v2(dbConnection,[sql UTF8String], -1, &statement,NULL)==SQLITE_OK)
                    {
                        int stepResult = sqlite3_step(statement);
                        int change = sqlite3_changes(dbConnection);
                        affectedRows +=change;
                        if (stepResult!=SQLITE_DONE)
                        {
                            sqlite3_finalize(statement);
                            NSString *errorMsg = [NSString stringWithFormat:@"%@执行出错",sql];
                            NSException *ex = [[NSException alloc]initWithName:@"do_Sqlite" reason:errorMsg userInfo:nil];
                            @throw (ex);
                        }
                    }
                }
            }
            else
            {
                affectedRows = 0;
            }
            if (sqlite3_exec(dbConnection, "COMMIT", NULL, NULL, &errorMsg)==SQLITE_OK)
            {
                NSLog(@"提交事务成功");
                sqlite3_free(errorMsg);
            }
        }
        @catch (NSException *exception) {
            [[doServiceContainer Instance].LogEngine WriteError:exception :nil];
            if (sqlite3_exec(dbConnection, "ROLLBACK", NULL, NULL, &errorMsg)==SQLITE_OK)  NSLog(@"回滚事务成功");
            sqlite3_free(errorMsg);
            affectedRows = 0;
        }
        [_invokeResult SetResultInteger:affectedRows];
    }
    else//不支持事务
    {
        @try {
            for (NSString *sql in sqls) {
                if(!sql || sql.length==0)
                    continue;
                int result = sqlite3_exec(dbConnection, [sql UTF8String], NULL, NULL, NULL);
                if (result == SQLITE_OK) {
                    int change = sqlite3_changes(dbConnection);
                    affectedRows += change;
                }
                else
                {
                    NSString *errorMsg = [NSString stringWithFormat:@"%@执行出错",sql];
                    NSException *ex = [[NSException alloc]initWithName:@"do_Sqlite" reason:errorMsg userInfo:nil];
                    @throw (ex);
                }
            }
            [_invokeResult SetResultInteger:affectedRows];
        }
        @catch (NSException *exception) {
            [[doServiceContainer Instance].LogEngine WriteError:exception :nil];
            [_invokeResult SetResultInteger:affectedRows];
        }
    }
    if (!isSync) {
        [self fireEvent:parms :_invokeResult];
    }
}

@end