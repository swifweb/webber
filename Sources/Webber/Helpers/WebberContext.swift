//
//  WebberContext.swift
//  Webber
//
//  Created by Mihael Isaev on 01.02.2021.
//

import Vapor

class WebberContext {
    private(set) lazy var defaultToolchainVersion = "wasm-5.6.0-RELEASE"
    
    #if os(macOS)
    private(set) lazy var toolchainPaths: [String] = [
        "/Library/Developer/Toolchains",
        "~/Library/Developer/Toolchains"
    ]
    #else
    private(set) lazy var toolchainPaths: [String] = ["/opt"]
    #endif
    
    #if os(macOS)
    let toolchainExtension = ".xctoolchain"
    #else
    let toolchainExtension = ""
    #endif
    
    let dir: DirectoryConfiguration
    let command: CommandContext
    
    lazy var toolchainFolder = "swift-" + toolchainVersion + toolchainExtension
    
    private var toolchainVersion: String {
        let path = URL(fileURLWithPath: dir.workingDirectory).appendingPathComponent(".swift-version").path
        guard let data = FileManager.default.contents(atPath: path), let str = String(data: data, encoding: .utf8), str.hasPrefix("wasm-") else {
            return defaultToolchainVersion
        }
        return str
    }
    
    init (dir: DirectoryConfiguration, command: CommandContext) {
        self.dir = dir
        self.command = command
    }
}
