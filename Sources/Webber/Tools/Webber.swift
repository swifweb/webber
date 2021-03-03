//
//  Webber.swift
//  Webber
//
//  Created by Mihael Isaev on 09.02.2021.
//

import Foundation
import ConsoleKit

struct Webber {
    private struct NewNpmPackage: Encodable {
        let name = "webber"
        let version = "1.0.0"
    }
    
    let console: Console
    let context: WebberContext
    let webberFolder = ".webber"
    let cwd: String
    var entrypoint: String {
        URL(fileURLWithPath: cwd).appendingPathComponent("entrypoint").path
    }
    var entrypointDev: String {
        URL(fileURLWithPath: entrypoint).appendingPathComponent("dev").path
    }
    var entrypointDevSSL: String {
        URL(fileURLWithPath: entrypointDev).appendingPathComponent(".ssl").path
    }
    
    init (_ context: WebberContext) throws {
        self.console = context.command.console
        self.context = context
        cwd = URL(fileURLWithPath: context.dir.workingDirectory).appendingPathComponent(webberFolder).path
        try checkOrCreateCWD()
        try checkOrCreatePackageFile()
    }
    
    func cook(dev: Bool, appTarget: String, serviceWorkerTarget: String, type appType: AppType) throws {
        let startedAt = Date()
        let preparingBar = console.loadingBar(title: "Cooking web files")
        preparingBar.start()
        try installDependencies()
        try checkOrCreateEntrypoint()
        let point = self.point(dev)
        try createPointFolderInsideEntrypoint(dev: dev)
        var isDir : ObjCBool = false
        let appJSURL = URL(fileURLWithPath: entrypoint)
            .appendingPathComponent(point)
            .appendingPathComponent(appTarget + ".js")
        let appJSPath = appJSURL.path
        if !FileManager.default.fileExists(atPath: appJSPath, isDirectory: &isDir) {
            let js = self.js(dev: dev, wasmFilename: appTarget, type: appType)
            guard let data = js.data(using: .utf8), FileManager.default.createFile(atPath: appJSPath, contents: data) else {
                throw WebberError.error("Unable to create \(appJSURL.lastPathComponent) file")
            }
        }
        let destURL = URL(fileURLWithPath: cwd).appendingPathComponent(point)
        try webpack(dev: dev, jsFile: appJSURL.lastPathComponent, destURL: destURL)
        let serviceWorkerJSURL = URL(fileURLWithPath: entrypoint)
            .appendingPathComponent(point)
            .appendingPathComponent(serviceWorkerTarget + ".js")
        let serviceWorkerJSPath = serviceWorkerJSURL.path
        if appType == .pwa {
            if !FileManager.default.fileExists(atPath: serviceWorkerJSPath, isDirectory: &isDir) {
                let js = self.js(dev: dev, wasmFilename: serviceWorkerTarget, type: appType, serviceWorker: true)
                guard let data = js.data(using: .utf8), FileManager.default.createFile(atPath: serviceWorkerJSPath, contents: data) else {
                    throw WebberError.error("Unable to create \(serviceWorkerJSURL.lastPathComponent) file")
                }
            }
            try webpack(dev: dev, jsFile: serviceWorkerJSURL.lastPathComponent, destURL: destURL)
        }
        let indexHTMLURL = URL(fileURLWithPath: entrypoint)
            .appendingPathComponent(point)
            .appendingPathComponent("index.html")
        let indexHTMLPath = indexHTMLURL.path
        if !FileManager.default.fileExists(atPath: indexHTMLPath, isDirectory: &isDir) {
            let index = self.index(
                dev: dev,
                appJS: appJSURL.lastPathComponent,
                swJS: serviceWorkerJSURL.lastPathComponent,
                type: appType
            )
            guard let data = index.data(using: .utf8), FileManager.default.createFile(atPath: indexHTMLPath, contents: data) else {
                throw WebberError.error("Unable to create \(indexHTMLURL.lastPathComponent) file")
            }
        }
        let newIndexPath = destURL
            .appendingPathComponent(indexHTMLURL.lastPathComponent)
            .path
        try? FileManager.default.removeItem(atPath: newIndexPath)
        try FileManager.default.copyItem(atPath: indexHTMLPath, toPath: newIndexPath)
        preparingBar.succeed()
        console.clear(.line)
        console.output([
            ConsoleTextFragment(string: "Cooked web files in ", style: .init(color: .brightBlue, isBold: true)),
            ConsoleTextFragment(string: String(format: "%.2fs", Date().timeIntervalSince(startedAt)), style: .init(color: .brightMagenta))
        ])
    }
    
