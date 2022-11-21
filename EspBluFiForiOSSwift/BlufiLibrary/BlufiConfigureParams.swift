//
//  BlufiConfigureParams.swift
//  BlufiSwiftFramework
//
//  Created by SomnicsAndrew on 2022/11/16.
//

import Foundation
public class BlufiConfigureParams: NSObject {
    public var opMode: OpMode?
    public var staBssid: String?
    public var staSsid: String?
    public var staPassword: String?
    public var softApSecurity: SoftAPSecurity = .SoftAPSecurityOpen
    public var softApSsid: String?
    public var softApPassword: String?
    public var softApChannel: Int?
    public var softApMaxConnection: Int?
}
