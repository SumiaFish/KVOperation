//
//  KVOperation.swift
//  Operation
//
//  Created by kevin on 2020/5/23.
//  Copyright © 2020 kevin. All rights reserved.
//

import UIKit

fileprivate protocol KVOperationDelegate: NSObject {
    
    func onTodo(_ op: KVOperation)
    
    func onComplete(_ op: KVOperation, _ done: @escaping ()->Void)
    
}

class KVOperation: Operation {
    
    private var _isExecuting: Bool = false {
        willSet {
            willChangeValue(forKey: "isExecuting")
        }
        didSet {
            didChangeValue(forKey: "isExecuting")
        }
    }
    override var isExecuting: Bool {
        return _isExecuting
    }
    
    private var _isFinished: Bool = false {
        willSet {
            willChangeValue(forKey: "isFinished")
        }
        didSet {
            didChangeValue(forKey: "isFinished")
        }
    }
    override var isFinished: Bool {
        return _isFinished
    }
    
//    override var isConcurrent: Bool {
//        false
//    }
//
//    override var isAsynchronous: Bool {
//        false
//    }
    
    let tid = UUID().uuidString
    
    private let sem = DispatchSemaphore(value: 1)
    
    private let todosem = DispatchSemaphore(value: 1)
            
    private var willCallback = false
    
    fileprivate var _todo: ((_ op: KVOperation)->Void)?
    
    fileprivate var _complete: ((_ op: KVOperation)->Void)?
    var isCompleteOnMainQueue = false
    
    fileprivate weak var delegate: KVOperationDelegate?
    
    fileprivate(set) weak var queue: KVOperationQueue?
        
    deinit {
        print("KVOperation dealloc~")
    }
    
    override init() {
        super.init()

    }
    
    override func start() {
        todosem.wait()
        defer {
            todosem.signal()
        }
        
        if isFinished || _isExecuting {
            return
        }
        
        _isExecuting = true
        delegate?.onTodo(self)
    }
    
    override func cancel() {
        sem.wait()
        defer {
            sem.signal()
        }

        if isFinished {
            return
        }

        if willCallback {
            return
        }
        
        willCallback = true
        super.cancel()
        delegate?.onComplete(self, { [weak self] in
            self?._isFinished = true
        })
    }
    
    func finish() {
        sem.wait()
        defer {
            sem.signal()
        }

        if isFinished {
            return
        }

        if willCallback {
            return
        }
        
        willCallback = true
        delegate?.onComplete(self, { [weak self] in
            self?._isFinished = true
        })
    }
    
    func todoTask(_ task: ((_ op: KVOperation)->Void)?) -> Self {
        _todo = task
        return self
    }
    
    func completeTask(_ task: ((_ op: KVOperation)->Void)?) {
        _complete = task
    }
    
}

private class KVQueuesManager: NSObject {

    enum Mode {
        case todo, complete
    }
    
    static let shared = KVQueuesManager()
    
    static let queuesLimit = 32
    
    private var map: [Mode: KVQueues] = [:]
    
    private var rwqueues = KVRWQueues()
    
    private var globalQueue = DispatchQueue.global()
    
    private let sem = DispatchSemaphore(value: 1)
    private let rwsem = DispatchSemaphore(value: 1)
    
    private override init() {
        map[.todo] = KVQueues()
        map[.complete] = KVQueues()
    }
    
    func getQueue(_ mode: Mode) -> DispatchQueue {
        self.sem.wait()
        defer {
            self.sem.signal()
        }
        
        return map[mode]!.getQueue()
    }
    
    func getGlobalQueue() -> DispatchQueue {
        globalQueue
    }
    
    func clear() {
        self.sem.wait()
        defer {
            self.sem.signal()
        }
        
        map.values.forEach { $0.clear() }
    }
    
    func getRWQueue(_ token: NSObject?) -> DispatchQueue {
        self.rwsem.wait()
        defer {
            self.rwsem.signal()
        }
        
        return rwqueues.getQueue(token)
    }
    
