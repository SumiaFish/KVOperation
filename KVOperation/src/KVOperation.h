//
//  KVOperation.h
//  KVOperation
//
//  Created by kevin on 2020/5/24.
//  Copyright © 2020 kevin. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#ifdef DEBUG
#define KVQLog(format,...) { \
printf("\n%s #%d: \n", __func__, __LINE__); \
printf("%s\n", [NSString stringWithFormat:(format), ##__VA_ARGS__].UTF8String); \
NSLog(@"\n\n"); \
}
#else
#define KVQLog(...)
#endif

@class KVOperationQueue;

@interface KVOperation : NSOperation

@property (assign, nonatomic, readonly) NSString *tid;
@property (assign, nonatomic) BOOL isCompleteOnMainQueue;
@property (weak, nonatomic, nullable, readonly) KVOperationQueue *queue;

- (KVOperation *)todoTask:(void (^ _Nullable) (KVOperation *op))task;
- (void)completeTask:(void (^ _Nullable) (KVOperation *op))task;
- (void)finish;

@end

@interface KVOperationQueue : NSObject

- (void)addOperations:(NSArray<KVOperation *> *)ops;
- (void)suspended:(BOOL)isSuspended;
- (void)cancelAllOperations;
- (void)completeTask:(void (^ _Nullable) (KVOperationQueue *queue))task;

+ (void)onGlobalQueue:(void (^) (void))block;
+ (void)synchronized:(NSObject *)token block:(void (^)(void))block;

@end

@interface KVOperationQueue (Convenient)

+ (instancetype)queueWithOperations:(NSArray<KVOperation *> *)ops;

+ (KVOperation *)operationWithTodo:(void (^ _Nullable) (KVOperation *op))todo complete:(void (^ _Nullable) (KVOperation *op))complete;

@end

NS_ASSUME_NONNULL_END
