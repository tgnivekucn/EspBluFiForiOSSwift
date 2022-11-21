//
//  BlufiCient+CentralManagerDelegate.swift
//  BlufiSwiftFramework
//
//  Created by SomnicsAndrew on 2022/11/17.
//

import Foundation
import CoreBluetooth

extension BlufiClient: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        blePowerOn = (central.state == .poweredOn)
        if blePowerOn {
            NSLog("test14 BlufiFramework Blufi Client BLE state pwoered on")
            self.scanBLE()
//            if bleConnectMark {
//                bleConnectMark = false
//            }
        }
        if let delegate = centralManagerDelete {
            callbackQueue.addOperation {
                delegate.centralManagerDidUpdateState(central)
            }
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if peripheral.identifier == identifier {
            central.stopScan()
            self.peripheral = peripheral
            peripheral.delegate = self
            readSequence = -1
            sendSequence = -1
            NSLog("test14 BlufiFramework _readSequence is:  \(readSequence), _readSequence/_sendSequence already be reset")
            NSLog("test14 BlufiFramework call connectPeripheral api, name & UUID is: \(peripheral.name), \(peripheral.identifier.uuidString)")
            central.connect(peripheral)
        }
        
        if let delegate = centralManagerDelete {
            callbackQueue.addOperation {
                delegate.centralManager?(central, didDiscover: peripheral, advertisementData: advertisementData, rssi: RSSI)
            }
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let uuid = CBUUID(string: UUID_SERVICE)
        var filters: [CBUUID] = [uuid]
        peripheral.discoverServices(filters)
        
        connectState = .StateConnected

        if let delegate = centralManagerDelete {
            callbackQueue.addOperation {
                delegate.centralManager?(central, didConnect: peripheral)
            }
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        self.clearConnection()
        
        if let delegate = centralManagerDelete {
            callbackQueue.addOperation {
                delegate.centralManager?(central, didFailToConnect: peripheral, error: error)
            }
        }
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        self.clearConnection()

        if let delegate = centralManagerDelete {
            callbackQueue.addOperation {
                delegate.centralManager?(central, didDisconnectPeripheral: peripheral, error: error)
            }
        }
    }
    
    public func centralManager(_ central: CBCentralManager, connectionEventDidOccur event: CBConnectionEvent, for peripheral: CBPeripheral) {
        if #available(iOS 13.0, *) {
            if let delegate = centralManagerDelete {
                callbackQueue.addOperation {
                    delegate.centralManager?(central, connectionEventDidOccur: event, for: peripheral)
                }
            }
        }
      
    }
    
    public func centralManager(_ central: CBCentralManager, didUpdateANCSAuthorizationFor peripheral: CBPeripheral) {
        if #available(iOS 13.0, *) {
            if let delegate = centralManagerDelete {
                callbackQueue.addOperation {
                    delegate.centralManager?(central, didUpdateANCSAuthorizationFor: peripheral)
                }
            }
        }
    }
    
    public func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        if let delegate = centralManagerDelete {
            callbackQueue.addOperation {
                delegate.centralManager?(central, willRestoreState: dict)
            }
        }
    }
}