    private class KVQueues: NSObject {
        
        private var queues: [DispatchQueue] = []
        private var queueTag: Int = 0
        
        func getQueue() -> DispatchQueue {
            if queues.count == 0 {
                for _ in 0..<queuesLimit {
                    queues.append(DispatchQueue(label: "kv", qos: .userInitiated, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil))
                }
            }
            let res = queues[queueTag%queuesLimit]
            offsetTag()
            return res
        }
        
        func clear() {
            queues.removeAll()
        }
        
        private func offsetTag() {
            queueTag += 1
            if queueTag == queuesLimit  {
                queueTag = 0
            }
        }
    }
    
    private class KVRWQueues: NSObject {
        
        private var map: [Int: DispatchQueue] = [:]
        private var tokens: [Int: NSHashTable<NSObject>] = [:]
        private var queueTag: Int = 0
        
        func getQueue(_ token: NSObject?) -> DispatchQueue {
            if map.count == 0 {
                for i in 0..<queuesLimit {
                    map[i] = DispatchQueue(label: "kv.rw")
                }
            }
            if tokens.count == 0 {
                for i in 0..<queuesLimit {
                    tokens[i] = NSHashTable(options: .weakMemory)
                }
            }
            
            for i in 0..<queuesLimit {
                if let set = tokens[i], set.contains(token) {
                    return map[i]!
                }
            }
            
            let res = map[queueTag%queuesLimit]!
            tokens[queueTag]?.add(token)
            offsetTag()
            return res
        }
        
        private func offsetTag() {
            queueTag += 1
            if queueTag == queuesLimit  {
                queueTag = 0
            }
        }
        
    }
}

final class KVOperationQueue: NSObject, KVOperationDelegate {

    private lazy var queue = OperationQueue()
    private let sem = DispatchSemaphore(value: 1)
    
    deinit {
        print("KVOperationQueue dealloc~")
        NotificationCenter.default.removeObserver(self)
    }
    
    override init() {
        super.init()
        
        NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main) { [weak self] (notifi) in
            self?.sem.wait()
            defer {
                self?.sem.signal()
            }
            
            self?.queue.cancelAllOperations()
            KVQueuesManager.shared.clear()
        }
        
        queue.maxConcurrentOperationCount = KVQueuesManager.queuesLimit
    }
    
    func addOperation(_ op: KVOperation) {
        self.sem.wait()
        defer {
            self.sem.signal()
        }
        
        op.delegate = self
        op.queue = self
        queue.addOperation(op)
    }
    
    func suspended(_ isSuspended: Bool) {
        self.sem.wait()
        defer {
            self.sem.signal()
        }
        
        if isSuspended == queue.isSuspended {
            return
        }
        queue.isSuspended = isSuspended
    }
    
    func cancelAllOperations() {
        self.sem.wait()
        defer {
            self.sem.signal()
        }
        
        queue.cancelAllOperations()
    }
    
    class func onGlobalQueue(_ block: @escaping ()->Void) {
        KVQueuesManager.shared.getGlobalQueue().async {
            block()
        }
    }
    
    class func synchronized(_ token: NSObject?, _ block: @escaping ()->Void) {
        KVQueuesManager.shared.getRWQueue(token).async {
            block()
        }
    }
    
    fileprivate func onTodo(_ op: KVOperation) {
        if let todo = op._todo {
            KVQueuesManager.shared.getQueue(.todo).async {
                todo(op)
            }
        } else {
            op.finish()
        }
    }
    
    fileprivate func onComplete(_ op: KVOperation, _ done: @escaping () -> Void) {
        if let complete = op._complete {
            if op.isCompleteOnMainQueue {
                DispatchQueue.main.async {
                    complete(op)
                    done()
                }
            } else {
                KVQueuesManager.shared.getQueue(.complete).async {
                    complete(op)
                    done()
                }
            }
        } else {
            done()
        }
    }
    
}

typealias KVQ = KVOperationQueue
