//
//  ViewController.swift
//  EspBluFiForiOSSwift
//
//  Created by SomnicsAndrew on 2022/11/21.
//

import UIKit

class ViewController: UIViewController {
    var device: BlufiDevice!
    var deviceUUID = "Your bluetooth device UUID" // TODO: MUST FIX
    let yourCustomRequest = "123456789"
    override func viewDidLoad() {
        super.viewDidLoad()
        // 1. Setup delegate & connect device by UUID
        device = BlufiDevice(delegate: self)
        device.connect(uuid: deviceUUID)
        
        // 2. Do what you want
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self = self else { return }
            self.device.postCustomData(request: self.yourCustomRequest)
            self.device.requestDeviceVersion()
        }
    }
}

extension ViewController: BlufiDeviceProtocol {
    func updateDeviceMessage(message: String) {
        print("test11 message: \(message)")
    }
}

