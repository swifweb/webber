//
//  ReleaseCommand.swift
//  Webber
//
//  Created by Mihael Isaev on 21.02.2021.
//

import ConsoleKit
import Vapor

final class ReleaseCommand: BundleCommand {
    override var help: String {
        "Compile, cook and pack files for release"
    }
}
