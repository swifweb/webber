//
//  WasmOpt.swift
//  Webber
//
//  Created by Mihael Isaev on 21.02.2021.
//

import Foundation
import ConsoleKit
import WebberTools

struct WasmOpt {
    enum WasmOptError: Error, CustomStringConvertible {
        case brokenStdout
        case somethingWentWrong(code: Int32)
        
        var description: String {
            switch self {
            case .brokenStdout: return "Unable to read stdout"
            case .somethingWentWrong(let code): return "WasmOpt failed with code \(code)"
            }
        }
    }
    
    static func optimize(_ productName: String, context: WebberContext) throws {
        let wasmFileURL = URL(fileURLWithPath: context.dir.workingDirectory)
            .appendingPathComponent(".build")
			.appendingPathComponent(".wasi")
            .appendingPathComponent("release")
            .appendingPathComponent(productName)
            .appendingPathExtension("wasm")
        
        let stdout = Pipe()
        let process = Process()
        process.launchPath = try Bash.which("wasm-opt")
        process.arguments = ["-Os", wasmFileURL.path, "-o", wasmFileURL.path]
        process.standardOutput = stdout
        
        let outHandle = stdout.fileHandleForReading
        outHandle.waitForDataInBackgroundAndNotify()

        let startedAt = Date()

        let bar = context.command.console.loadingBar(title: "Optimizing \"\(productName)\" with `wasm-opt`")
        bar.start()
        
        process.launch()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            bar.fail()
            context.command.console.clear(.line)
            throw WasmOptError.somethingWentWrong(code: process.terminationStatus)
        }
        
        bar.succeed()
        context.command.console.clear(.line)
        context.command.console.output([
            ConsoleTextFragment(string: "Optimized \"\(productName)\" with `wasm-opt` in ", style: .init(color: .brightBlue, isBold: true)),
            ConsoleTextFragment(string: String(format: "%.2fs", Date().timeIntervalSince(startedAt)), style: .init(color: .brightMagenta)),
            ConsoleTextFragment(string: " new size is ", style: .init(color: .brightBlue, isBold: true)),
            ConsoleTextFragment(string: wasmFileURL.fileSizeString, style: .init(color: .brightMagenta))
        ])
    }
}
