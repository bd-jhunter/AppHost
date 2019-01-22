//
//  AHResponseManager.m
//  AppHost
//
//  Created by liang on 2019/1/22.
//  Copyright © 2019 liang. All rights reserved.
//

#import "AHResponseManager.h"
#import<pthread.h>

@interface AHResponseManager ()

// 以下是注册 response 使用的属性

/**
 自定义response类
 */
@property (nonatomic, strong, readwrite) NSMutableArray *customResponseClasses;
/**
 response类的 实例的缓存。
 */
@property (nonatomic, strong) NSMutableDictionary *responseClassObjs;

@end

@implementation AHResponseManager

+(instancetype)defaultManager
{
    static dispatch_once_t onceToken;
    static AHResponseManager *kResponeManger = nil;
    dispatch_once(&onceToken, ^{
        kResponeManger = [AHResponseManager new];
        
        kResponeManger.responseClassObjs = [NSMutableDictionary dictionaryWithCapacity:10];
        kResponeManger.customResponseClasses = [NSMutableArray arrayWithCapacity:10];
        
        // 静态注册 可响应的类
        NSArray<NSString *> *responseClassNames = @[
                                                    @"AHNavigationResponse",
                                                    @"AHNavigationBarResponse",
                                                    @"AHBuiltInResponse",
                                                    @"AHAppLoggerResponse"];
        [responseClassNames enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [kResponeManger.customResponseClasses addObject:NSClassFromString(obj)];
        }];
    });
    
    return kResponeManger;
}

#pragma mark - public

- (void)addCustomResponse:(id<AppHostProtocol>)cls
{
    if (cls) {
        [self.customResponseClasses addObject:cls];
    }
}

- (id<AppHostProtocol>)responseForAction:(NSString *)action withAppHost:(AppHostViewController *)appHost
{
    id<AppHostProtocol> vc = nil;
    // 逆序遍历，让后添加的 Response 能够覆盖内置的方法；
    for (NSInteger i = self.customResponseClasses.count - 1; i >= 0; i--) {
        Class responseClass = [self.customResponseClasses objectAtIndex:i];
        if ([responseClass isSupportedAction:action]) {
            // 先判断是否可以响应，再决定初始化。
            NSString *key = NSStringFromClass(responseClass);
            vc = [self.responseClassObjs objectForKey:key];
            if (vc == nil) {
                vc = [[responseClass alloc] initWithAppHost:appHost];
                // 缓存住
                [self.responseClassObjs setObject:vc forKey:key];
            }
            break;
        }
    }
    
    return vc;
}

#ifdef DEBUG

/**
 //TODO: 缓存
 */
static NSDictionary *kAllResponseMethods = nil;
static pthread_mutex_t lock;
- (NSDictionary *)allResponseMethods
{
    pthread_mutex_init(&lock, NULL);
    pthread_mutex_lock(&lock);
    if (kAllResponseMethods) {
        pthread_mutex_unlock(&lock);
        return kAllResponseMethods;
    }
    
    kAllResponseMethods = [NSMutableDictionary dictionaryWithCapacity:10];
    //
    for (NSInteger i = 0; i < self.customResponseClasses.count; i++) {
        Class responseClass = [self.customResponseClasses objectAtIndex:i];
        NSMutableArray *methods = [NSMutableArray arrayWithCapacity:10];
        [[responseClass supportActionList] enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSString * _Nonnull obj, BOOL * _Nonnull stop) {
            if ([obj integerValue] > 0) {
                [methods addObject:key];
            }
        }];
        
        if (methods.count > 0) {
            [kAllResponseMethods setValue:methods forKey:NSStringFromClass(responseClass)];
        }
    }
    
    pthread_mutex_unlock(&lock);
    return kAllResponseMethods;
}

#endif

-(void)dealloc
{
    // 清理 response
    [self.responseClassObjs enumerateKeysAndObjectsUsingBlock:^(NSString *key, id _Nonnull obj, BOOL *_Nonnull stop) {
        obj = nil;
    }];
    [self.responseClassObjs removeAllObjects];
    self.responseClassObjs = nil;
    
}
@end
