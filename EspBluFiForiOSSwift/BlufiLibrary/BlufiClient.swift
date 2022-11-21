import Foundation
import CoreBluetooth
import BlufiSecurityFramework

public protocol BlufiDelegate: NSObject {
    func blufi(_ client: BlufiClient, gattPrepared status: BlufiStatusCode, service: CBService?, writeChar: CBCharacteristic?, notifyChar: CBCharacteristic?)
    func blufi(_ client: BlufiClient, gattNotification data: Data, packageType: PackageType, subType: SubType) -> Bool
    func blufi(_ client: BlufiClient, didReceiveError errCode: Int)
    func blufi(_ client: BlufiClient, didNegotiateSecurity status: BlufiStatusCode)
    func blufi(_ client: BlufiClient, didPostConfigureParams status: BlufiStatusCode)
    func blufi(_ client: BlufiClient, didReceiveDeviceVersionResponse response: BlufiVersionResponse?, status: BlufiStatusCode)
    func blufi(_ client: BlufiClient, didReceiveDeviceStatusResponse response: BlufiStatusResponse?, status: BlufiStatusCode)
    func blufi(_ client: BlufiClient, didReceiveDeviceScanResponse scanResults: [BlufiScanResponse]?, status: BlufiStatusCode)
    func blufi(_ client: BlufiClient, didPostCustomData data: Data, status: BlufiStatusCode)
    func blufi(_ client: BlufiClient, didReceiveCustomData data: Data, status: BlufiStatusCode)
}

public class BlufiClient: NSObject {
    // MARK: Public properties
    public var blufiDelegate: BlufiDelegate?
    public var centralManagerDelete: CBCentralManagerDelegate?
    public var peripheralDelegate: CBPeripheralDelegate?
    
    // MARK: Internal properties
    internal var postPackageLengthLimit: Int
    internal var connectState: ConnectionState
    internal var peripheral: CBPeripheral?
    internal var service: CBService?
    internal var writeUUID: CBUUID
    internal var notifyUUID: CBUUID
    internal var writeChar: CBCharacteristic?
    internal var notifyChar: CBCharacteristic?
    internal var writeCondition: NSCondition
    internal var callbackQueue: OperationQueue //NSOperationQueue
    internal var identifier: UUID?
    internal var blePowerOn: Bool
    internal var sendSequence: Int
    internal var readSequence: Int
    internal var notifyData: BlufiNotifyData?
    
    // MARK: Private properties
    private var bleConnectMark: Bool
    private var aesKey: Data?
    private var encrypted: Bool
    private var checksum: Bool
    private var requireAck: Bool
    private var deviceAck: EspBlockingQueue
    private var deviceKey: EspBlockingQueue
    private var centralManager: CBCentralManager?
    private var requestQueue: OperationQueue //NSOperationQueue
    private var closed: Bool
    
