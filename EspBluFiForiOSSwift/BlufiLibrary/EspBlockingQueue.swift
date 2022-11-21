//
//  EspBlockingQueue.swift
//  BlufiSwiftFramework
//
//  Created by SomnicsAndrew on 2022/11/15.
//

import Foundation

class EspBlockingQueue: NSObject {
    var queue: NSMutableArray? = []
    var lock: NSCondition? = NSCondition()
    var dispatchQueue: DispatchQueue?
    override init() {
        self.queue = []
        self.lock = NSCondition()
        self.dispatchQueue = DispatchQueue(label: "com.espressif.blufi")
    }
    
    func cancel() {
        lock?.lock()
        lock?.signal()
        lock?.unlock()
    }
    
    func enqueue(object: Any) {
        lock?.lock()
        queue?.add(object)
        lock?.signal()
        lock?.unlock()
    }
    
    func dequeue() -> Any? {
        var object: Any?
        dispatchQueue?.sync {
            self.lock?.lock()
            while self.queue?.count == 0 {
                self.lock?.wait()
            }
            object = self.queue?.object(at: 0)
            self.queue?.removeObject(at: 0)
            self.lock?.unlock()
        }
        NSLog("test14 BlufiFramework device details object \(object)")
        return object
    }
    
    func count() -> Int {
        return queue?.count ?? 0
    }
    
    deinit {
        self.dispatchQueue = nil
        self.queue = nil
        self.lock = nil
    }
}
