// swift-tools-version:5.7
import PackageDescription
import Foundation

// MARK: - Conveniences

let localDev = false
let devDir = "../"

struct Dep {
    let package: PackageDescription.Package.Dependency
    let targets: [Target.Dependency]
	
	init (_ what: What, _ targets: Target.Dependency...) {
		self.package = what.dependency
		self.targets = targets
	}
}

struct What {
    let dependency: Package.Dependency

    static func local(_ path: String) -> What {
        .init(dependency: .package(path: "\(devDir)\(path)"))
    }
    static func github(_ path: String, _ from: Version) -> What {
        .init(dependency: .package(url: "https://github.com/\(path)", from: from))
    }
	static func github(_ path: String, exact: Version) -> What {
		.init(dependency: .package(url: "https://github.com/\(path)", exact: exact))
	}
	static func github(_ path: String, branch: String) -> What {
		.init(dependency: .package(url: "https://github.com/\(path)", branch: branch))
	}
}

extension Target.Dependency {
    static func product(_ name: String, _ package: String? = nil) -> Target.Dependency {
        .product(name: name, package: package ?? name)
    }
}

// MARK: - Dependencies

var deps: [Dep] = [
	.init(.github("vapor/vapor", "4.0.0"), .product("Vapor", "vapor")),
	.init(.github("swifweb/console-kit", branch: "master"), .product("ConsoleKit", "console-kit")),
	.init(.github("swiftwasm/WasmTransformer", "0.0.3"), .product("WasmTransformer", "WasmTransformer"))
]

if localDev {
	deps.append(contentsOf: [
		.init(.local("webber-tools"), .product("WebberTools", "webber-tools"))
	])
} else {
	deps.append(contentsOf: [
		.init(.github("swifweb/webber-tools", "1.4.1"), .product("WebberTools", "webber-tools"))
	])
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