    // MARK: - Public functions
    public override init() {
        writeUUID = CBUUID(string: UUID_WRITE_CHAR)
        writeCondition = NSCondition()
        notifyUUID = CBUUID(string: UUID_NOTIFY_CHAR)
        
        callbackQueue = OperationQueue.main
        requestQueue = OperationQueue()
        requestQueue.maxConcurrentOperationCount = 1
        
        bleConnectMark = false
        blePowerOn = false
        
        connectState = .StateDisconnected
        
        postPackageLengthLimit = PACKAGE_LENGTH_DEFAULT
        
        sendSequence = -1
        readSequence = -1
        
        encrypted = false
        checksum = false
        requireAck = false
        
        deviceAck = EspBlockingQueue()
        deviceKey = EspBlockingQueue()
        
        closed = false
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    public func close() {
        closed = true
        callbackQueue.cancelAllOperations()
        requestQueue.cancelAllOperations()
        centralManager?.stopScan()
        self.clearConnection()
        
        blufiDelegate = nil
        centralManagerDelete = nil
        peripheralDelegate = nil
        centralManager?.delegate = nil
        
        deviceAck.cancel()
        deviceKey.cancel()
    }
    
    public func connect(_ identifier: String) {
        if closed {
            self.onError(errCode: 0)
        }
        self.clearConnection()
        self.identifier = UUID(uuidString: identifier)
        self.scanBLE()
        
        // Comment Below code to fix reconnect Blufi device issue after turning off bluetooth first and then re-open bluetooth
        //        if blePowerOn {}
        //        else { bleConnectMark = true }
    }
    
    public func clearConnection() {
        readSequence = -1
        sendSequence = -1
        NSLog("test14 BlufiFramework _readSequence is: \(readSequence), _readSequence/_sendSequence already be reset")
        
        bleConnectMark = false
        connectState = .StateDisconnected
        if let peripheral = self.peripheral {
            centralManager?.cancelPeripheralConnection(peripheral)
            self.peripheral = nil
        }
        service = nil
        writeChar = nil
        notifyChar = nil
        deviceAck.cancel()
    }
    
    
    public func requestCloseConnection() {
        requestQueue.addOperation {
            let type: Byte = self.getTypeValueWithPackageType(pkgType: .PackageCtrl, subType: SubType(CtrlSubTypeCloseConnection))
            _ = self.post(data: nil, encrypt: false, checksum: false, requireAck: false, type: type)
        }
    }
    
    public func requestDeviceVersion() {
        let encrypted = encrypted
        let checksum = checksum
        requestQueue.addOperation {
            let type: Byte = self.getTypeValueWithPackageType(pkgType: .PackageCtrl, subType: SubType(CtrlSubTypeGetVersion))
            let posted = self.post(data: nil, encrypt: encrypted, checksum: checksum, requireAck: false, type: type)
            if !posted {
                NSLog("test14 BlufiFramework Post DeiviceVersion request failed")
                self.onVersionResponse(response: nil, status: .StatusWriteFailed)
            }
        }
    }
    
    public func requestDeviceStatus() {
        let encrypted = encrypted
        let checksum = checksum
        requestQueue.addOperation {
            let type: Byte = self.getTypeValueWithPackageType(pkgType: .PackageCtrl, subType: SubType(CtrlSubTypeGetWiFiStatus))
            let posted = self.post(data: nil, encrypt: encrypted, checksum: checksum, requireAck: false, type: type)
            if !posted {
                NSLog("test14 BlufiFramework Post DeviceStatus request failed")
                self.onDeviceStatusResponse(response: nil, status: .StatusWriteFailed)
            }
        }
    }
    
    public func requestDeviceScan() {
        let encrypted = encrypted
        let checksum = checksum
        requestQueue.addOperation {
            let type: Byte = self.getTypeValueWithPackageType(pkgType: .PackageCtrl, subType: SubType(CtrlSubTypeGetWiFiList))
            let posted = self.post(data: nil, encrypt: encrypted, checksum: checksum, requireAck: false, type: type)
            if !posted {
                NSLog("test14 BlufiFramework Post WiFiScan request failed")
                self.onDeviceScanList(list: nil, status: .StatusWriteFailed)
            }
        }
    }
    
    public func postCustomData(_ data: Data) {
        let encrypted = encrypted
        let checksum = checksum
        let ack = requireAck
        requestQueue.addOperation {
            let type: Byte = self.getTypeValueWithPackageType(pkgType: .PackageData, subType: SubType(DataSubTypeCustomData))
            let posted = self.post(data: data, encrypt: encrypted, checksum: checksum, requireAck: ack, type: type)
            let code: BlufiStatusCode = posted ? BlufiStatusCode.StatusSuccess : BlufiStatusCode.StatusWriteFailed
            self.onPostCustomData(data: data, status: code)
        }
    }
    
    public func configure(_ params: BlufiConfigureParams) {
        requestQueue.addOperation {
            guard let opMode = params.opMode else { return }
            switch opMode {
            case .OpModeNull:
                if !self.postDeviceMode(opMode: opMode) {
                    self.onPostConfigureParams(code: .StatusWriteFailed)
                    return
                }
                self.onPostConfigureParams(code: .StatusSuccess)
            case .OpModeSta:
                if !self.postDeviceMode(opMode: opMode) {
                    self.onPostConfigureParams(code: .StatusWriteFailed)
                    return
                }
                if !self.postStaInfo(params: params) {
                    self.onPostConfigureParams(code: .StatusWriteFailed)
                    return
                }
                self.onPostConfigureParams(code: .StatusSuccess)
            case .OpModeSoftAP:
                if !self.postDeviceMode(opMode: opMode) {
                    self.onPostConfigureParams(code: .StatusWriteFailed)
                    return
                }
                if !self.postSoftAPInfo(params: params) {
                    self.onPostConfigureParams(code: .StatusWriteFailed)
                    return
                }
                self.onPostConfigureParams(code: .StatusSuccess)
            case .OpModeStaSoftAP:
                if !self.postDeviceMode(opMode: opMode) {
                    self.onPostConfigureParams(code: .StatusWriteFailed)
                    return
                }
                if !self.postStaInfo(params: params) {
                    self.onPostConfigureParams(code: .StatusWriteFailed)
                    return
                }
                if !self.postSoftAPInfo(params: params) {
                    self.onPostConfigureParams(code: .StatusWriteFailed)
                    return
                }
                self.onPostConfigureParams(code: .StatusSuccess)
            }
        }
    }
    
    public func postNegotiateSecurity() -> BlufiDH? {
        let type: Byte = self.getTypeValueWithPackageType(pkgType: .PackageData, subType: SubType(DataSubTypeNeg))
        let blufiDH = BlufiSecurity.dhGenerateKeys()
        let p = blufiDH.p
        let g = blufiDH.g
        let k = blufiDH.publicKey
        let pgkLength = p.count + g.count + k.count + 6
        let bytes: [Byte] = [ Byte(NegSecuritySetTotalLength),
                              Byte(pgkLength >> 8 & 0xff),
                              Byte(pgkLength & 0xff)]
        var posted = self.post(data: Data(bytes), encrypt: false, checksum: false, requireAck: requireAck, type: type)
        if !posted {
            NSLog("test14 BlufiFramework postNegotiateSecurity: Post length failed")
            return nil
        }
        
        var data = Data(repeating: 0, count: pgkLength)
        let negType: [Byte] = [ Byte(NegSecuritySetAllData) ]
        data.append(negType, count: 1)
        
        let pLength: [Byte] = [ Byte(p.count >> 8 & 0xff),
                                Byte(p.count & 0xff)]
        data.append(pLength, count: 2)
        data.append(p)
        
        let gLength: [Byte] = [ Byte(g.count >> 8 & 0xff),
                                Byte(g.count & 0xff)]
        data.append(gLength, count: 2)
        data.append(g)
        
        
        
        let kLength: [Byte] = [ Byte(k.count >> 8 & 0xff),
                                Byte(k.count & 0xff)]
        data.append(kLength, count: 2)
        data.append(k)
        
        posted = self.post(data: data, encrypt: false, checksum: false, requireAck: requireAck, type: type)
        if !posted {
            NSLog("test14 BlufiFramework postNegotiateSecurity: Post data failed")
            return nil
        }
        return blufiDH
    }
    
    public func negotiateSecurity() {
        requestQueue.addOperation { [weak self] in
            guard let self = self else { return }
            var setSecurity = false
            var code: BlufiStatusCode = .StatusFailed
            do {
                let blufiDH = self.postNegotiateSecurity()
                if blufiDH == nil {
                    code = .StatusWriteFailed
                    return
                }
                NSLog("test14 BlufiFramework negotiateSecurity DH posted")
                
                let deviceKey = self.deviceKey.dequeue()
                if deviceKey == nil {
                    NSLog("test14 BlufiFramework negotiateSecurity Recevie nil deviceKey")
                    code = .StatusFailed
                    return
                }
                if let deviceKey = deviceKey as? Data,
                   let blufiDH = blufiDH {
                    let secretKey = blufiDH.generateSecret(deviceKey)
                    self.aesKey = BlufiSecurity.md5(secretKey)
                }
                
                setSecurity = self.postSetSecurityCtrlEncrypted(ctrlEncrypted: false, ctrlChecksum: false, dataEncrypted: true, dataChecksum: true)
                if !setSecurity {
                    NSLog("test14 BlufiFramework negotiateSecurity postSetSecurity failed")
                    code = .StatusWriteFailed
                }
            } catch {
                NSLog("test14 BlufiFramework negotiateSecurity exception: \(error)")
                code = .StatusException
            }
            if setSecurity {
                self.encrypted = true
                self.checksum = true
                self.onNegotiateSecurityResult(code: .StatusSuccess)
            } else {
                self.encrypted = false
                self.checksum = false
                self.onNegotiateSecurityResult(code: code)
            }
        }
        
    }
    
    public func scanBLE() {
        NSLog("test14 BlufiFramework Blufi Scan device: \(String(describing: identifier))")
        centralManager?.scanForPeripherals(withServices: nil)
    }
    
    
    // MARK: - Private functions
    private func onPostConfigureParams(code: BlufiStatusCode) {
        let delegate = blufiDelegate
        let client: BlufiClient = self
        if let delegate = delegate {
            callbackQueue.addOperation {
                delegate.blufi(client, didPostConfigureParams: code)
            }
        }
    }
    
    private func postDeviceMode(opMode: OpMode) -> Bool {
        let type: Byte = self.getTypeValueWithPackageType(pkgType: .PackageCtrl, subType: SubType(CtrlSubTypeSetOpMode))
        let buf: [Byte] = [ Byte(opMode.rawValue) ]
        let data = Data(buf)
        return self.post(data: data, encrypt: encrypted, checksum: checksum, requireAck: true, type: type)
    }
    
    private func postStaInfo(params: BlufiConfigureParams) -> Bool {
        var type: Byte = self.getTypeValueWithPackageType(pkgType: .PackageData, subType: SubType(DataSubTypeStaSsid))
        let ssid: Data = params.staSsid?.data(using: .utf8) ?? Data()
        if !self.post(data: ssid, encrypt: encrypted, checksum: checksum, requireAck: requireAck, type: type) {
            return false
        }
        Thread.sleep(forTimeInterval: 0.01)
        
        type = self.getTypeValueWithPackageType(pkgType: .PackageData, subType: SubType(DataSubTypeStaSsid))
        let password: Data = params.staPassword?.data(using: .utf8) ?? Data()
        if !self.post(data: password, encrypt: encrypted, checksum: checksum, requireAck: requireAck, type: type) {
            return false
        }
        Thread.sleep(forTimeInterval: 0.01)
        
        type = self.getTypeValueWithPackageType(pkgType: .PackageCtrl, subType: SubType(CtrlSubTypeConnectWiFi))
        return self.post(data: nil, encrypt: encrypted, checksum: checksum, requireAck: requireAck, type: type)
    }
    
    private func postSoftAPInfo(params: BlufiConfigureParams) -> Bool {
        let ssid: Data? = params.softApSsid?.data(using: .utf8) ?? nil
        if let ssid = ssid,
           ssid.count > 0 {
            let type: Byte = self.getTypeValueWithPackageType(pkgType: .PackageData, subType: SubType(DataSubTypeSoftAPSsid))
            if !self.post(data: ssid, encrypt: encrypted, checksum: checksum, requireAck: requireAck, type: type) {
                return false
            }
            Thread.sleep(forTimeInterval: 0.01)
        }
        
        let password: Data? = params.softApPassword?.data(using: .utf8) ?? nil
        if let password = password,
           password.count > 0 {
            let type: Byte = self.getTypeValueWithPackageType(pkgType: .PackageData, subType: SubType(DataSubTypeSoftAPPassword))
            if !self.post(data: password, encrypt: encrypted, checksum: checksum, requireAck: requireAck, type: type) {
                return false
            }
            Thread.sleep(forTimeInterval: 0.01)
        }
        
        let channel = params.softApChannel ?? 0
        if channel > 0 {
            let type: Byte = self.getTypeValueWithPackageType(pkgType: .PackageData, subType: SubType(DataSubTypeSoftAPChannel))
            let buf: [Byte] = [Byte(channel)]
            let data = Data(buf)
            if !self.post(data: data, encrypt: encrypted, checksum: checksum, requireAck: requireAck, type: type) {
                return false
            }
            Thread.sleep(forTimeInterval: 0.01)
        }
        
        
        let maxConn = params.softApMaxConnection ?? 0
        if maxConn > 0 {
            let type: Byte = self.getTypeValueWithPackageType(pkgType: .PackageData, subType: SubType(DataSubTypeSoftAPMaxConnection))
            let buf: [Byte] = [Byte(maxConn)]
            let data = Data(buf)
            if !self.post(data: data, encrypt: encrypted, checksum: checksum, requireAck: requireAck, type: type) {
                return false
            }
            Thread.sleep(forTimeInterval: 0.01)
        }
        
        let type: Byte = self.getTypeValueWithPackageType(pkgType: .PackageData, subType: SubType(DataSubTypeSoftAPAuthMode))
        let buf: [Byte] = [Byte(params.softApSecurity.rawValue)]
        let data = Data(buf)
        return self.post(data: data, encrypt: encrypted, checksum: checksum, requireAck: requireAck, type: type)
    }
    
    private func postSetSecurityCtrlEncrypted(ctrlEncrypted: Bool, ctrlChecksum: Bool, dataEncrypted: Bool, dataChecksum: Bool) -> Bool {
        let type: Byte = self.getTypeValueWithPackageType(pkgType: .PackageCtrl, subType: SubType(CtrlSubTypeSetSecurityMode))
        var data: Byte = 0
        if dataChecksum {
            data |= 1
        }
        if dataEncrypted {
            data |= 0b10
        }
        if ctrlChecksum {
            data |= 0b10000
        }
        if ctrlEncrypted {
            data |= 0b100000
        }
        let postBytes: [Byte] = [data]
        let postData = Data(bytes: postBytes, count: 1)
        return self.post(data: postData, encrypt: false, checksum: true, requireAck: requireAck, type: type)
    }
    
    private func onNegotiateSecurityResult(code: BlufiStatusCode) {
        let delegate = blufiDelegate
        let client: BlufiClient = self
        if let delegate = delegate {
            callbackQueue.addOperation {
                delegate.blufi(client, didNegotiateSecurity: code)
            }
        }
    }

    private func onVersionResponse(response: BlufiVersionResponse?, status code: BlufiStatusCode) {
        let delegate = blufiDelegate
        let client = self
        if let delegate = delegate {
            callbackQueue.addOperation {
                delegate.blufi(client, didReceiveDeviceVersionResponse: response, status: code)
            }
        }
    }
    
    private func parseVersion(data: Data) {
        var code: BlufiStatusCode?
        var response: BlufiVersionResponse?
        let buf: [Byte] = [UInt8] (data)
        if data.count != 2 {
            code = .StatusInvalidData
            response = nil
        } else {
            code = .StatusSuccess
            response = BlufiVersionResponse()
            response?.bigVer = buf[0]
            response?.smallVer = buf[1]
        }
        if let response = response,
           let code = code {
            self.onVersionResponse(response: response, status: code)
        }
    }
    
    private func onDeviceStatusResponse(response: BlufiStatusResponse?, status code: BlufiStatusCode) {
        let delegate = blufiDelegate
        let client = self
        if let delegate = delegate {
            callbackQueue.addOperation {
                delegate.blufi(client, didReceiveDeviceStatusResponse: response, status: code)
            }
        }
    }
    
    
    private func onDeviceScanList(list: [BlufiScanResponse]?, status code: BlufiStatusCode) {
        let delegate = blufiDelegate
        let client: BlufiClient = self
        if let delegate = delegate {
            callbackQueue.addOperation {
                delegate.blufi(client, didReceiveDeviceScanResponse: list, status: code)
            }
        }
    }
 
    private func parseWiFiScanList(data: Data) {
        var result = [BlufiScanResponse]()
        let dataIS = InputStream(data: data)
        let temp = [Byte] (repeating: 0, count: data.count)
        dataIS.open()
        while dataIS.hasBytesAvailable {
            var read = dataIS.read(UnsafeMutableRawPointer(mutating: temp), maxLength: 2)
            if read != 2 {
                NSLog("test14 BlufiFramework parseWiFiScanList contain invalid data1")
                break
            }
            let length: Byte = temp[0]
            if length < 1 {
                NSLog("test14 BlufiFramework parseWiFiScanList invalid length")
                break
            }
            let rssi: Byte = temp[1]
            read = dataIS.read(UnsafeMutableRawPointer(mutating: temp), maxLength: Int(length) - 1)
            if read != (Int(length) - 1) {
                NSLog("test14 BlufiFramework parseWiFiScanList invalid ssid data")
                break
            }
            let ssid = String(data: Data(temp), encoding: .utf8) ?? ""
            let response = BlufiScanResponse(type: 0x01, ssid: ssid, rssi: Int8(bitPattern: rssi))
            result.append(response)
        }
        dataIS.close()
        self.onDeviceScanList(list: result, status: .StatusSuccess)
    }
    
    private func onPostCustomData(data: Data, status code: BlufiStatusCode) {
        let delegate = blufiDelegate
        let client: BlufiClient = self
        if let delegate = delegate {
            callbackQueue.addOperation {
                delegate.blufi(client, didPostCustomData: data, status: code)
            }
        }
    }
    
    private func onReceiveCustomData(data: Data, status code: BlufiStatusCode) {
        let delegate = blufiDelegate
        let client: BlufiClient = self
        if let delegate = delegate {
            callbackQueue.addOperation {
                delegate.blufi(client, didReceiveCustomData: data, status: code)
            }
        }
    }

    private func parseWifiState(data: Data) {
        var code: BlufiStatusCode?
        var response: BlufiStatusResponse?
        if data.count < 3 {
            code = .StatusInvalidData
            response = nil
        } else {
            code = .StatusSuccess
            response = BlufiStatusResponse()
            let temp = [Byte] (repeating: 0, count: data.count)
            let dataIS = InputStream(data: data)
            dataIS.open()
            
            dataIS.read(UnsafeMutableRawPointer(mutating: temp), maxLength: 1)
            response?.opMode = OpMode(rawValue: Int(temp[0])) ?? .OpModeNull
            
            dataIS.read(UnsafeMutableRawPointer(mutating: temp), maxLength: 1)
            response?.staConnectionStatus = Int(temp[0])
            
            dataIS.read(UnsafeMutableRawPointer(mutating: temp), maxLength: 1)
            response?.softApConnectionCount = Int(temp[0])
            
            while dataIS.hasBytesAvailable {
                var read = dataIS.read(UnsafeMutableRawPointer(mutating: temp), maxLength: 2)
                if read != 2 {
                    code = .StatusInvalidData
                    break
                }
                
                let infoType: Byte = temp[0]
                let len: Byte = temp[1]
                read = dataIS.read(UnsafeMutableRawPointer(mutating: temp), maxLength: Int(len))
                
                if read != len {
                    NSLog("test14 BlufiFramework parseWifiState contain invalid data2")
                    code = .StatusInvalidData
                    break
                }
                self.parseWifiStateData(data: temp, length: Int(len), type: infoType, response: response)
            }
            dataIS.close()
        }
        self.onDeviceStatusResponse(response: response, status: code ?? .StatusInvalidData)
    }

    private func parseWifiStateData(data: [Byte], length: Int, type infoType: Byte, response: BlufiStatusResponse?) {
        guard let response = response else { return }
        switch Int(infoType) {
        case DataSubTypeStaBssid:
            let bssid = self.hexFromBytes(bytes: data, length: length)
            response.staBssid = bssid
        case DataSubTypeStaSsid:
            let ssid = String(data: Data(data), encoding: .utf8)
            response.staSsid = ssid
        case DataSubTypeStaPassword:
            let password = String(data: Data(data), encoding: .utf8)
            response.staPassword = password
        case DataSubTypeSoftAPAuthMode:
            response.softApSecurity = SoftAPSecurity(rawValue: Int(data[0])) ?? .SoftAPSecurityOpen
        case DataSubTypeSoftAPChannel:
            response.softApChannel = Int(data[0])
        case DataSubTypeSoftAPMaxConnection:
            response.softApMaxConnection = Int(data[0])
        case DataSubTypeSoftAPPassword:
            let password = String(data: Data(data), encoding: .utf8)
            response.softApPassword = password
        case DataSubTypeSoftAPSsid:
            let ssid = String(data: Data(data), encoding: .utf8)
            response.softApSsid = ssid
        default:
            break
        }
    }
}


// MARK: - Common Utilities
extension BlufiClient {
    private func generateSendSequence() -> Byte {
        sendSequence += 1
        let result = sendSequence & 0xff
        return Byte(result)
    }
    
