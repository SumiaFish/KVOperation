//
//  KVOperation.m
//  KVOperation
//
//  Created by kevin on 2020/5/24.
//  Copyright © 2020 kevin. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "KVOperation.h"

@class KVOperation;
@class KVOperationQueue;
@class KVQueues;
@class KVRWQueues;

static NSInteger const KVQueuesLimit = 32;

typedef NS_ENUM(NSInteger, KVOperationTaskMode) {
    KVOperationTaskMode_Todo,
    KVOperationTaskMode_Complete,
};

@protocol KVOperationDelegate <NSObject>

- (void)onTodo:(KVOperation *)op;

- (void)onComplete:(KVOperation *)op done:(void (^) (void))done;

@end

@interface KVOperation ()
{
    @private BOOL _isExecuting;
    @private BOOL _isFinished;
    
    @private dispatch_semaphore_t _sem;
    @private dispatch_semaphore_t _todosem;
    
    @private BOOL _willCallback;
}

@property (copy, nonatomic, nullable) void (^ todo) (KVOperation *op);
@property (copy, nonatomic, nullable) void (^ complete) (KVOperation *op);

@property (weak, nonatomic, nullable) id<KVOperationDelegate> delegate;

@end

@implementation KVOperation

- (void)dealloc {
    KVQLog(@"KVOperation dealloc~");
}

- (void)set_isExecuting:(BOOL)isExecuting {
    [self willChangeValueForKey:@"isExecuting"];
    _isExecuting = isExecuting;
    [self didChangeValueForKey:@"isExecuting"];
}

- (BOOL)isExecuting {
    return _isExecuting;
}

- (void)set_isFinished:(BOOL)isFinished {
    [self willChangeValueForKey:@"isFinished"];
    _isFinished = isFinished;
    [self didChangeValueForKey:@"isFinished"];
}

- (BOOL)isFinished {
    return _isFinished;
}

- (void)setQueue:(KVOperationQueue *)queue {
    _queue = queue;
}

- (instancetype)init {
    if (self = [super init]) {
        _tid = NSUUID.UUID.UUIDString;
        _sem = dispatch_semaphore_create(1);
        _todosem = dispatch_semaphore_create(1);
    }
    return self;
}

- (void)start {
    
    NSAssert(self.delegate && self.queue, @"You do not have to start manually, please add the operation to the queue, which is responsible for starting the call");
    
    dispatch_semaphore_wait(_todosem, DISPATCH_TIME_FOREVER);
    
    if (self.isFinished || self.isExecuting) {
        dispatch_semaphore_signal(_todosem);
        return;
    }
    
    self._isExecuting = YES;
    [self.delegate onTodo:self];
    
    dispatch_semaphore_signal(_todosem);
}

- (void)cancel {
    dispatch_semaphore_wait(_sem, DISPATCH_TIME_FOREVER);
    
    if (self.isFinished || _willCallback) {
        dispatch_semaphore_signal(_sem);
        return;
    }
    
    _willCallback = YES;
    if (self.delegate) {
        __weak typeof(self) ws = self;
        [self.delegate onComplete:self done:^{
            [ws super_calcel];
            ws._isFinished = YES;
        }];
    } else {
        [self super_calcel];
        self._isFinished = YES;
    }
    
    dispatch_semaphore_signal(_sem);
}

- (void)super_calcel {
    [super cancel];
}

- (void)finish {
    dispatch_semaphore_wait(_sem, DISPATCH_TIME_FOREVER);
    
    if (self.isFinished || _willCallback) {
        dispatch_semaphore_signal(_sem);
        return;
    }
    
    _willCallback = YES;
    if (self.delegate) {
        __weak typeof(self) ws = self;
        [self.delegate onComplete:self done:^{
            ws._isFinished = YES;
        }];
    } else {
        self._isFinished = YES;
    }
    
    dispatch_semaphore_signal(_sem);
}

- (KVOperation *)todoTask:(void (^) (KVOperation *op))task {
    self.todo = task;
    return self;
}

- (void)completeTask:(void (^) (KVOperation *op))task  {
    self.complete = task;
}

@end

@interface KVQueues : NSObject
{
    @private NSMutableArray<dispatch_queue_t> *_queues;
    @private NSInteger _queueTag;
}

@end

@implementation KVQueues

- (instancetype)init {
    if (self = [super init]) {
        _queues = NSMutableArray.array;
    }
    return self;
}

- (dispatch_queue_t)getQueue {
    if (_queues.count == 0) {
        for (NSInteger i = 0; i < KVQueuesLimit; i++) {
            [_queues addObject:dispatch_queue_create("kv", DISPATCH_QUEUE_CONCURRENT)];
        }
    }
    dispatch_queue_t res = _queues[_queueTag%KVQueuesLimit];
    [self offsetTag];
    return res;
}

- (void)offsetTag {
    _queueTag += 1;
    if (_queueTag == KVQueuesLimit) {
        _queueTag = 0;
    }
}

- (void)clear {
    [_queues removeAllObjects];
}

@end

