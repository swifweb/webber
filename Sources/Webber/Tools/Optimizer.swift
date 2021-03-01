//
//  Optimizer.swift
//  Webber
//
//  Created by Mihael Isaev on 11.02.2021.
//

import Foundation
import WasmTransformer
import ConsoleKit

struct Optimizer {
    static func optimizeForOldSafari(debug: Bool, _ productName: String, context: WebberContext) throws {
        let wasmFileURL = URL(fileURLWithPath: context.dir.workingDirectory)
            .appendingPathComponent(".build")
            .appendingPathComponent(debug ? "debug" : "release")
            .appendingPathComponent(productName)
            .appendingPathExtension("wasm")

        let startedAt = Date()

        let bar = context.command.console.loadingBar(title: "Optimizing for old Safari")
        bar.start()

        guard let wasmBeforeOptimization = FileManager.default.contents(atPath: wasmFileURL.path) else {
            bar.fail()
            context.command.console.clear(.line)
            context.command.console.output([
                ConsoleTextFragment(string: "Unable to read compiled wasm file ☹️ at: \(wasmFileURL.path)", style: .init(color: .brightRed, isBold: true))
            ])
            return
        }

        guard FileManager.default.createFile(
            atPath: wasmFileURL.path,
            contents: Data(try lowerI64Imports(wasmBeforeOptimization.bytes)),
            attributes: nil
        ) else {
            bar.fail()
            context.command.console.clear(.line)
            context.command.console.output([
                ConsoleTextFragment(string: "Unable to save optimized wasm file ☹️", style: .init(color: .brightRed, isBold: true))
            ])
            return
        }

        bar.succeed()
        context.command.console.clear(.line)
        context.command.console.output([
            ConsoleTextFragment(string: "Optimized for old Safari in ", style: .init(color: .brightBlue, isBold: true)),
            ConsoleTextFragment(string: String(format: "%.2fs", Date().timeIntervalSince(startedAt)), style: .init(color: .brightMagenta))
        ])
    }
    
    static func stripDebugInfo(debug: Bool = false, _ productName: String, context: WebberContext) throws {
        let wasmFileURL = URL(fileURLWithPath: context.dir.workingDirectory)
            .appendingPathComponent(".build")
            .appendingPathComponent(debug ? "debug" : "release")
            .appendingPathComponent(productName)
            .appendingPathExtension("wasm")

        let startedAt = Date()

        let bar = context.command.console.loadingBar(title: "Stripping debug info")
        bar.start()

        guard let wasmBeforeOptimization = FileManager.default.contents(atPath: wasmFileURL.path) else {
            bar.fail()
            context.command.console.clear(.line)
            context.command.console.output([
                ConsoleTextFragment(string: "Unable to read compiled wasm file ☹️", style: .init(color: .brightRed, isBold: true))
            ])
            return
        }

        guard FileManager.default.createFile(
            atPath: wasmFileURL.path,
            contents: Data(try stripCustomSections(wasmBeforeOptimization.bytes)),
            attributes: nil
        ) else {
            bar.fail()
            context.command.console.clear(.line)
            context.command.console.output([
                ConsoleTextFragment(string: "Unable to save stripped wasm file ☹️", style: .init(color: .brightRed, isBold: true))
            ])
            return
        }

        bar.succeed()
        context.command.console.clear(.line)
        context.command.console.output([
            ConsoleTextFragment(string: "Stripped debug info in ", style: .init(color: .brightBlue, isBold: true)),
            ConsoleTextFragment(string: String(format: "%.2fs", Date().timeIntervalSince(startedAt)), style: .init(color: .brightMagenta))
        ])
    }
}
