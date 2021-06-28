//
//  File.swift
//  
//
//  Created by Mihael Isaev on 09.02.2021.
//

import Foundation
import ConsoleKit
import WebberTools

private let programName = "npm"

struct Npm {
    let console: Console
    let launchPath, cwd: String
    
    init (_ console: Console, _ cwd: String) throws {
        self.console = console
        self.cwd = cwd
        if !Bash.whichBool(programName) {
            guard console.confirm([
                ConsoleTextFragment(string: programName, style: .init(color: .brightYellow, isBold: true)),
                ConsoleTextFragment(string: " is not installed, would you like to install it?", style: .init(color: .none))
            ]) else {
                throw NpmError.error("\(programName) is required to prepare web files, please install it manually then")
            }
            try Brew.install(programName)
        }
        launchPath = try Bash.which(programName)
    }
    
    func install() throws {
        guard !isNodeModulesFolderExists() else { return }
        let stdout = Pipe()
        let process = Process()
        process.currentDirectoryPath = cwd
        process.launchPath = launchPath
        process.arguments = ["install", "--quiet", "--no-progress"]
        process.standardOutput = stdout
        
        let outHandle = stdout.fileHandleForReading
        outHandle.waitForDataInBackgroundAndNotify()

        process.launch()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw NpmError.unableToInstall
        }
    }
    
    func addDevDependencies() throws {
        let packages = [
            "@wasmer/wasi",
            "@wasmer/wasmfs",
            "javascript-kit-swift",
            "reconnecting-websocket",
            "webpack",
            "webpack-cli"
        ]
        let installedPackages = try list()
        try packages.forEach {
            guard !installedPackages.contains($0) else { return }
            try addDependency($0, dev: true)
        }
    }
    
    func addDependency(_ packageName: String, dev: Bool = false) throws {
        let stdout = Pipe()
        let process = Process()
        process.currentDirectoryPath = cwd
        process.launchPath = launchPath
        process.arguments = ["install", packageName, dev ? "--save-dev" : "--save-prod", "--quiet", "--no-progress"]
        process.standardOutput = stdout
        
        let outHandle = stdout.fileHandleForReading
        outHandle.waitForDataInBackgroundAndNotify()

        process.launch()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw NpmError.unableToInstall
        }
    }
    
    func installAllGlobalPackages() throws {
        try installGlobalPackage("webpack-cli")
    }
    
    func installGlobalPackage(_ packageName: String) throws {
        guard !Bash.whichBool(packageName) else { return }
        let stdout = Pipe()
        let process = Process()
        process.currentDirectoryPath = cwd
        process.launchPath = launchPath
        process.arguments = ["install", packageName, "-g", "--quiet", "--no-progress"]
        process.standardOutput = stdout
        
        let outHandle = stdout.fileHandleForReading
        outHandle.waitForDataInBackgroundAndNotify()

        process.launch()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw NpmError.unableToInstall
        }
    }
    
    func isNodeModulesFolderExists() -> Bool {
        let path = URL(fileURLWithPath: cwd)
            .appendingPathComponent("node_modules")
            .path
        var isDir : ObjCBool = true
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
    }
    
    func list() throws -> String {
        guard isNodeModulesFolderExists() else { return "" }
        let stdout = Pipe()
        let process = Process()
        process.currentDirectoryPath = cwd
        process.launchPath = launchPath
        process.arguments = ["list", "--depth=0"]
        process.standardOutput = stdout
        
        let outHandle = stdout.fileHandleForReading

        process.launch()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw NpmError.unableToInstall
        }
        let data = outHandle.readDataToEndOfFile()
        guard data.count > 0, let list = String(data: data, encoding: .utf8) else {
            throw NpmError.error("Unable to get list of packages from npm")
        }
        return list
    }
    
    enum NpmError: Error, CustomStringConvertible {
        case unableToInstall
        case error(String)
        
        var description: String {
            switch self {
            case .unableToInstall: return "`npm install` command failed"
            case .error(let description): return description
            }
        }
    }
}
