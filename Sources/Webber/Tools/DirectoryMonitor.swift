//
//  DirectoryMonitor.swift
//  Webber
//
//  Created by Mihael Isaev on 10.02.2021.
//

import Foundation

class DirectoryMonitor {
    lazy var dispatchQueue = DispatchQueue(label: "webber.directorymonitor", attributes: .concurrent)
    
    var fileDescriptor: Int32 = -1
    var dispatchSource: DispatchSourceFileSystemObject?
    
    let url: URL
    let singleFile: Bool
    let watchSubdirectoryCreation: Bool
    
    var subfolders: [String] = []
    var subfolderMonitors: [DirectoryMonitor] = []
    
    init(_ url: URL, singleFile: Bool = false, watchSubdirectoryCreation: Bool = false) {
        self.url = url
        self.singleFile = singleFile
        self.watchSubdirectoryCreation = watchSubdirectoryCreation
    }
    
    convenience init(_ path: String, singleFile: Bool = false, watchSubdirectoryCreation: Bool = false) {
        self.init(URL(fileURLWithPath: path), singleFile: singleFile, watchSubdirectoryCreation: watchSubdirectoryCreation)
    }
    
    @discardableResult
    func startMonitoring(_ closure: @escaping () -> Void) -> Self {
        guard dispatchSource == nil && fileDescriptor == -1 else { return self }
        func scanSubfolders() -> [String] {
            guard let content = try? FileManager.default.contentsOfDirectory(atPath: url.path) else { return [] }
            return content.filter {
                let path = url.appendingPathComponent($0).path
                var isDir: ObjCBool = false
                return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
            }
        }
        
        if watchSubdirectoryCreation {
            subfolders = scanSubfolders()
        }
        
        fileDescriptor = open(url.path, O_EVTONLY)
        guard fileDescriptor != -1 else { return self }
        
        dispatchSource = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileDescriptor, eventMask: .all, queue: dispatchQueue)
        dispatchSource?.setEventHandler {
            guard let data = self.dispatchSource?.data else { return }
            if self.singleFile {
                closure()
                if data.contains(.link) {
                    self.dispatchSource?.cancel()
                    self.dispatchQueue.asyncAfter(deadline: .now() + 1) {
                        self.startMonitoring(closure)
                    }
                }
                return
            }
            closure()
            guard self.watchSubdirectoryCreation == true else { return }
            guard data.contains(.write) else { return }
            scanSubfolders().forEach {
                guard !self.subfolders.contains($0) else { return }
                self.subfolders.append($0)
                self.subfolderMonitors.append(DirectoryMonitor(self.url.appendingPathComponent($0), watchSubdirectoryCreation: true).startMonitoring(closure))
            }
        }
        dispatchSource?.setCancelHandler {
            close(self.fileDescriptor)
            
            self.fileDescriptor = -1
            self.dispatchSource = nil
            self.subfolderMonitors.forEach { $0.stopMonitoring() }
        }
        dispatchSource?.resume()
        
        return self
    }
    
    func stopMonitoring() {
        dispatchSource?.cancel()
    }
}