@interface KVRWQueues : NSObject
{
    @private NSMutableDictionary<NSNumber*, dispatch_queue_t> *_map;
    @private NSMutableDictionary<NSNumber *, NSHashTable<NSObject *> *> *_tokens;
    @private NSInteger _queueTag;
}

@end

@implementation KVRWQueues

- (instancetype)init {
    if (self = [super init]) {
        _map = NSMutableDictionary.dictionary;
        _tokens = NSMutableDictionary.dictionary;
    }
    return self;
}

- (dispatch_queue_t)getQueue:(NSObject * _Nullable)token {
    if (_map.count == 0) {
        for (NSInteger i = 0; i < KVQueuesLimit; i++) {
            _map[@(i)] = dispatch_queue_create("kv.rw", DISPATCH_QUEUE_SERIAL);
        }
    }
    if (_tokens.count == 0) {
        for (NSInteger i = 0; i < KVQueuesLimit; i++) {
            _tokens[@(i)] = [[NSHashTable alloc] initWithOptions:(NSPointerFunctionsWeakMemory) capacity:0];
        }
    }
    for (NSInteger i = 0; i < KVQueuesLimit; i++) {
        NSHashTable<NSObject *> *set = _tokens[@(i)];
        if ([set containsObject:token]) {
            return _map[@(i)];
        }
    }
    
    dispatch_queue_t res = _map[@(_queueTag%KVQueuesLimit)];
    NSHashTable<NSObject *> *set = _tokens[@(_queueTag)];
    [set addObject:token];
    [self offsetTag];
    return res;
}

- (void)offsetTag {
    _queueTag += 1;
    if (_queueTag == KVQueuesLimit) {
        _queueTag = 0;
    }
}

@end

@interface KVQueuesManager : NSObject
{
    @private NSMutableDictionary<NSNumber *, KVQueues *> *_map;
    @private KVRWQueues *_rwqueues;
    @private dispatch_queue_t _globalQueue;
    
    @private dispatch_semaphore_t _sem;
    @private dispatch_semaphore_t _rwsem;
}

@end

@implementation KVQueuesManager

static KVQueuesManager *instance = nil;
static BOOL KVQueuesManagerInitFlag = NO;

+ (instancetype)shared {
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        KVQueuesManagerInitFlag = YES;
        instance = [[KVQueuesManager alloc] init];
        KVQueuesManagerInitFlag = NO;
    });
    return instance;
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        instance = [super allocWithZone:zone];
    });
    return instance;
}

- (instancetype)init {
    if (KVQueuesManagerInitFlag) {
        if (self = [super init]) {
            _map = NSMutableDictionary.dictionary;
            _rwqueues = [KVRWQueues new];
            _globalQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
            _sem = dispatch_semaphore_create(1);
            _rwsem = dispatch_semaphore_create(1);
            
            //
            _map[@(KVOperationTaskMode_Todo)] = KVQueues.new;
            _map[@(KVOperationTaskMode_Complete)] = KVQueues.new;
        }
        return self;
    }
    return instance;
}

- (dispatch_queue_t)getQueue:(KVOperationTaskMode)mode {
    dispatch_semaphore_wait(_sem, DISPATCH_TIME_FOREVER);
    dispatch_queue_t res = [_map[@(mode)] getQueue];
    dispatch_semaphore_signal(_sem);
    return res;
}

- (dispatch_queue_t)getGlobalQueue {
    return _globalQueue;
}

- (void)clear {
    dispatch_semaphore_wait(_sem, DISPATCH_TIME_FOREVER);
    [_map enumerateKeysAndObjectsUsingBlock:^(NSNumber * _Nonnull key, KVQueues * _Nonnull obj, BOOL * _Nonnull stop) {
        [obj clear];
    }];
    dispatch_semaphore_signal(_sem);
}

- (dispatch_queue_t)getRWQueue:(NSObject *)token {
    dispatch_semaphore_wait(_rwsem, DISPATCH_TIME_FOREVER);
    dispatch_queue_t res = [_rwqueues getQueue:token];
    dispatch_semaphore_signal(_rwsem);
    return res;
}

@end

@interface KVOperationQueue ()
<KVOperationDelegate>
{
    @private NSOperationQueue *_queue;
    @private dispatch_semaphore_t _sem;
    @private dispatch_semaphore_t _completesem;
}

@property (copy, nonatomic, nullable) void (^ complete) (KVOperationQueue *op);
@property (assign, nonatomic) BOOL isCompleted;

@end

@implementation KVOperationQueue

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
    KVQLog(@"KVOperationQueue dealloc~");
}

- (instancetype)init {
    if (self = [super init]) {
        __weak typeof(self) ws = self;
        [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidReceiveMemoryWarningNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification * _Nonnull note) {
            
            dispatch_semaphore_wait(ws.sem, DISPATCH_TIME_FOREVER);
            [ws.queue cancelAllOperations];
            [[KVQueuesManager shared] clear];
            dispatch_semaphore_signal(ws.sem);
            
        }];
        
        _sem = dispatch_semaphore_create(1);
        _completesem = dispatch_semaphore_create(1);
        _queue = [[NSOperationQueue alloc] init];
        _queue.maxConcurrentOperationCount = KVQueuesLimit;
    }
    return self;
}

