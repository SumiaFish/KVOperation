//
//  KVOperation.h
//  KVOperation
//
//  Created by kevin on 2020/5/24.
//  Copyright © 2020 kevin. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class KVOperationQueue;

@interface KVOperation : NSOperation

@property (assign, nonatomic, readonly) NSString *tid;
@property (assign, nonatomic, readonly) BOOL isCompleteOnMainQueue;
@property (weak, nonatomic, nullable, readonly) KVOperationQueue *queue;

- (KVOperation *)todoTask:(void (^ _Nullable) (KVOperation *op))task;
- (void)completeTask:(void (^ _Nullable) (KVOperation *op))task;
- (void)finish;

@end

@interface KVOperationQueue : NSObject

- (void)addOperation:(KVOperation *)op;
- (void)suspended:(BOOL)isSuspended;
- (void)cancelAllOperations;
+ (void)onGlobalQueue:(void (^) (void))block;
+ (void)synchronized:(NSObject *)token block:(void (^)(void))block;

@end

NS_ASSUME_NONNULL_END
