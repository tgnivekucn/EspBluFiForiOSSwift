//
//  BlufiNotifyData.swift
//  BlufiSwiftFramework
//
//  Created by SomnicsAndrew on 2022/11/18.
//

import Foundation

class BlufiNotifyData: NSObject {
    var mutableData: NSMutableData
    var typeValue: Byte?
    var packageType: PackageType?
    var subType: SubType?
    var frameCtrl: Int?
    
    override init() {
        mutableData = NSMutableData(capacity: 0)!
    }
    
    func appendData(data: Data) {
        mutableData.append(data)
    }

    func getdata() -> Data {
        return mutableData as Data
    }
}
