//
//  NewCommand.swift
//  
//
//  Created by Mihael Isaev on 04.03.2023.
//

import Foundation
import ConsoleKit
import Vapor

class NewCommand: Command {
    lazy var dir = DirectoryConfiguration.detect()
    
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

        init() {}
    }
    
    var help: String { "Creates the new project" }
    
    func run(using context: CommandContext, signature: Signature) throws {
        let type: AppType
        if let t = signature.type {
            type = t
        } else {
            type = context.console.choose("Choose \("type", color: .brightYellow) of the app", from: [AppType.pwa, .spa])
        }
        let name = context.console.ask("Enter \("name", color: .brightYellow) of the app").firstCapitalized
        let newFolderPath = dir.workingDirectory.appending("/\(name)")
        
        let filesCountInFolder = (try? FileManager.default.contentsOfDirectory(atPath: newFolderPath).count) ?? 0
        guard filesCountInFolder == 0 else {
            throw CommandError.error("Unfortunately \"\(name)\" folder already exists and it is not empty")
        }
        try FileManager.default.createDirectory(atPath: newFolderPath, withIntermediateDirectories: false)
        // Root files
        FileManager.default.createFile(atPath: newFolderPath.appending("/Package.xpreview"), contents: nil)
        FileManager.default.createFile(atPath: newFolderPath.appending("/.gitignore"), contents: """
        .DS_Store
        /.build
        /Packages
        /*.xcodeproj
        xcuserdata/
        /.webber/dev
        /.webber/release
        /.webber/entrypoint/dev/.ssl
        /.webber/node_modules
        /.webber/package*
        /.swiftpm
        """.data(using: .utf8))
        FileManager.default.createFile(atPath: newFolderPath.appending("/Package.swift"), contents: """
        // swift-tools-version:5.7
        import PackageDescription

        let package = Package(
            name: "\(name)",
            platforms: [
                .macOS(.v10_15)
            ],
            products: [
                .executable(name: "App", targets: ["App"]),\(type == .pwa ? """
                
                .executable(name: "Service", targets: ["Service"])
        """ : "")
            ],
            dependencies: [
                .package(url: "https://github.com/swifweb/web", from: "1.0.0-beta.2.0.0")
            ],
            targets: [
                .executableTarget(name: "App", dependencies: [
                    .product(name: "Web", package: "web")
                ]),\(type == .pwa ? """
                
                .executableTarget(name: "Service", dependencies: [
                    .product(name: "ServiceWorker", package: "web")
                ], resources: [
                    //.copy("images/favicon.ico"),
                    //.copy("images")
                ]),
        """ : "")
                .testTarget(name: "AppTests", dependencies: ["App"])
            ]
        )
        """.data(using: .utf8))
        // Tests folder
        let testsPath = newFolderPath.appending("/Tests")
        let appTestsPath = testsPath.appending("/AppTests")
        try FileManager.default.createDirectory(atPath: appTestsPath, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: testsPath.appending("/LinuxMain.swift"), contents: """
        import XCTest

        import SwiftWasmAppTests

        var tests = [XCTestCaseEntry]()
        tests += SwiftWasmAppTests.allTests()
        XCTMain(tests)
        """.data(using: .utf8))
        FileManager.default.createFile(atPath: appTestsPath.appending("/AppTests.swift"), contents: """
        import XCTest
        import class Foundation.Bundle

        final class SwiftWasmAppTests: XCTestCase {
            func testExample() throws {
                XCTAssertEqual("Hello, world!", "Hello, world!")
            }

            static var allTests = [
                ("testExample", testExample),
            ]
        }
        """.data(using: .utf8))
        FileManager.default.createFile(atPath: appTestsPath.appending("/XCTestManifests.swift"), contents: """
        import XCTest

        #if !canImport(ObjectiveC)
        public func allTests() -> [XCTestCaseEntry] {
            return [
                testCase(SwiftWasmAppTests.allTests),
            ]
        }
        #endif
        """.data(using: .utf8))
        // Sources folder
        let sourcesPath = newFolderPath.appending("/Sources")
        let appSourcesPath = sourcesPath.appending("/App")
        try FileManager.default.createDirectory(atPath: appSourcesPath, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: appSourcesPath.appending("/App.swift"), contents: """
        import Web

        @main
        class App: WebApp {
            @State var color = Color.cyan
            
            enum Theme {
                case happy, sad
            }
            
            @State var theme: Theme = .happy
            
            @AppBuilder override var app: Configuration {
                Lifecycle.didFinishLaunching {
                    Navigator.shared.serviceWorker?.register("./service.js")
                    print("Lifecycle.didFinishLaunching")
                }.willTerminate {
                    print("Lifecycle.willTerminate")
                }.willResignActive {
                    print("Lifecycle.willResignActive")
                }.didBecomeActive {
                    print("Lifecycle.didBecomeActive")
                }.didEnterBackground {
                    print("Lifecycle.didEnterBackground")
                }.willEnterForeground {
                    print("Lifecycle.willEnterForeground")
                }
                Routes {
                    Page { IndexPage() }
                    Page("hello") { HelloPage() }
                    Page("**") { NotFoundPage() }
                }
                HappyStyle().id(.happyStyle).disabled($theme.map { $0 != .happy })
                SadStyle().id("sadStyle").disabled($theme.map { $0 != .sad })
            }
        }

        class HappyStyle: Stylesheet {
            @Rules
            override var rules: Rules.Content {
                Rule(H1.pointer).color(App.current.$color)
                Rule(Pointer.any)
                    .margin(all: 0)
                    .padding(all: 0)
                Rule(H1.class(.hello).after, H2.class(.hello).after) {
                    AlignContent(.baseline)
                    Color(.red)
                }
                .property(.alignContent, .auto)
                .alignContent(.auto)
                .color(.red)
            }
        }

        class SadStyle: Stylesheet {
            @Rules
            override var rules: Rules.Content {
                Rule(H1.pointer).color(.deepPink)
            }
        }

        extension Id {
            static var happyStyle: Id { "happyStyle" }
        }

        extension Class {
            static var hello: Class { "hello" }
        }
        """.data(using: .utf8))
        let extensionsAppSourcesPath = appSourcesPath.appending("/Extensions")
        try FileManager.default.createDirectory(atPath: extensionsAppSourcesPath, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: extensionsAppSourcesPath.appending("/Fonts.swift"), contents: """
        import Web

        extension FontFamilyType {
            static var sanFrancisco: Self { .init("San Francisco") }
            
            static var roboto: Self { .init("Roboto") }
            
            static var segoeUI: Self { .init("Segoe UI") }
            
            static var helveticaNeue: Self { .init("Helvetica Neue") }
            
            static var lucidaGrande: Self { .init("Lucida Grande") }
            
            static var app: Self { .combined(.system, .appleSystem, .sanFrancisco, .roboto, .segoeUI, .helveticaNeue, .lucidaGrande, .sansSerif) }
        }
        """.data(using: .utf8))
        let pagesAppSourcesPath = appSourcesPath.appending("/Pages")
        try FileManager.default.createDirectory(atPath: pagesAppSourcesPath, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: pagesAppSourcesPath.appending("/HelloPage.swift"), contents: """
        import Web

        class HelloPage: PageController {
            @DOM override var body: DOM.Content {
                P("Hello page")
                    .textAlign(.center)
                    .body {
                         Button("go back").display(.block).onClick {
                             History.back()
                         }
                    }
                Div().width(300.px).height(300.px).background(color: .yellow).backgroundImage("https://i.ytimg.com/vi/1Ne1hqOXKKI/maxresdefault.jpg").backgroundSize(h: 200.px, v: 200.px).backgroundRepeat(.noRepeat)
            }
        }

        /// Live preview works in both XCode and VSCode
        /// To make it work in XCode install the `XLivePreview` app
        /// To make it work in VSCode install `webber` extension
        class Hello_Preview: WebPreview {
            @Preview override class var content: Preview.Content {
                Language.en
                Title("My hello preview")
                Size(400, 400)
                HelloPage()
            }
        }
        """.data(using: .utf8))
        FileManager.default.createFile(atPath: pagesAppSourcesPath.appending("/IndexPage.swift"), contents: """
        import Web
        import FetchAPI

        class IndexPage: PageController {
            @State var firstTodoTitle = "n/a"
            
            @DOM override var body: DOM.Content {
                Header {
                    Div {
                        H1("First Todo Title")
                        Br()
                        H2(self.$firstTodoTitle)
                        Br()
                        Button("Load First Todo Title").onClick {
                            Fetch("https://jsonplaceholder.typicode.com/todos/1") {
                                switch $0 {
                                case .failure:
                                    break
                                case .success(let response):
                                    struct Todo: Decodable {
                                        let id, userId: Int
                                        let title: String
                                        let completed: Bool
                                    }
                                    response.json(as: Todo.self) {
                                        switch $0 {
                                        case .failure(let error):
                                            self.firstTodoTitle = "some error occured: \\(error)"
                                        case .success(let todo):
                                            self.firstTodoTitle = todo.title
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .position(.absolute)
                    .display(.block)
                    .top(50.percent)
                    .left(50.percent)
                    .transform(.translate(-50.percent, -50.percent))
                    .whiteSpace(.nowrap)
                    .overflow(.hidden)
                }
                .position(.fixed)
                .width(100.percent)
                .height(100.percent)
                .background(.linearGradient(angle: -30, .red/20, .green/80, .red))
            }

            override func buildUI() {
                super.buildUI()
                title = "Fetch example"
                metaDescription = "An awesome Swift in heart of your website"
            }
        }

        /// Live preview works in both XCode and VSCode
        /// To make it work in XCode install the `XLivePreview` app
        /// To make it work in VSCode install `webber` extension
        class Welcome_Preview: WebPreview {
            @Preview override class var content: Preview.Content {
                Language.en
                Title("Initial page")
                Size(640, 480)
                // add styles if needed
                AppStyles.id(.happyStyle)
                // add here as many elements as needed
                IndexPage()
            }
        }
        """.data(using: .utf8))
        FileManager.default.createFile(atPath: pagesAppSourcesPath.appending("/NotFoundPage.swift"), contents: """
        import Web

        class NotFoundPage: PageController {
            @DOM override var body: DOM.Content {
                P("this is catchall aka 404 NOT FOUND page")
                    .textAlign(.center)
                    .body {
                        Button("go back").display(.block).onClick {
                            History.back()
                        }
                    }
            }
        }

        /// Live preview works in both XCode and VSCode
        /// To make it work in XCode install the `XLivePreview` app
        /// To make it work in VSCode install `webber` extension
        class NotFound_Preview: WebPreview {
            @Preview override class var content: Preview.Content {
                Language.en
                Title("Not found endpoint")
                Size(200, 200)
                NotFoundPage()
            }
        }
        """.data(using: .utf8))
        if type == .pwa {
            let serviceSourcesPath = sourcesPath.appending("/Service")
            let imagesServiceSourcesPath = serviceSourcesPath.appending("/images")
            try FileManager.default.createDirectory(atPath: serviceSourcesPath, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(atPath: imagesServiceSourcesPath, withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: serviceSourcesPath.appending("/Service.swift"), contents: """
            import ServiceWorker

            @main
            public class Service: ServiceWorker {
                @ServiceBuilder public override var body: ServiceBuilder.Content {
                    Manifest
                        .name("\(name)")
                        .startURL(".")
                        .display(.standalone)
                        .backgroundColor("#2A3443")
                        .themeColor("white")
            //            .icons(
            //                .init(src: "images/192.png", sizes: .x192, type: .png),
            //                .init(src: "images/512.png", sizes: .x512, type: .png)
            //            )
                    Lifecycle.activate {
                        debugPrint("service activate event")
                    }.install {
                        debugPrint("service install event")
                    }.fetch {
                        debugPrint("service fetch event")
                    }.sync {
                        debugPrint("service sync event")
                    }.contentDelete {
                        debugPrint("service contentDelete event")
                    }
                }
            }
            """.data(using: .utf8))
        }
        #if os(macOS)
        let isMacOS = true
        let chromeInstalled = FileManager.default.fileExists(atPath: "/Applications/Google Chrome.app")
        #else
        let isMacOS = false
        let chromeInstalled = false
        #endif
        context.console.output("""
        **********************************************************************************************
        *
        *    New \(type == .pwa ? "PWA" : "SPA", color: .brightMagenta) project \(name, color: .brightYellow) has been created!
        *
        *    Go to the project folder
        *    \("cd \(name)", color: .brightGreen)
        *
        *    Launch debug session
        *    \("webber serve \(type == .pwa ? "-t pwa -s Service" : "") -p 443 \(chromeInstalled ? "--browser chrome --browser-self-signed --browser-incognito" : "")", color: .brightGreen)
        *
        *    Open project folder in VSCode\(isMacOS ? " or Package.swift in Xcode" : "") and start working
        *    Webber will reload page automatically once you save changes
        *
        **********************************************************************************************
        """)
    }
}

fileprivate extension StringProtocol {
    var firstCapitalized: String { prefix(1).capitalized + dropFirst() }
}