    private func isConnected() -> Bool {
        return connectState == .StateConnected
    }
    
    private func gattWrite(data: Data) {
        writeCondition.lock()
        if !isConnected() {
            writeCondition.unlock()
            return
        }
        if let writeChar = writeChar {
            peripheral?.writeValue(data, for: writeChar, type: CBCharacteristicWriteType.withResponse)
        }
        writeCondition.wait()
        writeCondition.unlock()
    }

    private func receiveAck(expectAck: Byte) -> Bool {
        let number = deviceAck.dequeue()
        if let number = number as? Byte {
            let ack: Byte = number
            return ack == expectAck
        } else {
            return false
        }
    }
    
    private func post(data: Data?, encrypt: Bool, checksum: Bool, requireAck ack: Bool, type: Byte) -> Bool {
        if let data = data,
           data.count > 0 {
            return self.postContainData(data: data, encrypt: encrypt, checksum: checksum, requireAck: ack, type: type)
        } else {
            return self.postEmptyDataWithEncrypt(encrypt: encrypt, checksum: checksum, requireAck: ack, type: type)
        }
    }
    
    private func postEmptyDataWithEncrypt(encrypt: Bool, checksum: Bool, requireAck ack: Bool, type: Byte) -> Bool {
        let sequence = self.generateSendSequence()
        let postPacket = self.getPostPacket(data: nil, type: type, encrypt: encrypt, checksum: checksum, requireAck: ack, hasFrag: false, sequence: sequence)
        self.gattWrite(data: postPacket)
        return !ack || self.receiveAck(expectAck: sequence)
    }
    
