//
//  OpenSSL.swift
//  Webber
//
//  Created by Mihael Isaev on 10.02.2021.
//

import Foundation
import WebberTools

struct OpenSSL {
    enum OpenSSLError: Error, CustomStringConvertible {
        case error(String)
        
        var description: String {
            switch self {
            case .error(let description): return description
            }
        }
    }
    
    static func generate(at path: String, keyName: String, certName: String, configName: String) throws {
        let stdout = Pipe()
        let process = Process()
        process.launchPath = try Bash.which("openssl")
        process.currentDirectoryPath = path
        process.arguments = [
            "req",
            "-x509",
            "-days", "3650",
            "-keyout", keyName,
            "-out", certName,
            "-newkey", "rsa:2048",
            "-nodes",
            "-sha256",
            "-subj", "/CN=0.0.0.0",
            "-extensions", "EXT",
            "-config", configName
        ]
        process.standardOutput = stdout
        
        let outHandle = stdout.fileHandleForReading
        outHandle.waitForDataInBackgroundAndNotify()

        process.launch()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw OpenSSLError.error("Unable to generate self-signed SSL certificate")
        }
    }
}
