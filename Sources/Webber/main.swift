//
//  main.swift
//  Webber
//
//  Created by Mihael Isaev on 31.01.2021.
//

import ConsoleKit
import Foundation

let console: Console = Terminal()
var input = CommandInput(arguments: CommandLine.arguments)
var context = CommandContext(console: console, input: input)

var commands = Commands(enableAutocomplete: false)
commands.use(VersionCommand(), as: "version", isDefault: false)
commands.use(ServeCommand(), as: "serve", isDefault: false)
commands.use(ReleaseCommand(), as: "release", isDefault: false)

do {
    let group = commands
        .group(help: "Hey there, this tool will help you to test and bundle your web app 🚀 details could be found on swifweb.com")
    try console.run(group, input: input)
} catch let error {
    console.error("\(error)")
    exit(1)
}
