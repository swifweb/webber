//
//  ToolchainRetriever.swift
//  Webber
//
//  Created by Mihael Isaev on 02.02.2021.
//

import Foundation
import ConsoleKit

class ToolchainRetriever {
    let context: WebberContext
    private var observation: NSKeyValueObservation?
    
    init (_ context: WebberContext) {
        self.context = context
    }
    
    deinit {
        observation?.invalidate()
    }
    
    enum ToolchainRetrieverError: Error, CustomStringConvertible {
        case unableToPreapareURL
        case unableToFindTagForCurrentOS
        case githubBadResponse
        case undecodableTag
        case unableToDownload
        case somethingWentWrong(Error)
        
        var description: String {
            switch self {
            case .unableToPreapareURL: return "Unable to prepare URL for toolchain tag"
            case .unableToFindTagForCurrentOS: return "Unable to find tag for current OS"
            case .githubBadResponse: return "Bad response from github"
            case .undecodableTag: return "Unable to decode tag from github"
            case .unableToDownload: return "Unable to download toolchain"
            case .somethingWentWrong(let e): return e.localizedDescription
            }
        }
    }
    
    private struct GithubTag: Decodable {
        struct Asset: Decodable {
            let name: String
            let size: Int
            let browser_download_url: URL
        }
        let assets: [Asset]
    }
    
    private var ubuntuRelease: String? {
        guard let data = FileManager.default.contents(atPath: "/etc/lsb-release"), let str = String(data: data, encoding: .utf8) else {
            return nil
        }
        if str.contains("DISTRIB_RELEASE=18.04") {
            return "ubuntu18.04"
        } else if str.contains("DISTRIB_RELEASE=20.04") {
            return "ubuntu20.04"
        }
        return nil
    }
    
    func retrieve() throws -> URL {
        guard let url = URL(string: "https://api.github.com/repos/swiftwasm/swift/releases/tags/swift-\(context.defaultToolchainVersion)") else {
            throw ToolchainRetrieverError.unableToPreapareURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let group = DispatchGroup()
        
        func getLastToolchainAsset() throws -> GithubTag.Asset {
            var d: Data?
            var r: URLResponse?
            var e: Error?
            group.enter()
            URLSession.shared.dataTask(with: request) {
                d = $0
                r = $1
                e = $2
                group.leave()
            }.resume()
            group.wait()
            if let err = e {
                throw ToolchainRetrieverError.somethingWentWrong(err)
            }
            guard let response = r as? HTTPURLResponse, (200..<300).contains(response.statusCode), let data = d else {
                throw ToolchainRetrieverError.githubBadResponse
            }
            let tag = try JSONDecoder().decode(GithubTag.self, from: data)
            #if os(macOS)
            guard let asset = tag.assets.first(where: { $0.name.contains("macos") && $0.name.contains(isAppleSilicon() ? "arm64" : "x86_64") }) else {
                throw ToolchainRetrieverError.undecodableTag
            }
            return asset
            #else
            guard
                let ubuntuRelease = self.ubuntuRelease,
                let asset = tag.assets.first(where: { $0.name.contains(ubuntuRelease) })
            else {
                throw ToolchainRetrieverError.unableToFindTagForCurrentOS
            }
            return asset
            #endif
        }
        
        let asset = try getLastToolchainAsset()
        
        func download(_ url: URL, _ size: Int) throws -> URL {
            var localURL: URL?
            var error: Error?
            group.enter()
            let task = URLSession.shared.downloadTask(with: url) {
                localURL = $0
                error = $2
                group.leave()
            }
            observation = task.progress.observe(\.fractionCompleted) { progress, _ in
                let progress = String(format: "%.2fMb (%.2f", (Double(size) / 1_000_000) * progress.fractionCompleted, progress.fractionCompleted * 100) + "%)"
                self.context.command.console.clear(.line)
                self.context.command.console.output([
                    ConsoleTextFragment(string: "Toolchain downloading progress: ", style: .init(color: .brightYellow)),
                    ConsoleTextFragment(string: progress, style: .init(color: .brightGreen)),
                ])
            }
            let downloadinStartedAt = Date()
            context.command.console.output([ConsoleTextFragment(string: "Started toolchain downloading", style: .init(color: .yellow))])
            task.resume()
            group.wait()
            context.command.console.clear(.line)
            context.command.console.output([
                ConsoleTextFragment(string: "Toolchain downloaded in ", style: .init(color: .brightGreen)),
                ConsoleTextFragment(string: String(format: "%.2fs", Date().timeIntervalSince(downloadinStartedAt)), style: .init(color: .brightMagenta)),
            ])
            guard error == nil else {
                throw ToolchainRetrieverError.unableToDownload
            }
            guard let localURLUnwrapped = localURL else {
                throw ToolchainRetrieverError.unableToDownload
            }
            #if os(macOS)
            let ext = ".pkg"
            #else
            let ext = ".tar.gz"
            #endif
            let destURL = URL(fileURLWithPath: "/tmp/" + localURLUnwrapped.deletingPathExtension().lastPathComponent + ext)
            try FileManager.default.moveItem(at: localURLUnwrapped, to: destURL)
            return destURL
        }
        
        return try download(asset.browser_download_url, asset.size)
    }
}
