//
//  Swift.swift
//  Webber
//
//  Created by Mihael Isaev on 31.01.2021.
//

import Foundation
import Vapor

public class Swift {
    let launchPath: String
    let context: WebberContext
    
    init (_ launchPath: String, _ context: WebberContext) {
        self.launchPath = launchPath
        self.context = context
    }
    
    private enum Command {
        case dump
        case version
        case build(release: Bool, productName: String)
        
        var arguments: [String] {
            switch self {
            case .dump: return ["package", "dump-package"]
            case .version: return ["--version"]
            case .build(let r, let p): return ["build", "-c", r ? "release" : "debug", "--product", p, "--enable-test-discovery", "--triple", "wasm32-unknown-wasi"]
            }
        }
    }

    enum SwiftError: Error, CustomStringConvertible {
        case lines(lines: [String])
        case another(Error)
        case text(String)
        
        var description: String {
            switch self {
            case .lines(let lines): return "\(lines)"
            case .another(let error): return error.localizedDescription
            case .text(let text): return text
            }
        }
        
        var localizedDescription: String {
            description
        }
    }
    
    func version() throws -> String {
        try execute(.version, process: Process())
    }
    
    func buildAsync(
        _ productName: String,
        release: Bool = false,
        handler: @escaping (Result<String, Error>) -> Void
    ) -> Process {
        let process = Process()
        DispatchQueue.global(qos: .userInteractive).async {
            do {
                let result = try self.execute(.build(release: release, productName: productName), process: process)
                handler(.success(result))
            } catch {
                handler(.failure(error))
            }
        }
        return process
    }
    
    @discardableResult
    func build(_ productName: String, release: Bool = false) throws -> String {
        try execute(.build(release: release, productName: productName), process: Process())
    }
    
    /// Swift command execution
    /// - Parameters:
    ///   - command: one of supported commands
    @discardableResult
    private func execute(_ command: Command, process: Process) throws -> String {
        let stdout = Pipe()
        let stderr = Pipe()
        
        process.currentDirectoryPath = context.dir.workingDirectory
        process.launchPath = launchPath
        process.arguments = command.arguments
        process.standardOutput = stdout
        process.standardError = stderr
        
        let outHandle = stdout.fileHandleForReading
        outHandle.waitForDataInBackgroundAndNotify()
        
        process.launch()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            let data = outHandle.readDataToEndOfFile()
            guard data.count > 0, let rawError = String(data: data, encoding: .utf8) else {
                throw SwiftError.text("Build failed with exit code \(process.terminationStatus)")
            }
            let errorLastLine = SwiftError.text("Unable to continue cause of failed compilation 🥺\n")
            switch command {
            case .build:
                struct CompilationError {
                    let file: URL
                    struct Place {
                        let line: Int
                        let reason: String
                        let code: String
                        let pointer: String
                    }
                    let places: [Place]
                }
                do {
                    var errors: [CompilationError] = []
                    var lines = rawError.components(separatedBy: "\n")
                    while !lines.isEmpty {
                        var places: [CompilationError.Place] = []
                        let line = lines.removeFirst()
                        func lineIsPlace(_ line: String) -> Bool {
                            line.hasPrefix("/") && line.components(separatedBy: "/").count > 1 && line.contains(".swift:")
                        }
                        func placeErrorComponents(_ line: String) -> [String]? {
                            let components = line.components(separatedBy: ":")
                            guard components.count == 5, components[3].contains("error") else {
                                return nil
                            }
                            return components
                        }
                        guard lineIsPlace(line) else { continue }
                        func parsePlace(_ line: String) {
                            guard let components = placeErrorComponents(line) else { return }
                            let filePath = URL(fileURLWithPath: components[0])
                            func gracefulExit() {
                                if places.count > 0 {
                                    errors.append(.init(file: filePath, places: places))
                                }
                            }
                            guard let lineInFile = Int(components[1]) else {
                                gracefulExit()
                                return
                            }
                            let reason = components[4]
                            let lineWithCode = lines.removeFirst()
                            let lineWithPointer = lines.removeFirst()
                            guard lineWithPointer.contains("^") else {
                                gracefulExit()
                                return
                            }
                            places.append(.init(line: lineInFile, reason: reason, code: lineWithCode, pointer: lineWithPointer))
                            if let nextLine = lines.first, lineIsPlace(nextLine), placeErrorComponents(nextLine)?.first == filePath.path {
                                parsePlace(lines.removeFirst())
                            } else {
                                gracefulExit()
                            }
                        }
                        parsePlace(line)
                    }
                    guard errors.count > 0 else { throw SwiftError.text("Unable to parse errors") }
                    context.command.console.output(" ")
                    for error in errors {
                        context.command.console.output([
                            ConsoleTextFragment(string: " " + error.file.lastPathComponent + " ", style: .init(color: .green, background: .custom(r: 68, g: 68, b: 68)))
                        ] + " " + [
                            ConsoleTextFragment(string: error.file.path, style: .init(color: .custom(r: 168, g: 168, b: 168)))
                        ])
                        context.command.console.output(" ")
                        for place in error.places {
                            let lineNumberString = "\(place.line) |"
                            let errorTitle = " ERROR "
                            let errorTitlePrefix = "   "
                            context.command.console.output([
                                ConsoleTextFragment(string: errorTitlePrefix, style: .init(color: .none)),
                                ConsoleTextFragment(string: errorTitle, style: .init(color: .brightWhite, background: .red, isBold: true))
                            ] + " " + [
                                ConsoleTextFragment(string: place.reason, style: .init(color: .none))
                            ])
                            let _len = (errorTitle.count + 5) - lineNumberString.count
                            let errorLinePrefix = _len > 0 ? (0..._len).map { _ in " " }.joined(separator: "") : ""
                            context.command.console.output([
                                ConsoleTextFragment(string: errorLinePrefix + lineNumberString, style: .init(color: .brightCyan))
                            ] + " " + [
                                ConsoleTextFragment(string: place.code, style: .init(color: .none))
                            ])
                            let linePointerBeginning = (0...lineNumberString.count - 2).map { _ in " " }.joined(separator: "") + "|"
                            context.command.console.output([
                                ConsoleTextFragment(string: errorLinePrefix + linePointerBeginning, style: .init(color: .brightCyan))
                            ] + " " + [
                                ConsoleTextFragment(string: place.pointer, style: .init(color: .brightRed))
                            ])
                            context.command.console.output(" ")
                        }
                    }
                } catch {
                    context.command.console.output([
                        ConsoleTextFragment(string: "Compilation failed: \(error)\n", style: .init(color: .brightMagenta)),
                        ConsoleTextFragment(string: rawError, style: .init(color: .brightRed))
                    ])
                    throw errorLastLine
                }
                throw errorLastLine
            default:
                context.command.console.output([
                    ConsoleTextFragment(string: "Compilation failed\n", style: .init(color: .brightMagenta)),
                    ConsoleTextFragment(string: rawError, style: .init(color: .brightRed))
                ])
                throw errorLastLine
            }
        }
        