    private func postContainData(data: Data, encrypt: Bool, checksum: Bool, requireAck ack: Bool, type: Byte) -> Bool {
        let dataIS = InputStream(data: data)
        var dataLengthLimit = postPackageLengthLimit - PACKAGE_HEADER_LENGTH
        dataLengthLimit -= 2
        if checksum {
            dataLengthLimit -= 2
        }
        let dataBuf = [Byte] (repeating: 0, count: dataLengthLimit)
        var available = data.count
        dataIS.open()
        
        while dataIS.hasBytesAvailable {
            var read = dataIS.read(UnsafeMutablePointer(mutating: dataBuf), maxLength: dataLengthLimit)
            if read == 0 {
                break
            }
            var dataContent = Data()
            available -= read
            dataContent.append(UnsafeMutablePointer(mutating: dataBuf), count: read)
            
            if available > 0 && available <= 2 {
                let last = [Byte] (repeating: 0, count: available)
                read = dataIS.read(UnsafeMutablePointer(mutating: last), maxLength: available)
                if read != available {
                    print("test14 BlufiFramework postContainData: read last bytes error: read=\(read), expect=\(available)")
                }
                dataContent.append(UnsafeMutablePointer(mutating: last), count: available)
                available -= read
            }
            
            let frag = dataIS.hasBytesAvailable
            if frag {
                let totalLen = UInt8(dataContent.count + available)
                var newDataContent = Data()
                var totalLenBytes: [Byte] = [totalLen & 0xff, totalLen >> 8 & 0xff]
                newDataContent.append(UnsafeMutablePointer(mutating: totalLenBytes), count: 2)
                newDataContent.append(dataContent)
            }
            
            let sequence = self.generateSendSequence()
            let postPacket = self.getPostPacket(data: dataContent, type: type, encrypt: encrypt, checksum: checksum, requireAck: ack, hasFrag: frag, sequence: sequence)
            self.gattWrite(data: postPacket)
            if frag {
                if ack && !self.receiveAck(expectAck: sequence) {
                    dataIS.close()
                    return false
                }
                Thread.sleep(forTimeInterval: 0.01)
            } else {
                dataIS.close()
                return !ack || self.receiveAck(expectAck: sequence)
            }
        }
        dataIS.close()
        return true
    }

    
    private func parseCtrlData(data: Data, subType: SubType) {
        if subType == CtrlSubTypeAck {
            self.parseAck(data: data)
        }
    }
    
