//
//  BundleCommand.swift
//  Webber
//
//  Created by Mihael Isaev on 21.02.2021.
//

import ConsoleKit
import Vapor
import NIOSSL
import WasmTransformer
import WebberTools

class BundleCommand: Command {
    var server: Server!
    lazy var dir = DirectoryConfiguration.detect()
    var context: WebberContext!
    lazy var toolchain = Toolchain(context)
    var swift: Swift!
    var serviceWorkerTarget: String?
    var productTarget: String!
    var webber: Webber!
    var debug: Bool { false }
    var serve: Bool { false }
    var appType: AppType = .spa
    var products: [String] = []
    
    enum CommandError: Error, CustomStringConvertible {
        case error(String)
        
        var description: String {
            switch self {
            case .error(let description): return description
            }
        }
    }
    
    struct Signature: CommandSignature {
        @Option(
            name: "type",
            short: "t",
            help: "App type. It is `spa` by default. Could also be `pwa`.",
            completion: .values(AppType.all)
        )
        var type: AppType?
        
        @Option(
            name: "service-worker-target",
            short: "s",
            help: "Name of service worker target."
        )
        var serviceWorkerTarget: String?
        
        @Option(
            name: "app-target",
            short: "a",
            help: "Name of app target."
        )
        var appTarget: String?

        init() {}
    }
    
    var help: String { "" }

    func run(using context: CommandContext, signature: Signature) throws {
        appType = signature.type ?? .spa
        serviceWorkerTarget = signature.serviceWorkerTarget
        if appType == .pwa && serviceWorkerTarget == nil {
            throw CommandError.error("You have to provide service target name for PWA. Use: -s ServiceTargetName")
        } else if appType != .pwa && serviceWorkerTarget != nil {
            context.console.output([
                ConsoleTextFragment(string: "You provided service target name but forgot to set app type to PWA.", style: .init(color: .magenta, isBold: true)),
                ConsoleTextFragment(string: " Use: -t pwa", style: .init(color: .yellow, isBold: true))
            ])
        }
        
        // Instantiate webber context
        self.context = WebberContext(dir: dir, command: context)
        
        // Instantiate swift
        swift = Swift(try toolchain.pathToSwift(), self.context.dir.workingDirectory)
        
        // Printing swift version
        context.console.output("\n\(try swift.version())")

        // Lookup product target
        if let appTarget = signature.appTarget {
            productTarget = signature.appTarget
            try swift.checkIfAppProductPresent(appTarget)
        } else {
            productTarget = try swift.lookupExecutableName(excluding: serviceWorkerTarget)
        }
        
        // Check for service worker target
        if appType == .pwa {
            if let sw = serviceWorkerTarget {
                try swift.checkIfServiceWorkerProductPresent(sw)
            }
        }
        
        // Fill products array
        products.append(productTarget)
        if let product = serviceWorkerTarget {
            products.append(product)
        }
        
        // Instantiate webber
        webber = try Webber(self.context)
        
        try execute()
        
        if serve {
            try watchForFileChanges()
            try spinup()
        }
    }
    
    func execute() throws {
        try products.forEach { product in
            try build(product, alsoNative: serviceWorkerTarget == product)
        }
		
		try webber.installDependencies()
		
		if !debug {
			try products.forEach { product in
				try optimize(product)
			}
		}
        
        try cook()
        try moveWasmFiles()
        try webber.moveResources(dev: debug)
    }
    
