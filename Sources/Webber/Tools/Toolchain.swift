//
//  Toolchain.swift
//  Webber
//
//  Created by Mihael Isaev on 01.02.2021.
//

import Foundation
import ConsoleKit

class Toolchain {
    let context: WebberContext
    
    private(set) var toolchainPath: String?
    
    private var _swiftPath: String? {
        guard let path = toolchainPath else { return nil }
        return URL(fileURLWithPath: path).appendingPathComponent("swift").path
    }
    
    init (_ context: WebberContext) {
        self.context = context
        lookup()
    }
    
    enum ToolchainError: Error, CustomStringConvertible {
        case toolchainNotFound
        
        var description: String {
            switch self {
            case .toolchainNotFound: return "Toolchain not found"
            }
        }
    }
    
    func pathToSwift() throws -> String {
        try lookupOrInstall()
        guard let path = _swiftPath else {
            throw ToolchainError.toolchainNotFound
        }
        return path
    }
    
    private var isLookedUp = false
    
    func lookupOrInstall() throws {
        guard !isLookedUp else {
            return
        }
        isLookedUp = true
        guard let toolchainPath = self.toolchainPath else {
            let localURL = try ToolchainRetriever(self.context).retrieve()
            #if os(macOS)
            try Installer.install(localURL)
            #else
            try Extractor.extract(archive: localURL, dest: URL(fileURLWithPath: "/opt/" + self.context.toolchainFolder))
            #endif
            lookup()
            guard let toolchainPath = self.toolchainPath else {
                throw ToolchainError.toolchainNotFound
            }
            context.command.console.output([
                ConsoleTextFragment(string: "Toolchain has been installed at ", style: .init(color: .brightGreen)),
                ConsoleTextFragment(string: toolchainPath, style: .init(color: .brightYellow))
            ])
            return
        }
        context.command.console.output([
            ConsoleTextFragment(string: "Toolchain has been found at ", style: .init(color: .brightGreen)),
            ConsoleTextFragment(string: toolchainPath, style: .init(color: .brightYellow))
        ])
    }
    
    private func lookup() {
        for path in context.toolchainPaths {
            var isDir : ObjCBool = false
            let url = URL(fileURLWithPath:
                            path.hasPrefix("~/")
                            ? path.replacingOccurrences(of: "~", with: FileManager.default.homeDirectoryForCurrentUser.path)
                            : path
            )
            .appendingPathComponent(context.toolchainFolder)
            .appendingPathComponent("usr")
            .appendingPathComponent("bin")
            let path: String = url.appendingPathComponent("swift").path
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir) else {
                continue
            }
            self.toolchainPath = url.path
        }
    }
}
