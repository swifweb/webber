//
//  ServeCommand.swift
//  Webber
//
//  Created by Mihael Isaev on 31.01.2021.
//

import ConsoleKit
import Vapor
import NIOSSL
import WasmTransformer

final class ServeCommand: BundleCommand {
    override var debug: Bool { true }
    override var serve: Bool { true }
    
    override var help: String {
        "Compile, cook and serve files for debug and development"
    }
}
