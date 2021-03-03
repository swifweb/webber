//
//  IpConfig.swift
//  Webber
//
//  Created by Mihael Isaev on 10.02.2021.
//

import Foundation

struct IpConfig {
    static func getLocalIPs() -> [String] {
        ["en0", "en1", "en2", "en3", "en4"].compactMap {
            try? getIP(at: $0)
        } + ["127.0.0.1"]
    }
    
    static func getIP(at interface: String) throws -> String? {
        let stdout = Pipe()
        let process = Process()
        process.launchPath = try Bash.which("ipconfig")
        process.arguments = ["getifaddr", interface]
        process.standardOutput = stdout
        
        let outHandle = stdout.fileHandleForReading
        
        process.launch()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            return nil
        }
        
        let data = outHandle.readDataToEndOfFile()
        guard data.count > 0, let path = String(data: data, encoding: .utf8) else {
            return nil
        }
        return path.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
