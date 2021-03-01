//
//  Brew.swift
//  Webber
//
//  Created by Mihael Isaev on 09.02.2021.
//

import Foundation

struct Brew {
    enum BrewError: Error, CustomStringConvertible {
        case unableToInstall(program: String)
        
        var description: String {
            switch self {
            case .unableToInstall(let program): return "Unable to install `\(program)`"
            }
        }
    }
    
    static func install(_ program: String) throws {
        let stdout = Pipe()
        let process = Process()
        process.launchPath = try Bash.which("brew")
        process.arguments = ["install", program]
        process.standardOutput = stdout
        
        let outHandle = stdout.fileHandleForReading
        outHandle.waitForDataInBackgroundAndNotify()

        process.launch()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw BrewError.unableToInstall(program: program)
        }
    }
}
