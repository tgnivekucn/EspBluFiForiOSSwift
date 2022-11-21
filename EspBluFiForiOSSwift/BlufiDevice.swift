//
//  BlufiDevice.swift
//  TestRxBluetooth
//
//  Created by SomnicsAndrew on 2022/9/26.
//

import Foundation
import CoreBluetooth

protocol BlufiDeviceProtocol {
    func updateDeviceMessage(message: String)
}

class BlufiDevice: NSObject {
    var client: BlufiClient?
    var delegate: BlufiDeviceProtocol?

    init(delegate: BlufiDeviceProtocol) {
        super.init()
        self.delegate = delegate
    }
    
    // MARK: - instance methods
    func connect(uuid: String) {
        if let client = self.client {
            client.close()
            self.client = nil
        }
        client = BlufiClient()
        client?.blufiDelegate = self
        client?.centralManagerDelete = self
        client?.connect(uuid)
    }
    
    func requestCloseConnection() {
        client?.requestCloseConnection()
    }

    func requestDeviceVersion() {
        client?.requestDeviceVersion()
    }

    func requestDeviceStatus() {
        client?.requestDeviceStatus()
    }
    
    func negotiateSecurity() {
        client?.negotiateSecurity()
    }
    
    func requestDeviceScan() {
        client?.requestDeviceScan()
    }
    
    func configureWifi(param: BlufiConfigureParams) {
        client?.configure(param)
    }
    
    func postCustomData(request: String) {
        let requestData = Data(request.utf8)
        client?.postCustomData(requestData)
    }

    // MARK: - Utility functions
    static func getBlufiConfigureParam(opMode: OpMode, staSSID: String? = nil, staPassword: String? = nil,
                                staBssid: String? = nil, apSecurity: SoftAPSecurity? = nil, softApSsid: String? = nil,
                                softApPassword: String? = nil, softApChannel: Int? = nil, softApMaxConnection: Int? = nil) -> BlufiConfigureParams {
        let param = BlufiConfigureParams()
        param.opMode = opMode
        switch opMode {
        case .OpModeNull:
            break
        case .OpModeSta:
            if let staSSID = staSSID,
               let staPassword = staPassword {
                param.staSsid = staSSID
                param.staPassword = staPassword
            }
        case .OpModeSoftAP:
            if let softApSsid = softApSsid,
               let softApPassword = softApPassword,
               let softApChannel = softApChannel,
               let softApMaxConnection = softApMaxConnection,
               let apSecurity = apSecurity {
                param.softApSsid = softApSsid
                param.softApPassword = softApPassword
                param.softApChannel = softApChannel
                param.softApMaxConnection = softApMaxConnection
                param.softApSecurity = apSecurity
            }
        case .OpModeStaSoftAP:
            if let staSSID = staSSID,
               let staPassword = staPassword,
               let softApSsid = softApSsid,
               let softApPassword = softApPassword,
               let softApChannel = softApChannel,
               let softApMaxConnection = softApMaxConnection,
               let apSecurity = apSecurity {
                param.staSsid = staSSID
                param.staPassword = staPassword
                param.softApSsid = softApSsid
                param.softApPassword = softApPassword
                param.softApChannel = softApChannel
                param.softApMaxConnection = softApMaxConnection
                param.softApSecurity = apSecurity
            }
        }
        return param
    }
    
    private func convertDataToByteArr(data: Data) -> [UInt8] {
        return data.reduce(into: [UInt8]()) {
            $0.append($1)
        }
    }
    
    private func convertByteArrToHexString(arr: [UInt8]) -> String {
        let hexArr = arr.map { String($0, radix: 16, uppercase: false) }
        return hexArr.reduce(into: "") { $0 += $1 }
    }
}

// MARK: - CBCentralManagerDelegate
extension BlufiDevice: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if let state = CBManagerState(rawValue: central.state.rawValue) {
            print("test11 \(state)")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        delegate?.updateDeviceMessage(message: "disconnect device")
    }
}

// MARK: - BlufiDelegate
extension BlufiDevice: BlufiDelegate {
    func blufi(_ client: BlufiClient, gattNotification data: Data, packageType: PackageType, subType: SubType) -> Bool {
        return true
    }
    
    func blufi(_ client: BlufiClient, didPostConfigureParams status: BlufiStatusCode) {
        //
    }
    
    func blufi(_ client: BlufiClient, didPostCustomData data: Data, status: BlufiStatusCode) {
        let tmpArr: [UInt8] = convertDataToByteArr(data: data)
        let hexString = convertByteArrToHexString(arr: tmpArr)
        print("test11 didPostCustomData, hex string: \(hexString)")
    }
    func blufi(_ client: BlufiClient, gattPrepared status: BlufiStatusCode, service: CBService?, writeChar: CBCharacteristic?, notifyChar: CBCharacteristic?) {
        if status.rawValue == 0 {
            delegate?.updateDeviceMessage(message: "BluFi connection has prepared")
        } else {
            delegate?.updateDeviceMessage(message: "BluFi connection fail")
        }
    }
    
    func blufi(_ client: BlufiClient, didReceiveDeviceVersionResponse response: BlufiVersionResponse?, status: BlufiStatusCode) {
        if status.rawValue == 0 {
            delegate?.updateDeviceMessage(message: "Receive device version: \(String(describing: response?.getVersionString()))")
        } else {
            delegate?.updateDeviceMessage(message: "Receive device version error")
        }
    }
    
    func blufi(_ client: BlufiClient, didReceiveError errCode: Int) {
        //
    }
    
    func blufi(_ client: BlufiClient, didReceiveDeviceStatusResponse response: BlufiStatusResponse?, status: BlufiStatusCode) {
        if status.rawValue == 0 {
            delegate?.updateDeviceMessage(message: "Receive device status: \(String(describing: response?.getStatusInfo()))")
        } else {
            delegate?.updateDeviceMessage(message: "Receive device status error")
        }
    }
    
    func blufi(_ client: BlufiClient, didReceiveDeviceScanResponse scanResults: [BlufiScanResponse]?, status: BlufiStatusCode) {
        if status.rawValue == 0 {
            var info: String = "Receive device scan results:\n"
            if let scanResults = scanResults {
                for item in scanResults {
                    info.append("SSID: \(item.ssid), RSSI: \(item.rssi)\n")
                }
            }
            delegate?.updateDeviceMessage(message: info)
        } else {
            delegate?.updateDeviceMessage(message: "didNegotiateSecurity fail")
        }
    }
    
    func blufi(_ client: BlufiClient, didNegotiateSecurity status: BlufiStatusCode) {
        if status.rawValue == 0 {
            delegate?.updateDeviceMessage(message: "didNegotiateSecurity success")
        } else {
            delegate?.updateDeviceMessage(message: "didNegotiateSecurity fail")
        }
    }
    
    func blufi(_ client: BlufiClient, didReceiveCustomData data: Data, status: BlufiStatusCode) {
        let tmpArr: [UInt8] = convertDataToByteArr(data: data)
        let hexString = convertByteArrToHexString(arr: tmpArr)
//        _ = DataQueueHandler.shared.parseDataQueue(by: hexString) //TODO

        // Below code is just for debugging
        print("test11 tmpArr: \(hexString)")
        if status.rawValue == 0 {
//            let tmp = String(data: data, encoding: .utf8)
            delegate?.updateDeviceMessage(message: "didReceiveCustomData success:\n \(hexString)")
        } else {
            delegate?.updateDeviceMessage(message: "didReceiveCustomData fail")
        }
    }
}