    private func parseAck(data: Data) {
        var ack: Int = 0x100
        if data.count > 0 {
            ack = Int([Byte] (data)[0])
        }
        deviceAck.enqueue(object: ack)
    }

     internal func parseBlufiNotifyData(data: BlufiNotifyData) {
         guard let pkgType = data.packageType else { return }
         guard let subType = data.subType else { return }
         let dataContent = data.getdata()
         //        if let blufiDelegate = blufiDelegate {
         //            let complete = blufiDelegate.blufi(self, gattNotification: dataContent, packageType: pkgType, subType: subType)
         //            if complete {
         //                return
         //            }
         //        }
         
         switch pkgType {
         case .PackageCtrl:
             self.parseCtrlData(data: dataContent, subType: subType)
         case .PackageData:
             self.parseDataData(data: dataContent, subType: subType)
         }
     }
   
     internal func onError(errCode: Int) {
         let delegate = blufiDelegate
         let client: BlufiClient = self
         if let delegate = delegate {
             callbackQueue.addOperation {
                 delegate.blufi(client, didReceiveError: errCode)
             }
         }
     }

    internal func gattDiscoverCallback() {
        let delegate = blufiDelegate
        if let delegate = delegate {
            let client: BlufiClient = self
            let service = self.service
            let writeChar = self.writeChar
            let notifyChar = self.notifyChar
            let code: BlufiStatusCode = (service != nil) && (writeChar != nil) && (notifyChar != nil) ? .StatusSuccess: .StatusFailed
            callbackQueue.addOperation {
                if let service = service,
                   let writeChar = writeChar,
                   let notifyChar = notifyChar {
                    delegate.blufi(client, gattPrepared: code, service: service, writeChar: writeChar, notifyChar: notifyChar)
                }
            }
        }
    }
    
    
    internal func parseNotification(response: Data?, notification: BlufiNotifyData) -> NotifyStatus {
        guard let response = response else {
            return .NotifyNull
        }
        if response.count < 4 {
            return .NotifyInvalidLength
        }
        var buf: [Byte] = [Byte] (response)
        var sequence: Byte = buf[2]
        readSequence += 1
        var expectSequence: Byte = Byte(readSequence & 0xff)
        NSLog("test14 BlufiFramework readSequence is: \(readSequence)")
        if sequence != expectSequence {
            NSLog("test14 BlufiFramework parseNotification invalid sequence")
            return .NotifyInvalidSequence
        }
        
        var type: Byte = buf[0]
        let tmpVal = self.getPackageTypeWithTypeValue(typeValue: Int(type))
        var pkgType: PackageType = PackageType(rawValue: Int(tmpVal)) ?? .PackageData
        var subType: SubType = self.getSubTypeWithTypeValue(typeValue: Int(type))
        notification.typeValue = type
        notification.packageType = pkgType
        notification.subType = subType
        
        var frameCtrl: Byte = buf[1]
        notification.frameCtrl = Int(frameCtrl)
        var frameCtrlData = BlufiFrameCtrlData(value: frameCtrl)
        
        let dataLen = buf[3]
        let dataBuf = [Byte] (repeating: 0, count: Int(dataLen))
        let dataOffset: Byte = 4
        if (dataLen + dataOffset) > response.count {
            return .NotifyError
        }
        memcpy(UnsafeMutableRawPointer(mutating: dataBuf), UnsafeMutableRawPointer(mutating: buf) + UnsafeMutableRawPointer.Stride(dataOffset), Int(dataLen))
        var data = Data(bytes: UnsafeMutableRawPointer(mutating: dataBuf), count: Int(dataLen))
        
        if frameCtrlData.isChecksum {
            let respChecksum1 = buf[response.count - 1]
            let respChecksum2 = buf[response.count - 2]
            let checkBuf: [Byte] = [sequence, dataLen]
            var crc = BlufiSecurity.crc(0, buf: UnsafeMutableRawPointer(mutating: checkBuf), length: 2)
            crc = BlufiSecurity.crc(crc, data: data)
            let calcChecksum1: Byte = Byte(crc >> 8 & 0xff)
            let calcChecksum2: Byte = Byte(crc & 0xff)
            
            if respChecksum1 != calcChecksum1 || respChecksum2 != calcChecksum2 {
                NSLog("test14 BlufiFramework parseNotification invalid checksum")
                return .NotifyInvalidChecsum
            }
        }
        
        var appendData: Data?
        if frameCtrlData.hasFrag {
            let dataSegment = [Byte] (repeating: 0, count: Int(dataLen) - 2)
            memcpy(UnsafeMutableRawPointer(mutating: dataSegment), UnsafeMutableRawPointer(mutating: dataBuf) + UnsafeMutableRawPointer.Stride(2), Int(dataLen) - 2)
            appendData = Data(bytes: UnsafeMutableRawPointer(mutating: dataSegment), count: Int(dataLen) - 2)
        } else {
            appendData = Data(bytes: UnsafeMutableRawPointer(mutating: dataBuf), count: Int(dataLen))
        }
        if let appendData = appendData {
            notification.appendData(data: appendData)
        }
        return frameCtrlData.hasFrag ? .NotifyHasFrag : .NotifyComplete
    }
    private func getPostPacket(data: Data?, type: Byte, encrypt: Bool, checksum: Bool, requireAck ack: Bool, hasFrag: Bool, sequence: Byte) -> Data {
        var result = Data()
        let dataLength = data?.count ?? 0
        let  frameCtrl = BlufiFrameCtrlData().getFrameCtrlValueWithEncrypted(encrypted: encrypt, checksum: checksum, direction: .DataOutput, requireAck: ack, hasFrag: hasFrag)
        let header: [Byte] = [type, frameCtrl, sequence, UInt8(dataLength)]
        result.append(UnsafeMutablePointer(mutating: header), count: 4)
        var checksumData: Data?
        if checksum {
            var buf: [Byte] = [sequence, UInt8(dataLength)]
            var crc = BlufiSecurity.crc(0, buf: UnsafeMutablePointer(mutating: buf), length: 2)
            if dataLength > 0 {
                if let data = data {
                    crc = BlufiSecurity.crc(crc, data: data)
                }
            }
            buf[0] = Byte(crc & 0xff)
            buf[1] = Byte(crc >> 8 & 0xff)
            checksumData = Data(bytes: UnsafeMutablePointer(mutating: buf), count: 2)
        }
        if let data = data,
           data.count > 0 {
            result.append(data)
        }
        if let checksumData = checksumData {
            result.append(checksumData)
        }
        return result
    }
    
