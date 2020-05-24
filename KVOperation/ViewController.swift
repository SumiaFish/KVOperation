//
//  ViewController.swift
//  KVOperation
//
//  Created by kevin on 2020/5/23.
//  Copyright © 2020 kevin. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var lable: UILabel!
    
    var data: [Model] = []
    
    var idx: Int = 0
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
        self.lable.text = "\(idx)"
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
        
        let count = 100
        
        
        
//        for i in 0..<count {
//
//            let op = KVOperation()
//            op.todoTask { (op) in
//                print("subOp begin i:\(i), thred: \(Thread.current)")
//                op.finish()
//            }.completeTask { (op) in
//
//                self.idx = i
//                print("subOp end i:\(i), thred: \(Thread.current)")
//                if i == count-1 {
//                    print("耗时: \(Date().timeIntervalSince1970-t1)")
//                }
//            }
//
//            queue.addOperation(op)
//
//        }
        
        
        for _ in 0..<count {
            
            let op = KVOperation()
            op.todoTask { (op) in
                op.finish()
            }.completeTask { (op) in

                KVQ.synchronized(self) {
                    let m = Model()
                    m.test()
                    self.data.append(m)
                }
            }

            queue.addOperation(op)
            
        }
                
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

            queue.addOperation(op)
            
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

            queue.addOperation(op)
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

            queue.addOperation(op)
        }

    }

}

