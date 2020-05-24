////
////  KVOperation.swift
////  Operation
////
////  Created by kevin on 2020/5/23.
////  Copyright © 2020 kevin. All rights reserved.
////
//
//import UIKit
//
///// 打印
//fileprivate func KVQLog<T>(_ message : T, file : String = #file, lineNumber : Int = #line) {
//    #if DEBUG
//        let fileName = (file as NSString).lastPathComponent
//        print("[\(fileName):line:\(lineNumber)]- \(message)")
//    #endif
//}
//
//fileprivate protocol KVOperationDelegate: NSObject {
//    
//    func onTodo(_ op: KVOperation)
//    
//    func onComplete(_ op: KVOperation, _ done: @escaping ()->Void)
//    
//}
//
//class KVOperation: Operation {
//    
//    private var _isExecuting: Bool = false {
//        willSet {
//            willChangeValue(forKey: "isExecuting")
//        }
//        didSet {
//            didChangeValue(forKey: "isExecuting")
//        }
//    }
//    override var isExecuting: Bool {
//        return _isExecuting
//    }
//    
//    private var _isFinished: Bool = false {
//        willSet {
//            willChangeValue(forKey: "isFinished")
//        }
//        didSet {
//            didChangeValue(forKey: "isFinished")
//        }
//    }
//    override var isFinished: Bool {
//        return _isFinished
//    }
//    
//    let tid = UUID().uuidString
//    
//    private let sem = DispatchSemaphore(value: 1)
//    
//    private let todosem = DispatchSemaphore(value: 1)
//            
//    private var willCallback = false
//    
//    fileprivate var _todo: ((_ op: KVOperation)->Void)?
//    
//    fileprivate var _complete: ((_ op: KVOperation)->Void)?
//    var isCompleteOnMainQueue = false
//    
//    fileprivate weak var delegate: KVOperationDelegate?
//    
//    fileprivate(set) weak var queue: KVOperationQueue?
//        
//    deinit {
//        KVQLog("KVOperation dealloc~")
//    }
//    
//    override init() {
//        super.init()
//
//    }
//    
//    override func start() {
//        todosem.wait()
//        defer {
//            todosem.signal()
//        }
//        
//        assert(delegate != nil && queue != nil, "You do not have to start manually, please add the operation to the queue, which is responsible for starting the call")
//        
//        if isFinished || _isExecuting {
//            return
//        }
//        
//        _isExecuting = true
//        delegate?.onTodo(self)
//    }
//    
//    override func cancel() {
//        sem.wait()
//        defer {
//            sem.signal()
//        }
//
//        if isFinished {
//            return
//        }
//
//        if willCallback {
//            return
//        }
//        
//        willCallback = true
//        if let delegate = self.delegate {
//            delegate.onComplete(self, { [weak self] in
//                self?.super_cancel()
//                self?._isFinished = true
//            })
//        } else {
//            super_cancel()
//            _isFinished = true
//        }
//    }
//    
//    private func super_cancel() {
//        super.cancel()
//    }
//    
//    func finish() {
//        sem.wait()
//        defer {
//            sem.signal()
//        }
//
//        if isFinished {
//            return
//        }
//
//        if willCallback {
//            return
//        }
//        
//        willCallback = true
//        if let delegate = self.delegate {
//            delegate.onComplete(self, { [weak self] in
//                self?._isFinished = true
//            })
//        } else {
//            _isFinished = true
//        }
//    }
//    
//    func todoTask(_ task: ((_ op: KVOperation)->Void)?) -> Self {
//        _todo = task
//        return self
//    }
//    
//    func completeTask(_ task: ((_ op: KVOperation)->Void)?) {
//        _complete = task
//    }
//    
//}
//
//private class KVQueuesManager: NSObject {
//
//    enum Mode {
//        case todo, complete
//    }
//    
//    static let shared = KVQueuesManager()
//    
//    static let queuesLimit = 32
//    
//    private var map: [Mode: KVQueues] = [:]
//    
//    private var rwqueues = KVRWQueues()
//    
//    private var globalQueue = DispatchQueue.global()
//    
//    private let sem = DispatchSemaphore(value: 1)
//    private let rwsem = DispatchSemaphore(value: 1)
//    
//    private override init() {
//        map[.todo] = KVQueues()
//        map[.complete] = KVQueues()
//    }
//    
//    func getQueue(_ mode: Mode) -> DispatchQueue {
//        self.sem.wait()
//        defer {
//            self.sem.signal()
//        }
//        
//        return map[mode]!.getQueue()
//    }
//    
//    func getGlobalQueue() -> DispatchQueue {
//        globalQueue
//    }
//    
//    func clear() {
//        self.sem.wait()
//        defer {
//            self.sem.signal()
//        }
//        
//        map.values.forEach { $0.clear() }
//    }
//    
//    func getRWQueue(_ token: NSObject?) -> DispatchQueue {
//        self.rwsem.wait()
//        defer {
//            self.rwsem.signal()
//        }
//        
//        return rwqueues.getQueue(token)
//    }
//    
//    private class KVQueues: NSObject {
//        
//        private var queues: [DispatchQueue] = []
//        private var queueTag: Int = 0
//        
//        func getQueue() -> DispatchQueue {
//            if queues.count == 0 {
//                for _ in 0..<queuesLimit {
//                    queues.append(DispatchQueue(label: "kv", qos: .userInitiated, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil))
//                }
//            }
//            let res = queues[queueTag%queuesLimit]
//            offsetTag()
//            return res
//        }
//        
//        func clear() {
//            queues.removeAll()
//        }
//        
//        private func offsetTag() {
//            queueTag += 1
//            if queueTag == queuesLimit  {
//                queueTag = 0
//            }
//        }
//    }
//    
//    private class KVRWQueues: NSObject {
//        
//        private var map: [Int: DispatchQueue] = [:]
//        private var tokens: [Int: NSHashTable<NSObject>] = [:]
//        private var queueTag: Int = 0
//        
//        func getQueue(_ token: NSObject?) -> DispatchQueue {
//            if map.count == 0 {
//                for i in 0..<queuesLimit {
//                    map[i] = DispatchQueue(label: "kv.rw")
//                }
//            }
//            if tokens.count == 0 {
//                for i in 0..<queuesLimit {
//                    tokens[i] = NSHashTable(options: .weakMemory)
//                }
//            }
//            
//            for i in 0..<queuesLimit {
//                if let set = tokens[i], set.contains(token) {
//                    return map[i]!
//                }
//            }
//            
//            let res = map[queueTag%queuesLimit]!
//            tokens[queueTag]?.add(token)
//            offsetTag()
//            return res
//        }
//        
//        private func offsetTag() {
//            queueTag += 1
//            if queueTag == queuesLimit  {
//                queueTag = 0
//            }
//        }
//        
//    }
//}
//
//final class KVOperationQueue: NSObject, KVOperationDelegate {
//
//    private lazy var queue = OperationQueue()
//    private let sem = DispatchSemaphore(value: 1)
//    private let completesem = DispatchSemaphore(value: 1)
//    private var complete: ((_ queue: KVOperationQueue)->Void)?
//    private var isCompleted: Bool = false
//    
//    deinit {
//        KVQLog("KVOperationQueue dealloc~")
//        NotificationCenter.default.removeObserver(self)
//    }
//    
//    override init() {
//        super.init()
//        
//        NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main) { [weak self] (notifi) in
//            self?.sem.wait()
//            defer {
//                self?.sem.signal()
//            }
//            
//            self?.queue.cancelAllOperations()
//            KVQueuesManager.shared.clear()
//        }
//        
//        queue.maxConcurrentOperationCount = KVQueuesManager.queuesLimit
//    }
//    
//    func add(_ ops: [KVOperation]) {
//        self.sem.wait()
//        defer {
//            self.sem.signal()
//        }
//        
//        let newOps = ops.filter({ (it) -> Bool in
//            if it.isFinished {
//                return false
//            }
//            it.delegate = self
//            it.queue = self
//            return true
//        })
//        if newOps.count == 0 {
//            return
//        }
//        
//        resetComplte()
//        queue.addOperations(newOps, waitUntilFinished: false)
//    }
//    
//    func completeTask(_ task: ((_ queue: KVOperationQueue)->Void)?) {
//        completesem.wait()
//        defer {
//            completesem.signal()
//        }
//        
//        complete = task
//    }
//    
//    private func resetComplte() {
//        completesem.wait()
//        defer {
//            completesem.signal()
//        }
//        
//        if isCompleted == true {
//            isCompleted = false
//        }
//    }
//    
//    private func notifiComplete() {
//        completesem.wait()
//        defer {
//            completesem.signal()
//        }
//        
//        if isCompleted {
//            return
//        }
//        
//        if queue.operationCount == 0 {
//            if let complete = self.complete {
//                KVQueuesManager.shared.getQueue(.complete).async {
//                    complete(self)
//                }
//            }
//            isCompleted = true
//        }
//        
//    }
//    
//    func suspended(_ isSuspended: Bool) {
//        self.sem.wait()
//        defer {
//            self.sem.signal()
//        }
//        
//        if isSuspended == queue.isSuspended {
//            return
//        }
//        queue.isSuspended = isSuspended
//    }
//    
//    func cancelAllOperations() {
//        self.sem.wait()
//        defer {
//            self.sem.signal()
//        }
//        
//        queue.cancelAllOperations()
//        notifiComplete()
//    }
//    
//    class func onGlobalQueue(_ block: @escaping ()->Void) {
//        KVQueuesManager.shared.getGlobalQueue().async {
//            block()
//        }
//    }
//    
//    class func synchronized(_ token: NSObject?, _ block: @escaping ()->Void) {
//        KVQueuesManager.shared.getRWQueue(token).async {
//            block()
//        }
//    }
//    
//    fileprivate func onTodo(_ op: KVOperation) {
//        if let todo = op._todo {
//            KVQueuesManager.shared.getQueue(.todo).async {
//                todo(op)
//            }
//        } else {
//            op.finish()
//        }
//    }
//    
//    fileprivate func onComplete(_ op: KVOperation, _ done: @escaping () -> Void) {
//        if let complete = op._complete {
//            if op.isCompleteOnMainQueue {
//                DispatchQueue.main.async { [weak self] in
//                    complete(op)
//                    done()
//                    self?.sem.wait()
//                    self?.notifiComplete()
//                    self?.sem.signal()
//                }
//            } else {
//                KVQueuesManager.shared.getQueue(.complete).async { [weak self] in
//                    complete(op)
//                    done()
//                    self?.sem.wait()
//                    self?.notifiComplete()
//                    self?.sem.signal()
//                }
//            }
//        } else {
//            done()
//            sem.wait()
//            notifiComplete()
//            sem.signal()
//        }
//    }
//}
//
//extension KVOperationQueue {
//    
//    class func queue(_ ops: [KVOperation]) -> KVOperationQueue {
//        let queue = KVOperationQueue()
//        queue.add(ops)
//        return queue
//    }
//    
//    class func operation(todo: ((_ op: KVOperation)->Void)?, complete: ((_ op: KVOperation)->Void)?) -> KVOperation {
//        let op = KVOperation()
//        op.todoTask(todo).completeTask(complete)
//        return op
//    }
//    
//}
//
////typealias KVQ = KVOperationQueue
