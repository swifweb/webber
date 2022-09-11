// swift-tools-version:5.3
import PackageDescription
import Foundation

// MARK: - Conveniences

let localDev = false
let devDir = "../"

struct Dep {
    let package: PackageDescription.Package.Dependency
    let targets: [Target.Dependency]
}

struct What {
    let dependency: Package.Dependency

    static func local(_ path: String) -> What {
        .init(dependency: .package(path: "\(devDir)\(path)"))
    }
    static func github(_ path: String, _ from: Version) -> What {
        .init(dependency: .package(url: "https://github.com/\(path)", from: from))
    }
    static func github(_ path: String, _ requirement: PackageDescription.Package.Dependency.Requirement) -> What {
        .init(dependency: .package(url: "https://github.com/\(path)", requirement))
    }
}

extension Array where Element == Dep {
    mutating func append(_ what: What, _ targets: Target.Dependency...) {
        append(.init(package: what.dependency, targets: targets))
    }
}

extension Target.Dependency {
    static func product(_ name: String, _ package: String? = nil) -> Target.Dependency {
        .product(name: name, package: package ?? name)
    }
}

// MARK: - Dependencies

var deps: [Dep] = []

deps.append(.github("vapor/vapor", "4.0.0"), .product("Vapor", "vapor"))
deps.append(.github("swifweb/console-kit", .branch("master")), .product("ConsoleKit", "console-kit"))
deps.append(.github("swiftwasm/WasmTransformer", .upToNextMinor(from: "0.0.2")), .product("WasmTransformer", "WasmTransformer"))

if localDev {
    deps.append(.local("webber-tools"), .product("WebberTools", "webber-tools"))
} else {
    deps.append(.github("swifweb/webber-tools", "1.2.2"), .product("WebberTools", "webber-tools"))
}

// MARK: - Package

let package = Package(
    name: "webber",
    platforms: [
       .macOS(.v10_15)
    ],
    products: [
        .executable(name: "Webber", targets: ["Webber"])
    ],
    dependencies: deps.map { $0.package },
    targets: [
        .target(name: "Webber", dependencies: deps.flatMap { $0.targets })
    ]
)

