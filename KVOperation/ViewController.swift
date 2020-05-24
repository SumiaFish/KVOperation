//
//  ViewController.swift
//  KVOperation
//
//  Created by kevin on 2020/5/23.
//  Copyright © 2020 kevin. All rights reserved.
//

import UIKit

typealias KVQ = KVOperationQueue

class ViewController: UIViewController {

    @IBOutlet weak var lable: UILabel!
    
    var data: [Model] = []
    
    var count: Int = 0
    var link: CADisplayLink?
    let queue = KVQ()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        addLink()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        removeLink()
    }
    
    func addLink() {
        removeLink()
        
        link = CADisplayLink(target: self, selector: #selector(run))
        link?.add(to: .main, forMode: .common)
        link?.frameInterval = 5
    }
    
    func removeLink() {
        link?.invalidate()
        link?.remove(from: .main, forMode: .common)
        link = nil
    }
    
    
    @objc func run() {
        self.lable.text = "\(count)"
    }
    
    func test() {
        
        KVOperationQueue.onGlobalQueue {
            for _ in 0..<1 {
                self.add()
            }
        }
        
    }
        
    func add() {
        
        let t1 = Date().timeIntervalSince1970
        
        let count = 10000
        
        
        /**
         count == 100000
        Swift:     耗时: 9.329712152481079
        OC:  耗时: 41.33598494529724
         搞不懂！怎么差这么多
         */
        
        KVQ.synchronized(self) {
            self.count = 0
        }
        
        queue.completeTask { (queue) in
            print("耗时: \(Date().timeIntervalSince1970-t1)")
            
//            KVQ.synchronized(self) {
//                assert(self.count == count, "有bug")
//            }
            
            KVQ.synchronized(self) {
                assert(self.data.count == 0, "有bug")
            }
        }
        
        var ops: [KVOperation] = []
        
//        for i in 0..<count {
//            let op = KVQ.operation(todo: { (op) in
//                print("subOp begin i:\(i), thred: \(Thread.current)")
//                op.finish()
//            }) { (op) in
//                print("subOp end i:\(i), thred: \(Thread.current)")
//                KVQ.synchronized(self) {
//                    self.count += 1
//                    print("count: \(self.count), thred: \(Thread.current)")
//                }
//            }
//            ops.append(op)
//        }
//        queue.add(ops)
        
        
        for _ in 0..<count {
            let op = KVOperation()
            op.todoTask { (op) in
                KVQ.synchronized(self) {
                    let m = Model()
                    self.data.append(m)
                }
                op.finish()
            }.completeTask { (op) in
                KVQ.synchronized(self) {
                    if self.data.count > 0 {
                        self.data.remove(at: 0)
                    }
                }
            }
            ops.append(op)
        }
        queue.add(ops)
        
        return
                
        for _ in 0..<count {
            
            let op = KVOperation()
            op.todoTask { (op) in
                op.finish()
            }.completeTask { (op) in

                KVQ.synchronized(self) {
                    if self.data.count > 0 {
                        self.data.remove(at: 0)
                    }
                }
                Thread.sleep(forTimeInterval: 0.01)
                
            }

//            queue.add(op)
            
        }

    }
    
    @IBAction func testAction(_ sender: Any) {
        test()
    }

}

class Model : NSObject {

    var data: [Int] = []
    let queue = KVQ()

    deinit {
        print("Model dealloc~")
    }

    func test() {
        KVOperationQueue.onGlobalQueue {
            for _ in 0..<1 {
                self.add()
            }
        }
    }

    func add() {

        let count = 100

        for i in 0..<count {
            
            let op = KVOperation()
            op.todoTask { (op) in
                print("subOp begin i:\(i), thred: \(Thread.current)")
                op.finish()
            }.completeTask { (op) in
                
                KVQ.synchronized(self) {
                    self.data.append(i)
                    print("count: \(self.data.count)")
                }

            }

//            queue.add(op)
        }
        
        for i in 0..<count {
            
            let op = KVOperation()
            op.todoTask { (op) in
                print("subOp begin i:\(i), thred: \(Thread.current)")
                op.finish()
            }.completeTask { (op) in
                
                // 加锁
                KVQ.synchronized(self) {
                    if self.data.count > 0 {
                        self.data.remove(at: 0)
                    }
                    print("count: \(self.data.count)")
                }
                
                // 不加锁
                /**
                 if self.data.count > 0 {
                     self.data.remove(at: 0)
                 }
                 print("count: \(self.data.count)")
                    有可能 catch
                 */
                

            }

//            queue.add(op)
        }

    }

}