        do {
            let data = outHandle.readDataToEndOfFile()
            guard data.count > 0 else { return "" }
            guard let result = String(data: data, encoding: .utf8) else {
                throw SwiftError.text("Unable to read stdout")
            }
            return result
        } catch {
            return ""
        }
    }
    
    struct Package: Decodable {
        struct Product: Decodable {
            let name: String
            let type: [String: String?]?
        }
        let products: [Product]?
    }
    private var package: Package?
    
    func dumpPackage() throws -> Package {
        if let package = package {
            return package
        }
        let dump = try execute(.dump, process: Process())
        
        guard let data = dump.data(using: .utf8) else {
            throw SwiftError.text("Unable to make dump data")
        }
        return try JSONDecoder().decode(Package.self, from: data)
    }
    
    func checkIfServiceWorkerProductPresent(_ targetName: String) throws {
        let package = try dumpPackage()
        guard let _ = package.products?.filter({
            targetName == $0.name && $0.type?.keys.contains("executable") == true
        }).first else {
            throw SwiftError.text("Unable to find service worker executable product with name `\(targetName)` in Package.swift")
        }
    }
    
    func checkIfAppProductPresent(_ targetName: String) throws {
        let package = try dumpPackage()
        guard let _ = package.products?.filter({
            targetName == $0.name && $0.type?.keys.contains("executable") == true
        }).first else {
            throw SwiftError.text("Unable to find app executable product with name `\(targetName)` in Package.swift")
        }
    }
    
    func lookupExecutableName(excluding serviceWorkerTarget: String?) throws -> String {
        let package = try dumpPackage()
        guard let product = package.products?.filter({
            serviceWorkerTarget != $0.name && $0.type?.keys.contains("executable") == true
        }).first else {
            let excluding = serviceWorkerTarget != nil ? " (excluding service worker: \(serviceWorkerTarget!)" : ""
            throw SwiftError.text("Unable to find app executable product in Package.swift\(excluding)")
        }
        return product.name
    }
    
    func lookupLocalDependencies() throws -> [String] {
        let dump = try execute(.dump, process: Process())
        struct Package: Decodable {
            struct Dependency: Decodable {
                let name: String
                let requirement: [String: String?]?
                let url: String?
            }
            let dependencies: [Dependency]?
        }
        guard let data = dump.data(using: .utf8) else {
            throw SwiftError.text("Unable to make dump data")
        }
        let package = try JSONDecoder().decode(Package.self, from: data)
        return package.dependencies?
            .filter { $0.requirement?.keys.contains("localPackage") == true }
            .compactMap { $0.url }
            .filter { !$0.hasPrefix("../") && !$0.hasPrefix("./") }
            .map { $0 + "/Sources" }
            ?? []
    }
}