    /// Build swift into wasm (sync)
    private func build(_ targetName: String, alsoNative: Bool = false) throws {
        context.command.console.output([
            ConsoleTextFragment(string: "Started building product ", style: .init(color: .brightGreen, isBold: true)),
            ConsoleTextFragment(string: targetName, style: .init(color: .brightYellow))
        ])
        
        let buildingStartedAt = Date()
        let buildingBar = context.command.console.loadingBar(title: "Building")
        buildingBar.start()
        try swiftBuild(targetName, release: !debug, tripleWasm: true)
        if alsoNative {
            // building non-wasi executable (usually for service worker to grab manifest json)
            // should be built in debug cause of compile error in JavaScriptKit in release mode
            buildingBar.activity.title = "Grabbing info"
            try swiftBuild(targetName, release: false, tripleWasm: false)
        }
        buildingBar.succeed()

        context.command.console.clear(.line)
        context.command.console.output([
            ConsoleTextFragment(string: "Finished building ", style: .init(color: .brightGreen, isBold: true)),
            ConsoleTextFragment(string: targetName, style: .init(color: .brightYellow)),
            ConsoleTextFragment(string: " in ", style: .init(color: .brightGreen, isBold: true)),
            ConsoleTextFragment(string: String(format: "%.2fs", Date().timeIntervalSince(buildingStartedAt)), style: .init(color: .brightMagenta))
        ])
    }
    
    private func swiftBuild(_ productName: String, release: Bool = false, tripleWasm: Bool) throws {
        #if DEBUG
        context.command.console.output([
            ConsoleTextFragment(string: swift.launchPath, style: .init(color: .brightBlue, isBold: true)),
            ConsoleTextFragment(string: " " + Swift.Command.build(release: release, productName: productName).arguments(tripleWasm: tripleWasm).joined(separator: " ") + "\n", style: .init(color: .brightMagenta))
        ])
        #endif
        var errorsCount = 0
        func errorLastLine() -> Swift.SwiftError {
            var ending = ""
            if errorsCount == 1 {
                ending = "found 1 error ❗️"
            } else if errorsCount > 1 {
                ending = "found \(errorsCount) errors ❗️❗️❗️"
            }
            return Swift.SwiftError.text("Unable to continue cause of failed compilation 🥺 \(ending)\n")
        }
        do {
            try swift.build(productName, release: release, tripleWasm: tripleWasm)
        } catch let error as Swift.SwiftError {
            switch error {
            case .errors(let errors):
                errorsCount = errors.map { $0.places.count }.reduce(0, +)
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
            case .raw(let raw):
                context.command.console.output([
                    ConsoleTextFragment(string: "Compilation failed\n", style: .init(color: .brightMagenta)),
                    ConsoleTextFragment(string: raw, style: .init(color: .brightRed))
                ])
                throw Swift.SwiftError.text("Unable to continue cause of failed compilation 🥺\n")
            default:
                throw error
            }
        } catch {
            throw error
        }
    }
    
    private func optimize(_ targetName: String) throws {
        // Optimization for old Safari
        try Optimizer.optimizeForOldSafari(debug: debug, targetName, context: context)
        // Stripping debug info
        try Optimizer.stripDebugInfo(targetName, context: context)
        // Optimize using `wasm-opt`
        try WasmOpt.optimize(targetName, context: context)
    }
    
    /// Cook web files
    private func cook() throws {
		try webber.cook(
            dev: debug,
            appTarget: productTarget,
            serviceWorkerTarget: serviceWorkerTarget ?? "sw",
            type: appType
        )
    }
    
    /// Moves wasm files into public dev/release folder
    private func moveWasmFiles() throws {
        try products.forEach { product in
            try webber.moveWasmFile(dev: debug, productName: product)
        }
    }
    
    lazy var rebuildQueue = DispatchQueue(label: "webber.rebuilder")
    private var lastRebuildRequestedAt: Date?
    
