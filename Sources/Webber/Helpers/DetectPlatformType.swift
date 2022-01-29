//
//  DetectPlatformType.swift
//  
//
//  Created by Mihael Isaev on 29.01.2022.
//

import Foundation

func isAppleSilicon() -> Bool {
    var systeminfo = utsname()
    uname(&systeminfo)
    let machine = withUnsafeBytes(of: &systeminfo.machine) { bufPtr -> String in
        let data = Data(bufPtr)
        if let lastIndex = data.lastIndex(where: {$0 != 0}) {
            return String(data: data[0...lastIndex], encoding: .isoLatin1)!
        } else {
            return String(data: data, encoding: .isoLatin1)!
        }
    }
    return machine == "arm64"
}
