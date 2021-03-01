//
//  WebberMiddleware.swift
//  Webber
//
//  Created by Mihael Isaev on 10.02.2021.
//

import Vapor

final class WebberMiddleware: Middleware {
    private let publicDirectory: URL

    public init(publicDirectory: URL) {
        self.publicDirectory = publicDirectory
    }

    public func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        // make a copy of the percent-decoded path
        guard var path = request.url.path.removingPercentEncoding else {
            return request.eventLoop.makeFailedFuture(Abort(.badRequest))
        }
        
        func respondWithIndex() -> Response {
            let filePath = publicDirectory.appendingPathComponent("index.html").path
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: filePath, isDirectory: &isDir), !isDir.boolValue else {
                return Response(status: .ok, body: Response.Body.init(staticString: "Seems that you deleted index file"))
            }
            return request.fileio.streamFile(at: filePath)
        }
        
        // respond with index
        guard path != "/" else {
            return request.eventLoop.makeSucceededFuture(respondWithIndex())
        }

        // path must be relative.
        while path.hasPrefix("/") {
            path = String(path.dropFirst())
        }
        
        // protect against relative paths
        guard !path.contains("../") else {
            return request.eventLoop.makeFailedFuture(Abort(.forbidden))
        }
        
        guard path != "webber" else {
            return next.respond(to: request)
        }
        
        // create absolute file path
        let fileURL = publicDirectory.appendingPathComponent(path)
        let filePath = fileURL.path

        /// robots.txt placeholder for Lighthouse
        guard fileURL.lastPathComponent != "robots.txt" else {
            let scheme = request.url.scheme ?? "https"
            let host = request.url.host ?? "127.0.0.1"
            let port = request.url.port ?? 8888
            return request.eventLoop.makeSucceededFuture(Response(status: .ok, body: .init(string: """
            User-agent: *
            Allow: /

            Sitemap: \(scheme)://\(host):\(port)/sitemap.xml
            """)))
        }
        
        // check if file exists and is not a directory
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: filePath, isDirectory: &isDir), !isDir.boolValue else {
            return request.eventLoop.makeSucceededFuture(respondWithIndex())
        }
        
        // stream the file
        var mediaType: HTTPMediaType?
        if fileURL.pathExtension == "wasm" {
            mediaType = .init(type: "application", subType: "wasm")
        }
        let res = request.fileio.streamFile(at: filePath, mediaType: mediaType)
        res.headers.add(name: .cacheControl, value: "max-age=31536000, public")
        return request.eventLoop.makeSucceededFuture(res)
    }
}
