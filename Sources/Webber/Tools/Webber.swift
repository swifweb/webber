//
//  Webber.swift
//  Webber
//
//  Created by Mihael Isaev on 09.02.2021.
//

import Foundation
import ConsoleKit
import WebberTools

struct Webber {
    private struct NewNpmPackage: Encodable {
        let name = "webber"
        let version = "1.0.0"
    }
    
    let console: Console
    let context: WebberContext
    let webberFolder = ".webber"
    let cwd: String
    var devPath: String {
        URL(fileURLWithPath: cwd).appendingPathComponent(point(true)).path
    }
    var releasePath: String {
        URL(fileURLWithPath: cwd).appendingPathComponent(point(false)).path
    }
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
    
    struct CookSettings {
        let appType: AppType
        let dev: Bool
        let point: String
        let appJSURL, destURL, serviceWorkerJSURL, indexHTMLURL: URL
        
        init (webber: Webber, type: AppType, dev: Bool, appTarget: String, serviceWorkerTarget: String, type appType: AppType) {
            self.appType = type
            self.dev = dev
            self.point = webber.point(dev)
            let appTarget = appTarget.lowercased()
            let serviceWorkerTarget = serviceWorkerTarget.lowercased()
            appJSURL = URL(fileURLWithPath: webber.entrypoint)
                .appendingPathComponent(point)
                .appendingPathComponent(appTarget + ".js")
            destURL = URL(fileURLWithPath: webber.cwd).appendingPathComponent(point)
            serviceWorkerJSURL = URL(fileURLWithPath: webber.entrypoint)
                .appendingPathComponent(point)
                .appendingPathComponent(serviceWorkerTarget + ".js")
            indexHTMLURL = URL(fileURLWithPath: webber.entrypoint)
                .appendingPathComponent(point)
                .appendingPathComponent("index.html")
        }
    }
    
    func cook(dev: Bool, appTarget: String, serviceWorkerTarget: String, type appType: AppType) throws {
        let startedAt = Date()
        console.output([
            ConsoleTextFragment(string: "Cooking web files, please wait", style: .init(color: .brightYellow))
        ])
        if !dev {
            try? FileManager.default.removeItem(atPath: releasePath)
        }
        try checkOrCreateEntrypoint()
        let settings = CookSettings(webber: self, type: appType, dev: dev, appTarget: appTarget, serviceWorkerTarget: serviceWorkerTarget, type: appType)
        try createPointFolderInsideEntrypoint(dev: dev)
        var manifest: Manifest?
        if appType == .pwa {
            manifest = try grabPWAManifest(dev: dev, serviceWorkerTarget: serviceWorkerTarget)
        }
        var isDir : ObjCBool = false
        let appJSPath = settings.appJSURL.path
        if !FileManager.default.fileExists(atPath: appJSPath, isDirectory: &isDir) {
            let js = self.js(dev: dev, wasmFilename: appTarget.lowercased(), type: appType)
            guard let data = js.data(using: .utf8), FileManager.default.createFile(atPath: appJSPath, contents: data) else {
                throw WebberError.error("Unable to create \(settings.appJSURL.lastPathComponent) file")
            }
        }
        try webpack(dev: dev, jsFile: settings.appJSURL.lastPathComponent, destURL: settings.destURL)
        let serviceWorkerJSPath = settings.serviceWorkerJSURL.path
        if appType == .pwa {
            if !FileManager.default.fileExists(atPath: serviceWorkerJSPath, isDirectory: &isDir) {
                let js = self.js(dev: dev, wasmFilename: serviceWorkerTarget.lowercased(), type: appType, serviceWorker: true)
                guard let data = js.data(using: .utf8), FileManager.default.createFile(atPath: serviceWorkerJSPath, contents: data) else {
                    throw WebberError.error("Unable to create \(settings.serviceWorkerJSURL.lastPathComponent) file")
                }
            }
            try webpack(dev: dev, jsFile: settings.serviceWorkerJSURL.lastPathComponent, destURL: settings.destURL)
        }
        try? cookIndexFile(settings, manifest)
        console.clear(.line)
        console.output([
            ConsoleTextFragment(string: "Cooked web files in ", style: .init(color: .brightBlue, isBold: true)),
            ConsoleTextFragment(string: String(format: "%.2fs", Date().timeIntervalSince(startedAt)), style: .init(color: .brightMagenta))
        ])
    }
    
    struct Manifest: Codable {
        let themeColor: String
        
        private enum CodingKeys : String, CodingKey {
            case themeColor = "theme_color"
        }
    }
    
    private func cookIndexFile(_ settings: CookSettings, _ manifest: Manifest?) throws {
        let indexHTMLPath = settings.indexHTMLURL.path
        var isDir : ObjCBool = false
        if !FileManager.default.fileExists(atPath: indexHTMLPath, isDirectory: &isDir) {
            let index = self.index(
                dev: settings.dev,
                appJS: settings.appJSURL.lastPathComponent,
                swJS: settings.serviceWorkerJSURL.lastPathComponent,
                type: settings.appType,
                manifest: manifest
            )
            guard let data = index.data(using: .utf8), FileManager.default.createFile(atPath: indexHTMLPath, contents: data) else {
                throw WebberError.error("Unable to create \(settings.indexHTMLURL.lastPathComponent) file")
            }
        }
        let newIndexPath = settings.destURL
            .appendingPathComponent(settings.indexHTMLURL.lastPathComponent)
            .path
        try? FileManager.default.removeItem(atPath: newIndexPath)
        try FileManager.default.copyItem(atPath: indexHTMLPath, toPath: newIndexPath)
    }
    