- (NSOperationQueue *)queue {
    return _queue;
}

- (dispatch_semaphore_t)sem {
    return _sem;
}

- (void)addOperations:(NSArray<KVOperation *> *)ops {
    
    if (!ops.count) {
        return;
    }
    
    dispatch_semaphore_wait(_sem, DISPATCH_TIME_FOREVER);

    NSMutableArray<KVOperation *> *newOps = [[NSMutableArray alloc] initWithArray:ops];
    [newOps enumerateObjectsUsingBlock:^(KVOperation * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.isFinished) {
            // 被取消或已完成的操作
            KVQLog(@"该操作已完成或取消，不能添加到队列");
            [newOps removeObject:obj];
            return;
        }
    }];
    if (!newOps.count) {
        dispatch_semaphore_signal(_sem);
        return;
    }
    
    [newOps enumerateObjectsUsingBlock:^(KVOperation * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        obj.delegate = self;
        obj.queue = self;
    }];
    [self resetComplete];
    [_queue addOperations:newOps waitUntilFinished:NO];
    dispatch_semaphore_signal(_sem);
    
}

- (void)suspended:(BOOL)isSuspended {
    
    dispatch_semaphore_wait(_sem, DISPATCH_TIME_FOREVER);
    if (_queue.isSuspended == isSuspended) {
        dispatch_semaphore_signal(_sem);
        return;
    }
    _queue.suspended = isSuspended;
    dispatch_semaphore_signal(_sem);
    
}

- (void)cancelAllOperations {
    
    dispatch_semaphore_wait(_sem, DISPATCH_TIME_FOREVER);
    [_queue cancelAllOperations];
    [self notifiComplete];
    dispatch_semaphore_signal(_sem);
    
}

- (void)completeTask:(void (^)(KVOperationQueue * _Nonnull))task {
    
    dispatch_semaphore_wait(_completesem, DISPATCH_TIME_FOREVER);
    self.complete = task;
    dispatch_semaphore_signal(_completesem);
    
}

- (void)resetComplete {
    
    dispatch_semaphore_wait(_completesem, DISPATCH_TIME_FOREVER);
    if (self.isCompleted) {
        self.isCompleted = NO;
    }
    dispatch_semaphore_signal(_completesem);
    
}

- (void)notifiComplete {
    
    dispatch_semaphore_wait(_completesem, DISPATCH_TIME_FOREVER);
    
    if (self.isCompleted) {
        dispatch_semaphore_signal(_completesem);
        return;
    }

    if (_queue.operationCount == 0) {
        if (self.complete) {
            dispatch_async([[KVQueuesManager shared] getQueue:(KVOperationTaskMode_Complete)], ^{
                self.complete(self);
            });
        }
        self.isCompleted = YES;
    }
    dispatch_semaphore_signal(_completesem);
    
}

- (void)onTodo:(KVOperation *)op {
    if (op.todo) {
        dispatch_async([[KVQueuesManager shared] getQueue:(KVOperationTaskMode_Todo)], ^{
            op.todo(op);
        });
    } else {
        [op finish];
    }
}

- (void)onComplete:(KVOperation *)op done:(void (^)(void))done {
    __weak typeof(self) ws = self;
    if (op.complete) {
        if (op.isCompleteOnMainQueue) {
            dispatch_async(dispatch_get_main_queue(), ^{
                op.complete(op);
                done();
                dispatch_semaphore_wait(ws.sem, DISPATCH_TIME_FOREVER);
                [ws notifiComplete];
                dispatch_semaphore_signal(ws.sem);
            });
        } else {
            dispatch_async([[KVQueuesManager shared] getQueue:(KVOperationTaskMode_Complete)], ^{
                op.complete(op);
                done();
                dispatch_semaphore_wait(ws.sem, DISPATCH_TIME_FOREVER);
                [ws notifiComplete];
                dispatch_semaphore_signal(ws.sem);
            });
        }
    } else {
        done();
        dispatch_semaphore_wait(_sem, DISPATCH_TIME_FOREVER);
        [ws notifiComplete];
        dispatch_semaphore_signal(_sem);
    }
}

+ (void)onGlobalQueue:(void (^) (void))block {
    if (!block) {
        return;
    }
    dispatch_async([[KVQueuesManager shared] getGlobalQueue], ^{
        block();
    });
}

+ (void)synchronized:(NSObject *)token block:(void (^)(void))block {
    dispatch_async([[KVQueuesManager shared] getRWQueue:token], ^{
        block? block(): nil;
    });
}

@end

@implementation KVOperationQueue (Convenient)

+ (instancetype)queueWithOperations:(NSArray<KVOperation *> *)ops {
    KVOperationQueue *queue = [[KVOperationQueue alloc] init];
    [queue addOperations:ops];
    return queue;
}

+ (KVOperation *)operationWithTodo:(void (^)(KVOperation * _Nonnull))todo complete:(void (^)(KVOperation * _Nonnull))complete {
    KVOperation *op = [[KVOperation alloc] init];
    [[op todoTask:todo] completeTask:complete];
    return op;
}

@end
