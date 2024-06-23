//
//  WebberContext.swift
//  Webber
//
//  Created by Mihael Isaev on 01.02.2021.
//

import Vapor
import ConsoleKit

private var _defaultToolchainVersion = "wasm-5.10.0-RELEASE"

class WebberContext {
    private(set) lazy var defaultToolchainVersion = _defaultToolchainVersion
    
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
    
    let customToolchain: String?
    let dir: DirectoryConfiguration
    let command: CommandContext
    let verbose: Bool
    let debugVerbose: Bool
    let port: Int
    let browserType: BrowserType?
    let browserSelfSigned: Bool
    let browserIncognito: Bool
    let console: Console
    let customSwiftVersion: String?
    let ignoreCustomSwiftVersion: Bool
    
    lazy var toolchainFolder = "swift-" + toolchainVersion + toolchainExtension
    
    private var toolchainVersion: String {
        if let customToolchain = customToolchain {
            let cleaned = customToolchain.replacingOccurrences(of: "swift-", with: "")
            if cleaned.hasPrefix("wasm-") {
                defaultToolchainVersion = cleaned
                return cleaned
            }
            if cleaned.contains("SNAPSHOT") {
                self.command.console.output([
                    ConsoleTextFragment(string: "YOU ARE ON PRE-RELEASE TOOLCHAIN", style: .init(color: .magenta, isBold: true))
                ])
            }
            defaultToolchainVersion = "wasm-" + cleaned
            return defaultToolchainVersion
        }
        return customSwiftVersion ?? defaultToolchainVersion
    }
    
    init (
        customToolchain: String?,
        dir: DirectoryConfiguration,
        command: CommandContext,
        verbose: Bool,
        debugVerbose: Bool,
        ignoreCustomSwiftVersion: Bool,
        port: Int,
        browserType: BrowserType?,
        browserSelfSigned: Bool,
        browserIncognito: Bool,
        console: Console
    ) {
        self.customToolchain = customToolchain
        self.dir = dir
        self.command = command
        if debugVerbose {
            self.verbose = debugVerbose
        } else {
            self.verbose = verbose
        }
        self.debugVerbose = debugVerbose
        self.ignoreCustomSwiftVersion = ignoreCustomSwiftVersion
        self.port = port
        self.browserType = browserType
        self.browserSelfSigned = browserSelfSigned
        self.browserIncognito = browserIncognito
        self.console = console
        if !ignoreCustomSwiftVersion {
            let swiftVersionPath = URL(fileURLWithPath: dir.workingDirectory).appendingPathComponent(".swift-version").path
            if let data = FileManager.default.contents(atPath: swiftVersionPath), let swiftVersion = String(data: data, encoding: .utf8), swiftVersion.hasPrefix("wasm-") {
                let v = swiftVersion.trimmingCharacters(in: .whitespacesAndNewlines)
                if _defaultToolchainVersion != v {
                    self.customSwiftVersion = v
                    // TODO: add check for silent mode
                    console.output([
                        ConsoleTextFragment(string: "Using .swift-version: \(v)", style: .init(color: .brightMagenta, isBold: true))
                    ])
                } else {
                    self.customSwiftVersion = nil
                }
            } else {
                self.customSwiftVersion = nil
            }
        } else {
            self.customSwiftVersion = nil
        }
    }
    
    func debugVerbose(_ text: String) {
        guard debugVerbose else { return }
        console.output([
            ConsoleTextFragment(string: "D: \(text)", style: .init(color: .brightRed, isBold: false))
        ])
    }
}