    func recookManifestWithIndex(dev: Bool, appTarget: String, serviceWorkerTarget: String, type appType: AppType) throws {
        let manifest = try grabPWAManifest(dev: dev, serviceWorkerTarget: serviceWorkerTarget)
        let settings = CookSettings(webber: self, type: appType, dev: dev, appTarget: appTarget, serviceWorkerTarget: serviceWorkerTarget, type: appType)
        try cookIndexFile(settings, manifest)
    }
    
    private func grabPWAManifest(dev: Bool, serviceWorkerTarget: String) throws -> Manifest? {
        let executablePath = URL(fileURLWithPath: context.dir.workingDirectory)
            .appendingPathComponent(".build")
            .appendingPathComponent(".native")
            .appendingPathComponent("debug")
            .appendingPathComponent(serviceWorkerTarget)
            .path
        var isDir : ObjCBool = false
        guard FileManager.default.fileExists(atPath: executablePath, isDirectory: &isDir) else {
            console.clear(.line)
            console.output([
                ConsoleTextFragment(string: "⚠️ Warning: unable to cook pwa manifest, executable wasn't built", style: .init(color: .brightYellow, isBold: true))
            ])
            return nil
        }
        let jsonString = try executeServiceWorkerToGrabManifest(path: executablePath)
        guard let data = jsonString.data(using: .utf8) else {
            console.clear(.line)
            console.output([
                ConsoleTextFragment(string: "⚠️ Warning: unable to cook pwa manifest, seems it is corrupted", style: .init(color: .brightYellow, isBold: true))
            ])
            return nil
        }
        do {
            let manifest = try JSONDecoder().decode(Manifest.self, from: data)
            let resultDir = dev ? devPath : releasePath
            if !FileManager.default.fileExists(atPath: resultDir) {
                try? FileManager.default.createDirectory(atPath: resultDir, withIntermediateDirectories: false)
            }
            let manifestPath = URL(fileURLWithPath: resultDir).appendingPathComponent("manifest.json").path
            if FileManager.default.fileExists(atPath: manifestPath) {
                try? FileManager.default.removeItem(atPath: manifestPath)
            }
            guard FileManager.default.createFile(atPath: manifestPath, contents: data) else {
                console.clear(.line)
                console.output([
                    ConsoleTextFragment(string: "⚠️ Warning: unable to save pwa manifest", style: .init(color: .brightYellow, isBold: true))
                ])
                return nil
            }
            return manifest
        } catch {
            console.clear(.line)
            console.output([
                ConsoleTextFragment(string: "⚠️ Warning: unable to cook pwa manifest: \(error)", style: .init(color: .brightYellow, isBold: true))
            ])
            return nil
        }
    }
    
    private func executeServiceWorkerToGrabManifest(path: String) throws -> String {
        let stdout = Pipe()
        let process = Process()
        process.launchPath = path
        process.standardOutput = stdout
        
        let outHandle = stdout.fileHandleForReading

        process.launch()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            let data = outHandle.readDataToEndOfFile()
            guard data.count > 0, let error = String(data: data, encoding: .utf8) else {
                throw WebberError.error("Service worker executable failed with code \(process.terminationStatus)")
            }
            throw WebberError.error("Service worker executable failed: \(error)")
        }
        let data = outHandle.readDataToEndOfFile()
        guard data.count > 0, let manifest = String(data: data, encoding: .utf8) else {
            throw WebberError.error("Service worker executable failed: empty string has been returned")
        }
        return manifest
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
    
    fileprivate func point(_ dev: Bool) -> String {
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
        process.launchPath = try Bash.which("webpack-cli")
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
    
    func installDependencies() throws {
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
            .appendingPathComponent(".wasi")
            .appendingPathComponent("wasm32-unknown-wasi")
            .appendingPathComponent(dev ? "debug" : "release")
            .appendingPathComponent("\(productName).wasm")
        let wasm = URL(fileURLWithPath: context.dir.workingDirectory)
            .appendingPathComponent(".webber")
            .appendingPathComponent(dev ? "dev" : "release")
            .appendingPathComponent("\(productName.lowercased()).wasm")
        try? FileManager.default.removeItem(at: wasm)
        try FileManager.default.copyItem(at: originalWasm, to: wasm)
    }
    
    func moveResources(dev: Bool = false) throws {
        var destFolder = URL(fileURLWithPath: context.dir.workingDirectory)
            .appendingPathComponent(".webber")
            .appendingPathComponent(dev ? "dev" : "release")
        if dev {
            destFolder = destFolder.appendingPathComponent(".resources")
            try? FileManager.default.removeItem(atPath: destFolder.path)
        }
        let buildFolder = URL(fileURLWithPath: context.dir.workingDirectory)
            .appendingPathComponent(".build")
            .appendingPathComponent(".wasi")
            .appendingPathComponent("wasm32-unknown-wasi")
            .appendingPathComponent(dev ? "debug" : "release")
        guard let resourceFolders = try? FileManager.default.contentsOfDirectory(atPath: buildFolder.path).filter({ $0.hasSuffix(".resources") }) else {
            return
        }
        guard resourceFolders.count > 0 else { return }
        try? FileManager.default.createDirectory(atPath: destFolder.path, withIntermediateDirectories: false)
        resourceFolders.forEach {
            let fromFolderURL = buildFolder.appendingPathComponent($0)
            guard let files = try? FileManager.default.contentsOfDirectory(atPath: fromFolderURL.path), files.count > 0 else {
                return
            }
            files.forEach {
                let fromFile = fromFolderURL.appendingPathComponent($0).path
                try? FileManager.default.copyItem(atPath: fromFile, toPath: destFolder.appendingPathComponent($0).path)
                try? FileManager.default.removeItem(atPath: fromFile)
            }
        }
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