    private func createPointFolderInsideEntrypoint(dev: Bool) throws {
        let point = self.point(dev)
        let pointPath = URL(fileURLWithPath: entrypoint)
            .appendingPathComponent(point)
            .path
        var isDir : ObjCBool = true
        if !FileManager.default.fileExists(atPath: pointPath, isDirectory: &isDir) {
            try FileManager.default.createDirectory(atPath: pointPath, withIntermediateDirectories: true)
        }
    }
    
    private func point(_ dev: Bool) -> String {
        dev ? "dev" : "release"
    }
    
    private func webpack(dev: Bool = false, jsFile: String, destURL: URL) throws {
        let configPath = URL(fileURLWithPath: entrypoint).appendingPathComponent("config.js").path
        try createWebpackConfig(dev, at: configPath, jsFile: jsFile, dest: destURL.path)
        do {
            try executeWebpack()
        } catch {
            try deleteWebpackConfig(at: configPath)
            throw error
        }
        try deleteWebpackConfig(at: configPath)
    }
    
    private func executeWebpack() throws {
        let stdout = Pipe()
        let process = Process()
        process.launchPath = try Bash.which("webpack")
        process.currentDirectoryPath = webberFolder
        process.arguments = ["--config", "entrypoint/config.js"]
        process.standardOutput = stdout
        
        let outHandle = stdout.fileHandleForReading

        process.launch()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            let data = outHandle.readDataToEndOfFile()
            guard data.count > 0, let error = String(data: data, encoding: .utf8) else {
                throw WebberError.error("Webpack command failed")
            }
            throw WebberError.error(error)
        }
    }
    
    private func createWebpackConfig(_ dev: Bool = false, at configPath: String, jsFile: String, dest destPath: String) throws {
        let point = self.point(dev)
        let mode = dev ? "development" : "production"
        let config = """
        module.exports = {
          entry: "./entrypoint/\(point)/\(jsFile)",
          mode: "\(mode)",
          output: {
            filename: "\(jsFile)",
            path: "\(destPath)",
          },
        };
        """
        guard let data = config.data(using: .utf8), FileManager.default.createFile(atPath: configPath, contents: data) else {
            throw WebberError.error("Unable to create webpack config file")
        }
    }
    
    private func deleteWebpackConfig(at path: String) throws {
        try FileManager.default.removeItem(atPath: path)
    }
    
    private func checkOrCreateCWD() throws {
        var isDir : ObjCBool = true
        if !FileManager.default.fileExists(atPath: cwd, isDirectory: &isDir) {
            try FileManager.default.createDirectory(atPath: cwd, withIntermediateDirectories: false)
        }
    }
    
    private func installDependencies() throws {
        let npm = try Npm(console, cwd)
        try npm.addDevDependencies()
        try npm.install()
        try npm.installAllGlobalPackages()
    }
    
    private func checkOrCreatePackageFile() throws {
        var isDir : ObjCBool = false
        let path = URL(fileURLWithPath: cwd).appendingPathComponent("package.json").path
        if !FileManager.default.fileExists(atPath: path, isDirectory: &isDir) {
            let data = try JSONEncoder().encode(NewNpmPackage())
            guard FileManager.default.createFile(atPath: path, contents: data) else {
                throw WebberError.error("Unable to create file: .webber/package.json")
            }
        }
    }
    
    private func checkOrCreateEntrypoint() throws {
        var isDir : ObjCBool = true
        if !FileManager.default.fileExists(atPath: entrypoint, isDirectory: &isDir) {
            try FileManager.default.createDirectory(atPath: entrypoint, withIntermediateDirectories: false)
        }
    }
    
    func moveWasmFile(dev: Bool = false, productName: String) throws {
        let originalWasm = URL(fileURLWithPath: context.dir.workingDirectory)
            .appendingPathComponent(".build")
            .appendingPathComponent(dev ? "debug" : "release")
            .appendingPathComponent("\(productName).wasm")
        let wasm = URL(fileURLWithPath: context.dir.workingDirectory)
            .appendingPathComponent(".webber")
            .appendingPathComponent(dev ? "dev" : "release")
            .appendingPathComponent("\(productName.lowercased()).wasm")
        try? FileManager.default.removeItem(at: wasm)
        try FileManager.default.copyItem(at: originalWasm, to: wasm)
    }
    
    enum WebberError: Error, CustomStringConvertible {
        case error(String)
        
        var description: String {
            switch self {
            case .error(let description): return description
            }
        }
    }
}
