//
//  ViewController.m
//  Do_Test
//
//  Created by linliyuan on 15/4/27.
//  Copyright (c) 2015年 DoExt. All rights reserved.
//

#import "ViewController.h"
#import "doPage.h"
#import "doService.h"
#import "do_SQLite_MM.h"
#define DBNAME    @"personinfo.sqlite"
#define NAME      @"name"
#define AGE       @"age"
#define ADDRESS   @"address"
#define TABLENAME @"PERSONINFO"

@interface ViewController ()
{
@private
    NSString *Type;
    doModule* model;
}
@end
@implementation CallBackEvnet

-(void)eventCallBack:(NSString *)_data
{
    NSLog(@"异步方法回调数据:%@",_data);
}

@end
@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self InitInstance];
    [self ConfigUI];
    // Do any additional setup after loading the view, typically from a nib.
}
- (void) InitInstance
{
    NSString *testPath = [[NSBundle mainBundle] pathForResource:@"do_Test" ofType:@"json"];
    NSData *data = [NSData dataWithContentsOfFile:testPath];
    NSMutableDictionary *_testDics = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
    Type = [_testDics valueForKey:@"Type"];
    //如果是SM
    model = [[do_SQLite_MM alloc]init];
}
- (void)ConfigUI {
    CGFloat w = self.view.frame.size.width;
    CGFloat h = self.view.frame.size.height;
    //在对应的测试按钮添加自己的测试代码, 如果6个测试按钮不够，可以自己添加
    
    if([Type isEqualToString:@"UI"]){
        //和SM，MM不一样，UI类型还得添加自己的View，所以测试按钮都在底部
        CGFloat height = h/6;
        CGFloat width = (w - 35)/6;
        for(int i = 0;i<6;i++){
            UIButton *test = [UIButton buttonWithType:UIButtonTypeCustom];
            test.frame = CGRectMake(5*(i+1)+width*i, h-h/6, width, height);
            NSString* title = [NSString stringWithFormat:@"Test%d",i ];
            [test setTitle:title forState:UIControlStateNormal];
            SEL customSelector = NSSelectorFromString([NSString stringWithFormat:@"test%d:",i]);
            [test addTarget:self action:customSelector forControlEvents:UIControlEventTouchUpInside];
            [self.view addSubview:test];
        }
        //addsubview 自定义的UI
        
    }else{
        CGFloat height = (h-140)/6;
        CGFloat width = w - 60;
        for(int i = 0;i<6;i++){
            UIButton *test = [UIButton buttonWithType:UIButtonTypeCustom];
            test.frame = CGRectMake(30, 20*(i+1)+height*i, width, height);
            NSString* title = [NSString stringWithFormat:@"Test%d",i ];
            [test setTitle:title forState:UIControlStateNormal];
            SEL customSelector = NSSelectorFromString([NSString stringWithFormat:@"test%d:",i]);
            [test addTarget:self action:customSelector forControlEvents:UIControlEventTouchUpInside];
            [self.view addSubview:test];
        }
    }
}

- (void)test0:(UIButton *)sender
{
    NSLog(@"请添加自己的测试代码");
    NSMutableDictionary* node = [[NSMutableDictionary alloc]init];
    [node setObject:@"data://1.db" forKey:@"path"];
    [[doService Instance] SyncMethod:model :@"open" :node];
    [node removeAllObjects];
    NSString *sqlCreateTable = @"CREATE TABLE IF NOT EXISTS PERSONINFO (ID INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, age INTEGER, address TEXT)";
    NSString *sql1 = [NSString stringWithFormat:
                      @"INSERT INTO '%@' ('%@', '%@', '%@') VALUES ('%@', '%@', '%@')",
                      TABLENAME, NAME, AGE, ADDRESS, @"张三", @"23", @"西城区"];
    
    NSString *sql2 = [NSString stringWithFormat:
                      @"INSERT INTO '%@' ('%@', '%@', '%@') VALUES ('%@', '%@', '%@')",
                      TABLENAME, NAME, AGE, ADDRESS, @"老六", @"20", @"东城区"];
    
    [node setObject:sqlCreateTable forKey:@"sql"];
    [[doService Instance] SyncMethod:model :@"executeSync" :node];
    [node removeAllObjects];
    [node setObject:sql1 forKey:@"sql"];
    [[doService Instance] SyncMethod:model :@"executeSync" :node];
    [node removeAllObjects];
    [node setObject:sql2 forKey:@"sql"];
    [[doService Instance] SyncMethod:model :@"executeSync" :node];
    
    [node removeAllObjects];
    [[doService Instance] SyncMethod:model :@"close" :node];
}
- (void)test1:(UIButton *)sender
{
    NSLog(@"请添加自己的测试代码");
    NSMutableDictionary* node = [[NSMutableDictionary alloc]init];
    [node setObject:@"data://1.db" forKey:@"path"];
    [[doService Instance] SyncMethod:model :@"open" :node];
    
    [node removeAllObjects];
    NSString *sql = [NSString stringWithFormat:
                      @"select * from '%@'",                      TABLENAME];
    [node setObject:sql forKey:@"sql"];
    CallBackEvnet* event = [[CallBackEvnet alloc]init];
    [[doService Instance] AsyncMethod:model :@"query" :node :event ];
    
    [node removeAllObjects];
    [[doService Instance] SyncMethod:model :@"close" :node];
}
- (void)test2:(UIButton *)sender
{
    NSLog(@"请添加自己的测试代码");
}
- (void)test3:(UIButton *)sender
{
    NSLog(@"请添加自己的测试代码");
}
- (void)test4:(UIButton *)sender
{
    NSLog(@"请添加自己的测试代码");
}
- (void)test5:(UIButton *)sender
{
    NSLog(@"请添加自己的测试代码");
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
