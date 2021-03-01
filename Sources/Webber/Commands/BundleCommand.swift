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
        swift = Swift(try toolchain.pathToSwift(), self.context)
        
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
            try build(product)
            if !debug {
                try optimize(product)
            }
        }
        
        try cook()
        try moveWasmFiles()
        
        // TODO: copy files into `Bundle` folder
    }
    
    /// Build swift into wasm (sync)
    private func build(_ targetName: String) throws {
        context.command.console.output([
            ConsoleTextFragment(string: "Started building product ", style: .init(color: .brightGreen, isBold: true)),
            ConsoleTextFragment(string: targetName, style: .init(color: .brightYellow))
        ])
        
        let buildingStartedAt = Date()
        let buildingBar = context.command.console.loadingBar(title: "Building")
        buildingBar.start()
        try swift.build(targetName, release: !debug)
        buildingBar.succeed()

        context.command.console.clear(.line)
        context.command.console.output([
            ConsoleTextFragment(string: "Finished building ", style: .init(color: .brightGreen, isBold: true)),
            ConsoleTextFragment(string: targetName, style: .init(color: .brightYellow)),
            ConsoleTextFragment(string: " in ", style: .init(color: .brightGreen, isBold: true)),
            ConsoleTextFragment(string: String(format: "%.2fs", Date().timeIntervalSince(buildingStartedAt)), style: .init(color: .brightMagenta))
        ])
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
            appTarget: productTarget.lowercased(),
            serviceWorkerTarget: serviceWorkerTarget?.lowercased() ?? "sw",
            type: appType
        )
    }
    
    /// Moves wasm files into public dev/release folder
    private func moveWasmFiles() throws {
        try products.forEach { product in
            try webber.moveWasmFile(dev: debug, productName: product)
        }
    }
    
    func watchForFileChanges() throws {
        var rebuildingWasmProcess: Process?
        var isRebuilding = false
        var needOneMoreRebuilding = false
        func rebuildWasm() {
            guard !isRebuilding else {
                needOneMoreRebuilding = true
                return
            }
            isRebuilding = true
            if let process = rebuildingWasmProcess {
                if process.isRunning {
                    process.terminate()
                }
            }
            rebuildingWasmProcess = nil
            let buildingStartedAt = Date()
            let buildingBar = context.command.console.loadingBar(title: "Rebuilding")
            buildingBar.start()
            let finishRebuilding = {
                isRebuilding = false
                if needOneMoreRebuilding {
                    needOneMoreRebuilding = false
                    rebuildWasm()
                }
            }
            let handleError: (Error) -> Void = { error in
                buildingBar.fail()
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
                    buildingBar.succeed()
                    self.context.command.console.clear(.line)
                    do {
                        try self.moveWasmFiles()
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
                rebuildingWasmProcess = swift.buildAsync(product) { result in
                    switch result {
                    case .success:
                        DispatchQueue.global(qos: .userInteractive).async {
                            rebuild()
                        }
                    case .failure(let error):
                        handleError(error)
                    }
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
                needOneMoreRecook = true
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
        FS.watchFile(URL(fileURLWithPath: dir.workingDirectory).appendingPathComponent("Package.swift")) {
            try? self.swift.lookupLocalDependencies().forEach {
                guard !FS.contains(path: $0) else { return }
                FS.watchDirectory($0) {
                    rebuildWasm()
                }
            }
            rebuildWasm()
        }
        FS.watchFile(URL(fileURLWithPath: dir.workingDirectory).appendingPathComponent(".swift-version")) {
            rebuildWasm()
        }
        FS.watchDirectory(URL(fileURLWithPath: dir.workingDirectory).appendingPathComponent("Sources")) {
            rebuildWasm()
        }
        try swift.lookupLocalDependencies().forEach {
            FS.watchDirectory($0) {
                rebuildWasm()
            }
        }
        FS.watchDirectory(webber.entrypoint) {
            recookEntrypoint()
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
