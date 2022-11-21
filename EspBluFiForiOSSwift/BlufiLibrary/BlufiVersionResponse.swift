//
//  BlufiVersionResponse.swift
//  BlufiSwiftFramework
//
//  Created by SomnicsAndrew on 2022/11/16.
//

import Foundation

public class BlufiVersionResponse: NSObject {
    var bigVer: Byte = 0
    var smallVer: Byte = 0

    public func getVersionString() -> String {
        return "V\(Int(bigVer)).\(Int(smallVer))"
    }
}
