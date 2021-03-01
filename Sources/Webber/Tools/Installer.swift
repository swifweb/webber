//
//  Installer.swift
//  Webber
//
//  Created by Mihael Isaev on 02.02.2021.
//

import Foundation

struct Installer {
    enum InstallerError: Error, CustomStringConvertible {
        case unavailableOnLinux
        case brokenStdout
        case somethingWentWrong(code: Int32)
        
        var description: String {
            switch self {
            case .unavailableOnLinux: return "macOS package installer is not available on Linux"
            case .brokenStdout: return "Unable to read stdout"
            case .somethingWentWrong(let code): return "Installer failed with code \(code)"
            }
        }
    }
    
    static func install(_ url: URL) throws {
        #if !os(macOS)
        throw InstallerError.unavailableOnLinux
        #endif
        let stdout = Pipe()
        let stderr = Pipe()
        let process = Process()
        process.launchPath = "/usr/sbin/installer"
        process.arguments = ["-target", "CurrentUserHomeDirectory", "-pkg", url.path]
        process.standardOutput = stdout
        process.standardError = stderr
        
        let outHandle = stdout.fileHandleForReading
        outHandle.waitForDataInBackgroundAndNotify()

        process.launch()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw InstallerError.somethingWentWrong(code: process.terminationStatus)
        }
    }
}
