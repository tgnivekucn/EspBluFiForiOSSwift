//
//  BlufiFrameCtrlData.swift
//  BlufiSwiftFramework
//
//  Created by SomnicsAndrew on 2022/11/15.
//

import Foundation

class BlufiFrameCtrlData: NSObject {
    var isEncrypted: Bool {
        return self.check(position: UInt32(PositionEncrypted))
    }
    var isChecksum: Bool {
        return self.check(position: UInt32(PositionChecksum))
    }
    var isAckRequirement: Bool {
        return self.check(position: UInt32(PositionRequireAck))
    }
    var hasFrag: Bool {
        return self.check(position: UInt32(PositionFrag))
    }
    var value: Byte

    let PositionEncrypted = 0
    let PositionChecksum = 1
    let PositionDataDirection = 2
    let PositionRequireAck = 3
    let PositionFrag = 4
    
    init(value: Byte = 0) {
        self.value = value
    }
    
    func getFrameCtrlValueWithEncrypted(encrypted: Bool, checksum: Bool, direction: DataDirection, requireAck ack: Bool, hasFrag frag: Bool) -> Byte {
        var frame: Byte = 0
        if encrypted {
            frame |= (1 << PositionEncrypted)
        }
        if checksum {
            frame |= (1 << PositionChecksum)
        }
        if direction == .DataInput {
            frame |= (1 << PositionDataDirection)
        }
        if ack {
            frame |= (1 << PositionRequireAck)
        }
        if frag {
            frame |= (1 << PositionFrag)
        }
        return frame
    }
    
    func check(position: UInt32) -> Bool {
        return (value >> position & 1) == 1
    }
}
