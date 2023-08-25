//
//  Arch.swift
//  
//
//  Created by Mihael Isaev on 23.12.2022.
//

import Foundation
import WebberTools

struct Arch {
    enum ArchError: Error, CustomStringConvertible {
        case unableToGetCurrentArchitecture
        
        var description: String {
            switch self {
            case .unableToGetCurrentArchitecture: return "Unable to get architecture of the current system"
            }
        }
    }
    
    /// Returns current architecture
    static func get() throws -> String {
        let stdout = Pipe()
        let process = Process()
        process.launchPath = try Bash.which("uname")
        process.arguments = ["-m"]
        process.standardOutput = stdout
        
        let outHandle = stdout.fileHandleForReading

        process.launch()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw ArchError.unableToGetCurrentArchitecture
        }
        
        let data = outHandle.readDataToEndOfFile()
        guard data.count > 0, let path = String(data: data, encoding: .utf8) else {
            throw ArchError.unableToGetCurrentArchitecture
        }
        return path.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
