//
//  BlufiStatusResponse.swift
//  BlufiSwiftFramework
//
//  Created by SomnicsAndrew on 2022/11/16.
//

import Foundation

public class BlufiStatusResponse: NSObject {
    var opMode: OpMode
    var softApSecurity: SoftAPSecurity
    var softApConnectionCount: Int
    var softApMaxConnection: Int
    var softApChannel: Int
    var softApPassword: String?
    var softApSsid: String?
    var staConnectionStatus: Int
    var staBssid: String?
    var staSsid: String?
    var staPassword: String?
    
    public init(opMode: OpMode = .OpModeNull, softApSecurity: SoftAPSecurity = .SoftAPSecurityUnknown, softApConnectionCount: Int = -1, softApMaxConnection: Int = -1, softApChannel: Int = -1, softApPassword: String? = nil, softApSsid: String? = nil, staConnectionStatus: Int = -1, staBssid: String? = nil, staSsid: String? = nil, staPassword: String? = nil) {
        self.opMode = opMode
        self.softApSecurity = softApSecurity
        self.softApConnectionCount = softApConnectionCount
        self.softApMaxConnection = softApMaxConnection
        self.softApChannel = softApChannel
        self.softApPassword = softApPassword
        self.softApSsid = softApSsid
        self.staConnectionStatus = staConnectionStatus
        self.staBssid = staBssid
        self.staSsid = staSsid
        self.staPassword = staPassword
    }

    public func isStaConnectWiFi() -> Bool {
        return staConnectionStatus == 0
    }
    
    public func getStatusInfo() -> String {
        var info: String = ""
        switch opMode {
        case .OpModeNull:
            info.append("NULL")
        case .OpModeSta:
            info.append("Station")
        case .OpModeSoftAP:
            info.append("SoftAP")
        case .OpModeStaSoftAP:
            info.append("Station/SoftAP")
        }
        info.append("\n")
        
        if opMode == .OpModeSta || opMode == .OpModeStaSoftAP {
            if isStaConnectWiFi() {
                info.append("Station connect Wi-Fi now")
            } else {
                info.append("Station disconnect Wi-Fi now")
            }
            info.append("\n")
            
            if let staBssid = staBssid {
                info.append("Station connect Wi-Fi bssid: ")
                info.append(staBssid)
                info.append("\n")
            }
            if let staSsid = staSsid {
                info.append("Station connect Wi-Fi ssid: ")
                info.append(staSsid)
                info.append("\n")
            }
            if let staPassword = staPassword {
                info.append("Statison connect Wi-Fi password: ")
                info.append(staPassword)
                info.append("\n")
            }
        }
        
        if opMode == .OpModeSoftAP || opMode == .OpModeStaSoftAP {
            switch softApSecurity {
            case .SoftAPSecurityOpen:
                info.append("SoftAP security: OPEN\n")
            case .SoftAPSecurityWEP:
                info.append("SoftAP security: WEP\n")
            case .SoftAPSecurityWPA:
                info.append("SoftAP security: WPA\n")
            case .SoftAPSecurityWPA2:
                info.append("SoftAP security: WPA2\n")
            case .SoftAPSecurityWPAWPA2:
                info.append("SoftAP security: WPA/WPA2\n")
            case .SoftAPSecurityUnknown:
                break
            }
            
            if let softApSsid = softApSsid {
                info.append("SoftAP ssid: ")
                info.append(softApSsid)
                info.append("\n")
            }
            if let softApPassword = softApPassword {
                info.append("SoftAP password: ")
                info.append(softApPassword)
                info.append("\n")
            }
            if softApChannel >= 0 {
                info.append("SoftAP channel: \(softApChannel)\n")
            }
            if softApMaxConnection >= 0 {
                info.append("SoftAP max connection: \(softApMaxConnection)\n")
            }
            if softApConnectionCount >= 0 {
                info.append("SoftAP current connection: \(softApConnectionCount)\n")
            }
        }
        return info
    }
}
