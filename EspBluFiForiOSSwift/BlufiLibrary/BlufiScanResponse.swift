//
//  BlufiScanResponse.swift
//  BlufiSwiftFramework
//
//  Created by SomnicsAndrew on 2022/11/16.
//

import Foundation

public class BlufiScanResponse: NSObject {
    public var type: Int
    public var ssid: String
    public var rssi: Int8
    public init(type: Int, ssid: String, rssi: Int8) {
        self.type = type
        self.ssid = ssid
        self.rssi = rssi
    }
}
