//
//  BlufiClient+CBPeripheralDelegate.swift
//  BlufiSwiftFramework
//
//  Created by SomnicsAndrew on 2022/11/17.
//

import Foundation
import CoreBluetooth

extension BlufiClient: CBPeripheralDelegate {
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            NSLog("test14 BlufiFramework didDiscoverServices error: \(error)")
            self.clearConnection()
            self.gattDiscoverCallback()
        } else {
            var services: [CBService]? = peripheral.services
            if let services = services {
                for service in services {
                    if service.uuid.uuidString == UUID_SERVICE {
                        self.service = service
                        break
                    }
                }
            }
            
            if let service = self.service,
                let serviceItem = services?[0] {
                    peripheral.discoverCharacteristics(nil, for: service)
                    self.service = serviceItem
            } else {
                NSLog("test14 BlufiFramework didDiscoverServices failed")
                self.gattDiscoverCallback()
                self.clearConnection()
            }
        }
        
        if let delegate = peripheralDelegate {
            delegate.peripheral?(peripheral, didDiscoverServices: error)
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            NSLog("test14 BlufiFramework didDiscoverCharacteristicsForService error: \(error)")
            self.gattDiscoverCallback()
            self.clearConnection()
        } else {
            var writeChar: CBCharacteristic? = nil
            var notifyChar: CBCharacteristic? = nil
            var characteristics: [CBCharacteristic] = service.characteristics ?? []
            for c in characteristics {
                if c.uuid.uuidString == writeUUID.uuidString {
                    NSLog("test14 BlufiFramework didDiscoverCharacteristicsForService get write char")
                    writeChar = c
                } else if c.uuid.uuidString == notifyUUID.uuidString {
                    NSLog("test14 BlufiFramework didDiscoverCharacteristicsForService get notify char")
                    notifyChar = c
                }
            }
            self.writeChar = writeChar
            self.notifyChar = notifyChar
            if (writeChar == nil) || (notifyChar == nil) {
                NSLog("test14 BlufiFramework didDiscoverCharacteristicsForService failed")
                self.gattDiscoverCallback()
                self.clearConnection()
            } else {
                if let notifyChar = notifyChar {
                    peripheral.setNotifyValue(true, for: notifyChar)
                }
            }
        }
        
        if let delegate = peripheralDelegate {
            callbackQueue.addOperation {
                delegate.peripheral?(peripheral, didDiscoverCharacteristicsFor: service, error: error)
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            NSLog("test14 BlufiFramework didUpdateNotificationStateForCharacteristic error: \(error)")
            self.gattDiscoverCallback()
            self.clearConnection()
        } else {
            self.gattDiscoverCallback()
        }
        
        if let delegate = peripheralDelegate {
            callbackQueue.addOperation {
                delegate.peripheral?(peripheral, didUpdateNotificationStateFor: characteristic, error: error)
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            self.clearConnection()
        } else {
            if self.notifyData == nil {
                self.notifyData = BlufiNotifyData()
            }
            
            let value = characteristic.value
            if let notifyData = self.notifyData {
                let status: NotifyStatus = self.parseNotification(response: value, notification: notifyData)
                switch status {
                case .NotifyComplete:
                    self.parseBlufiNotifyData(data: notifyData)
                    self.notifyData = nil
                    break
                case .NotifyHasFrag:
                    NSLog("test14 BlufiFramework parseNotification wait next")
                default:
                    NSLog("test14 BlufiFramework parseNotification failed")
                    self.onError(errCode: BlufiStatusCode.StatusInvalidData.rawValue)
                    break
                }
            }
        }
        
        if let delegate = peripheralDelegate {
            callbackQueue.addOperation {
                delegate.peripheral?(peripheral, didUpdateValueFor: characteristic, error: error)
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        writeCondition.lock()
        writeCondition.signal()
        writeCondition.unlock()
        if let error = error {
            NSLog("test14 BlufiFramework didWriteValueForCharacteristic error: \(error)")
            self.clearConnection()
        }
        
        if let delegate = peripheralDelegate {
            callbackQueue.addOperation {
                delegate.peripheral?(peripheral, didWriteValueFor: characteristic, error: error)
            }
        }
    }
    
    public func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
        if let delegate = peripheralDelegate {
            callbackQueue.addOperation {
                delegate.peripheralDidUpdateName?(peripheral)
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        if let delegate = peripheralDelegate {
            callbackQueue.addOperation {
                delegate.peripheral?(peripheral, didModifyServices: invalidatedServices)
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        if let delegate = peripheralDelegate {
            callbackQueue.addOperation {
                delegate.peripheral?(peripheral, didReadRSSI: RSSI, error: error)
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverIncludedServicesFor service: CBService, error: Error?) {
        if let delegate = peripheralDelegate {
            callbackQueue.addOperation {
                delegate.peripheral?(peripheral, didDiscoverIncludedServicesFor: service, error: error)
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        if let delegate = peripheralDelegate {
            callbackQueue.addOperation {
                delegate.peripheral?(peripheral, didDiscoverDescriptorsFor: characteristic, error: error)
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
        if let delegate = peripheralDelegate {
            callbackQueue.addOperation {
                delegate.peripheral?(peripheral, didUpdateValueFor: descriptor, error: error)
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
        if let delegate = peripheralDelegate {
            callbackQueue.addOperation {
                delegate.peripheral?(peripheral, didWriteValueFor: descriptor, error: error)
            }
        }
    }

    public func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        if let delegate = peripheralDelegate {
            callbackQueue.addOperation {
                delegate.peripheralIsReady?(toSendWriteWithoutResponse: peripheral)
            }
        }
    }
    
    public func peripheral(_ peripheral: CBPeripheral, didOpen channel: CBL2CAPChannel?, error: Error?) {
        if let delegate = peripheralDelegate {
            callbackQueue.addOperation {
                delegate.peripheral?(peripheral, didOpen: channel, error: error)
            }
        }
    }
}