    private func hexFromBytes(bytes: [Byte], length: Int) -> String {
        var hex: String = ""
        for i in 0 ..< bytes.count {
            let b = bytes[i]
            if let val = self.hexFromUint4(b: b >> 4 & 0xf) {
                hex.append(val)
            }
            if let val = self.hexFromUint4(b: b & 0xf) {
                hex.append(val)
            }
        }
        return hex
    }
    
    private func hexFromUint4(b: Byte) -> String? {
        switch b {
        case 0: return "0"
        case 1: return "1"
        case 2: return "2"
        case 3: return "3"
        case 4: return "4"
        case 5: return "5"
        case 6: return "6"
        case 7: return "7"
        case 8: return "8"
        case 9: return "9"
        case 10: return "A"
        case 11: return "B"
        case 12: return "C"
        case 13: return "D"
        case 14: return "E"
        case 15: return "F"
        default: return nil
        }
    }
    
    private func getSubTypeWithTypeValue(typeValue: Int) -> SubType {
        return SubType(((typeValue & 0b11111100) >> 2))
    }
    
    private func generateAESIV(sequence: Byte) -> Data {
        var buf = Array<Byte>(repeating: 0, count: 16)
        buf[0] = sequence
        return Data(buf)
    }
    
    private func getPackageTypeWithTypeValue(typeValue: Int) -> SubType {
        return SubType(((typeValue & 0b11111100) >> 2))
    }
    
    
    private func getTypeValueWithPackageType(pkgType: PackageType, subType: SubType) -> Byte {
        let result = subType << 2 | UInt32(pkgType.rawValue)
        return Byte(result & 0xff)
    }
    
    private func setPostPackageLengthLimit(postPackageLengthLimit: Int) {
        if postPackageLengthLimit <= PACKAGE_LENGTH_MIN {
            self.postPackageLengthLimit = PACKAGE_LENGTH_MIN
        } else {
            self.postPackageLengthLimit = postPackageLengthLimit
        }
    }

    private func parseDataData(data: Data, subType: SubType) {
        switch Int(subType) {
        case DataSubTypeNeg:
            if !closed {
                deviceKey.enqueue(object: data)
            }
        case DataSubTypeVersion:
            self.parseVersion(data: data)
        case DataSubTypeWiFiConnectionState:
            self.parseWifiState(data: data)
        case DataSubTypeWiFiList:
            self.parseWiFiScanList(data: data)
        case DataSubTypeCustomData:
            self.onReceiveCustomData(data: data, status: .StatusSuccess)
        case DataSubTypeError:
            let bytes = [UInt8] (data)
            let errCode = data.count > 0 ? Int(bytes[0]): 300
            self.onError(errCode: errCode)
        default:
            break
        }
    }
}
