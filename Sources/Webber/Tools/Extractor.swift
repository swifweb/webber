//
//  Extractor.swift
//  Webber
//
//  Created by Mihael Isaev on 02.02.2021.
//

import Foundation

struct Extractor {
    enum ExtractorError: Error, CustomStringConvertible {
        case brokenStdout
        case somethingWentWrong(code: Int32)
        
        var description: String {
            switch self {
            case .brokenStdout: return "Unable to read stdout"
            case .somethingWentWrong(let code): return "Extractor failed with code \(code)"
            }
        }
    }
    
    static func extract(archive archivePath: URL, dest destinationPath: URL) throws {
        let stdout = Pipe()
        let stderr = Pipe()
        
        let process = Process()
        
        #if os(macOS)
        process.launchPath = "/usr/bin/tar"
        #else
        process.launchPath = "/bin/tar"
        #endif
        
        process.arguments = ["xzf", archivePath.path, "--strip-components=1", "--directory", destinationPath.path]
        process.standardOutput = stdout
        process.standardError = stderr
        
        let outHandle = stdout.fileHandleForReading
        outHandle.waitForDataInBackgroundAndNotify()
        
        process.launch()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw ExtractorError.somethingWentWrong(code: process.terminationStatus)
        }
    }
}