    func watchForFileChanges() throws {
        var isRebuilding = false
        var needOneMoreRebuilding = false
        func rebuildWasm() {
            guard !isRebuilding else {
                if let lastRebuildRequestedAt = lastRebuildRequestedAt {
                    if Date().timeIntervalSince(lastRebuildRequestedAt) < 2 {
                        return
                    }
                }
                needOneMoreRebuilding = true
                return
            }
            lastRebuildRequestedAt = Date()
            isRebuilding = true
            let buildingStartedAt = Date()
            
            console.output([
                ConsoleTextFragment(string: "Rebuilding, please wait...", style: .init(color: .brightYellow))
            ])
            
            let finishRebuilding = {
                isRebuilding = false
                if needOneMoreRebuilding {
                    needOneMoreRebuilding = false
                    rebuildWasm()
                }
            }
            let handleError: (Error) -> Void = { error in
                self.context.command.console.clear(.line)
                self.context.command.console.output([
                    ConsoleTextFragment(string: "Rebuilding error: \(error)", style: .init(color: .brightRed))
                ])
                finishRebuilding()
            }
            var productsToRebuild: [String] = []
            productsToRebuild.append(contentsOf: products)
            func rebuild() {
                guard productsToRebuild.count > 0 else {
                    try? self.webber.recookManifestWithIndex(
                        dev:  self.debug,
                        appTarget: self.productTarget,
                        serviceWorkerTarget: self.serviceWorkerTarget ?? "sw",
                        type: self.appType
                    )
                    self.context.command.console.clear(.line)
                    do {
                        try self.moveWasmFiles()
                        try self.webber.moveResources(dev: debug)
                    } catch {
                        handleError(error)
                    }
                    // notify ws clients
                    self.server.notify(.wasmRecompiled)
                    let df = DateFormatter()
                    df.dateFormat = "hh:mm:ss"
                    // notify console
                    self.context.command.console.output([
                        ConsoleTextFragment(string: "[\(df.string(from: Date()))] Rebuilt in ", style: .init(color: .brightGreen, isBold: true)),
                        ConsoleTextFragment(string: String(format: "%.2fs", Date().timeIntervalSince(buildingStartedAt)), style: .init(color: .brightMagenta))
                    ])
                    finishRebuilding()
                    return
                }
				let product = productsToRebuild.removeFirst()
				do {
					try swift.build(product)
					if self.serviceWorkerTarget == product {
						try self.swift.build(product, tripleWasm: false)
						DispatchQueue.global(qos: .userInteractive).async {
							rebuild()
						}
					} else {
						DispatchQueue.global(qos: .userInteractive).async {
							rebuild()
						}
					}
				} catch {
					handleError(error)
				}
            }
            DispatchQueue.global(qos: .userInteractive).async {
                rebuild()
            }
        }
        
        // Recooking
        var isRecooking = false
        var needOneMoreRecook = false
        func recookEntrypoint() {
            guard !isRecooking else {
//                needOneMoreRecook = true
                return
            }
            isRecooking = true
            DispatchQueue.global(qos: .userInteractive).async {
                do {
                    // cook web files
                    try self.cook()
                    // notify ws clients
                    self.server.notify(.entrypointRecooked)
                } catch {
                    self.context.command.console.output([
                        ConsoleTextFragment(string: "Recooking error: \(error)", style: .init(color: .brightRed))
                    ])
                }
                isRecooking = false
                if needOneMoreRecook {
                    needOneMoreRecook = false
                    recookEntrypoint()
                }
            }
        }
        FS.watch(URL(fileURLWithPath: dir.workingDirectory).appendingPathComponent("Package.swift")) { url in
            try? self.swift.lookupLocalDependencies().forEach {
                guard !FS.contains(path: $0) else { return }
                FS.watch($0) { url in
                    self.rebuildQueue.sync {
                        rebuildWasm()
                    }
                }
            }
            self.rebuildQueue.sync {
                rebuildWasm()
            }
        }
        FS.watch(URL(fileURLWithPath: dir.workingDirectory).appendingPathComponent(".swift-version")) { url in
            self.rebuildQueue.sync {
                rebuildWasm()
            }
        }
        FS.watch(URL(fileURLWithPath: dir.workingDirectory).appendingPathComponent("Sources")) { url in
            self.rebuildQueue.sync {
                rebuildWasm()
            }
        }
        try swift.lookupLocalDependencies().forEach {
            FS.watch($0) { url in
                self.rebuildQueue.sync {
                    rebuildWasm()
                }
            }
        }
        FS.watch(webber.entrypoint) { url in
            self.rebuildQueue.sync {
                recookEntrypoint()
            }
        }
    }
    
    private var isSpinnedUp = false
    
    /// Spin up Vapor server
    func spinup() throws {
        guard !isSpinnedUp else { return }
        isSpinnedUp = true
        server = Server(webber)
        try server.spinup()
    }
}
