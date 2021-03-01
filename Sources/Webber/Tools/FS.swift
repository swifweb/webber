//
//  FS.swift
//  Webber
//
//  Created by Mihael Isaev on 10.02.2021.
//

import Foundation

private let _fs = FS()

final class FS {
    private var monitors: [DirectoryMonitor] = []
    
    fileprivate init () {}
    
    deinit {
        monitors.forEach { $0.stopMonitoring() }
    }
    
    static func watchFile(_ path: String, closure: @escaping () -> Void) {
        watchFile(URL(fileURLWithPath: path), closure: closure)
    }
    
    static func watchFile(_ url: URL, closure: @escaping () -> Void) {
        _fs.monitors.append(DirectoryMonitor(url, singleFile: true).startMonitoring(closure))
    }
    
    static func watchDirectory(_ path: String, closure: @escaping () -> Void) {
        watchDirectory(URL(fileURLWithPath: path), closure: closure)
    }
    
    static func watchDirectory(_ url: URL, closure: @escaping () -> Void) {
        func scan(_ path: String) -> [String] {
            var isDir: ObjCBool = true
            guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir) else { return [] }
            guard isDir.boolValue else { return [] }
            guard let directoryContent = try? FileManager.default.contentsOfDirectory(atPath: path) else { return [path] }
            return [path] + directoryContent.flatMap { scan(path + "/" + $0) }
        }
        scan(url.path).forEach {
            let dm = DirectoryMonitor($0, watchSubdirectoryCreation: true).startMonitoring(closure)
            _fs.monitors.append(dm)
        }
    }
    
    static func contains(path: String) -> Bool {
        _fs.monitors.contains(where: { $0.url.path == path })
    }
    
    static func shutdown() {
        _fs.monitors.forEach { $0.stopMonitoring() }
    }
}
