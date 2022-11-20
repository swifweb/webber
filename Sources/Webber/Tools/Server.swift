//
//  Server.swift
//  Webber
//
//  Created by Mihael Isaev on 10.02.2021.
//

import Vapor
import NIOSSL
import WebberTools

class Server {
    fileprivate var app: Application!
    let webber: Webber
    private var wsClients: [WebSocket] = []
    
    init (_ webber: Webber) {
        self.webber = webber
    }
    
    private var isSpinnedUp = false
    
    func spinup() throws {
        guard !isSpinnedUp else { return }
        isSpinnedUp = true
        
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)
        app = Application(env)
        try configureHTTP2()
        let publicDirectory = URL(fileURLWithPath: webber.context.dir.workingDirectory)
            .appendingPathComponent(".webber")
            .appendingPathComponent("dev")
        app.middleware.use(WebberMiddleware(publicDirectory: publicDirectory))
        app.webSocket("webber") { req, client in
            self.wsClients.append(client)
            client.onClose.whenComplete { _ in self.wsClients.removeAll(where: { $0 === client }) }
        }
        app.logger.logLevel = .critical
        defer { app.shutdown() }
        app.lifecycle.use(self)
        try app.run()
    }
    
    enum WSOutgoingNotification: String {
        case wasmRecompiled
        case entrypointRecooked
    }
    
    func notify(_ notification: WSOutgoingNotification) {
        wsClients.forEach {
            $0.send(notification.rawValue)
        }
    }
    
    private func configureHTTP1() {
        app.http.server.configuration.address = .hostname("0.0.0.0", port: 8888)
    }
    
    private func configureHTTP2() throws {
        let sslURL = URL(fileURLWithPath: webber.entrypointDevSSL)
        let keyURL = sslURL.appendingPathComponent("key.pem")
        let certURL = sslURL.appendingPathComponent("cert.pem")
        let certs = try certificates(ssl: sslURL, key: keyURL, cert: certURL)
        let tls = TLSConfiguration.makeServerConfiguration(certificateChain: certs, privateKey: .file(keyURL.path))

        app.http.server.configuration = .init(hostname: "0.0.0.0",
                                              port: 8888,
                                              backlog: 256,
                                              reuseAddress: true,
                                              tcpNoDelay: true,
                                              responseCompression: .disabled,
                                              requestDecompression: .disabled,
                                              supportPipelining: false,
                                              supportVersions: [.two],
                                              tlsConfiguration: tls,
                                              serverName: nil,
                                              logger: nil)
    }
    
    private func certificates(ssl: URL, key: URL, cert: URL) throws -> [NIOSSLCertificateSource] {
        if !FileManager.default.fileExists(atPath: key.path) || !FileManager.default.fileExists(atPath: cert.path) {
            var isDir : ObjCBool = false
            if !FileManager.default.fileExists(atPath: ssl.path, isDirectory: &isDir) {
                try FileManager.default.createDirectory(at: ssl, withIntermediateDirectories: false, attributes: nil)
            } else if isDir.boolValue {
                throw ServerError.error("SSL path is unexpectedly file, not a folder: \(ssl.path)")
            }
			context.console.output([
				ConsoleTextFragment(string: "Generating self-signed SSL certificate", style: .init(color: .brightYellow, isBold: true))
			])
			let configURL = ssl.appendingPathComponent("conf.cnf")
            do {
                let config = """
                [dn]
                CN=0.0.0.0
                [req]
                distinguished_name = dn
                [EXT]
                subjectAltName=DNS:localhost
                keyUsage=digitalSignature
                extendedKeyUsage=serverAuth
                """
                guard FileManager.default.createFile(atPath: configURL.path, contents: config.data(using: .utf8), attributes: nil) else {
                    throw ServerError.error("Unable to create SSL config file")
                }
                try OpenSSL.generate(
                    at: ssl.path,
                    keyName: key.lastPathComponent,
                    certName: cert.lastPathComponent,
                    configName: configURL.lastPathComponent
                )
                try? FileManager.default.removeItem(at: configURL)
            } catch {
                try? FileManager.default.removeItem(at: configURL)
                throw error
            }
			context.console.clear(.line)
			context.console.output([
				ConsoleTextFragment(string: "Generated self-signed SSL certificate", style: .init(color: .brightBlue, isBold: true))
			])
        }
        
        return try NIOSSLCertificate.fromPEMFile(cert.path).map { .certificate($0) }
    }
}

extension Server: LifecycleHandler {
    public func didBoot(_ application: Application) throws {
        IpConfig.getLocalIPs().forEach { address in
			webber.context.command.console.output([
				ConsoleTextFragment(string: "Available at ", style: .init(color: .brightBlue, isBold: true)),
				ConsoleTextFragment(string: "https://" + address + ":8888", style: .init(color: .brightMagenta))
			])
        }
        open(url: "https://127.0.0.1:8888")
    }
    
    func shutdown(_ application: Application) {
        FS.shutdown()
        exit(EXIT_SUCCESS)
    }

    private func open(url: String) {
        #if os(macOS)
        let launchPath = "/usr/bin/open"
        #else
        let launchPath = "/bin/xdg-open"
        #endif
        let process = Process()
        process.launchPath = launchPath
        process.arguments = [url]
        process.launch()
    }
}

private enum ServerError: Error, CustomStringConvertible {
    case error(String)
    
    var description: String {
        switch self {
        case .error(let description): return description
        }
    }
}
