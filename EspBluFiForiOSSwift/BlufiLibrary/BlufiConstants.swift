//
//  BlufiConstants.swift
//  BlufiSwiftFramework
//
//  Created by SomnicsAndrew on 2022/11/15.
//

import Foundation

typealias Byte = UInt8
public typealias SubType = UInt32

public let UUID_SERVICE = "FFFF"
public let UUID_WRITE_CHAR = "FF01"
public let UUID_NOTIFY_CHAR = "FF02"

public let PACKAGE_LENGTH_DEFAULT = 128
public let PACKAGE_LENGTH_MIN = 20
public let PACKAGE_HEADER_LENGTH = 4


// Security usage
public let NegSecuritySetTotalLength = 0
public let NegSecuritySetAllData = 1

public enum ConnectionState: Int {
    case StateConnected = 0
    case StateDisconnected
}

public enum NotifyStatus: Int {
    case NotifyComplete = 0
    case NotifyHasFrag
    case NotifyNull
    case NotifyInvalidLength
    case NotifyInvalidSequence
    case NotifyInvalidChecsum
    case NotifyError
}

public enum BlufiStatusCode: Int {
    case StatusSuccess = 0
    case StatusFailed = 100
    case StatusInvalidRequest
    case StatusWriteFailed
    case StatusInvalidData
    case StatusBLEStateDisable
    case StatusException
}

public enum OpMode: Int {
    case OpModeNull = 0
    case OpModeSta
    case OpModeSoftAP
    case OpModeStaSoftAP
}

public enum SoftAPSecurity: Int {
    case SoftAPSecurityOpen = 0
    case SoftAPSecurityWEP
    case SoftAPSecurityWPA
    case SoftAPSecurityWPA2
    case SoftAPSecurityWPAWPA2
    case SoftAPSecurityUnknown
}

public enum DataDirection: Int {
    case DataOutput = 0
    case DataInput
}

public enum PackageType: Int {
    case PackageCtrl = 0
    case PackageData
}


// Ctrl Enum
public let CtrlSubTypeAck = 0
public let CtrlSubTypeSetSecurityMode = 1
public let CtrlSubTypeSetOpMode = 2
public let CtrlSubTypeConnectWiFi = 3
public let CtrlSubTypeDisconnectWiFi = 4
public let CtrlSubTypeGetWiFiStatus = 5
public let CtrlSubTypeDeauthenticate = 6
public let CtrlSubTypeGetVersion = 7
public let CtrlSubTypeCloseConnection = 8
public let CtrlSubTypeGetWiFiList = 9



// DataSubType Enum
public let DataSubTypeNeg = 0
public let DataSubTypeStaBssid = 1
public let DataSubTypeStaSsid = 2
public let DataSubTypeStaPassword = 3
public let DataSubTypeSoftAPSsid = 4
public let DataSubTypeSoftAPPassword = 5
public let DataSubTypeSoftAPMaxConnection = 6
public let DataSubTypeSoftAPAuthMode = 7
public let DataSubTypeSoftAPChannel = 8
public let DataSubTypeUserName = 9
public let DataSubTypeCACertification = 10
public let DataSubTypeClentCertification = 11
public let DataSubTypeServerCertification = 12
public let DataSubTypeClientPrivateKey = 13
public let DataSubTypeServerPrivateKey = 14
public let DataSubTypeWiFiConnectionState = 15
public let DataSubTypeVersion = 16
public let DataSubTypeWiFiList = 17
public let DataSubTypeError = 18
public let DataSubTypeCustomData = 19
