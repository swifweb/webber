//
//  VersionCommand.swift
//  
//
//  Created by Mihael Isaev on 25.12.2022.
//

import ConsoleKit
import Vapor
import NIOSSL
import WasmTransformer

final class VersionCommand: Command {
    static var currentVersion = "1.8.1"
    
    struct Signature: CommandSignature {
        init() {}
    }
    
    var help: String { "Prints current version" }
    
    func run(using context: ConsoleKit.CommandContext, signature: Signature) throws {
        let arch = try Arch.get()
        #if DEBUG
        let mode = "DEBUG"
        #else
        let mode = "RELEASE"
        #endif
        context.console.output([
            ConsoleTextFragment(string: "Webber", style: .init(color: .magenta, isBold: true)),
            ConsoleTextFragment(string: " \(Self.currentVersion)-\(mode)", style: .init(color: .yellow, isBold: true)),
            ConsoleTextFragment(string: " \(arch)", style: .init(color: .green, isBold: true))
        ])
    }
}
