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
    
    static func watch(_ path: String, closure: @escaping () -> Void) {
        watch(URL(fileURLWithPath: path), closure: closure)
    }
    
    static func watch(_ url: URL, closure: @escaping () -> Void) {
        _fs.monitors.append(DirectoryMonitor(url).startMonitoring(closure))
    }
    
    static func contains(path: String) -> Bool {
        _fs.monitors.contains(where: { $0.url.path == path })
    }
    
    static func shutdown() {
        _fs.monitors.forEach { $0.stopMonitoring() }
    }
}
