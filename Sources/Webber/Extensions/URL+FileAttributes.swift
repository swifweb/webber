//
//  URL+FileAttributes.swift
//  Webber
//
//  Created by Mihael Isaev on 21.02.2021.
//  Taken from https://stackoverflow.com/questions/28268145/get-file-size-in-swift
//

import Foundation

extension URL {
    var attributes: [FileAttributeKey : Any]? {
        do {
            return try FileManager.default.attributesOfItem(atPath: path)
        } catch {
            debugPrint("FileAttribute error: \(error)")
        }
        return nil
    }

    var fileSize: UInt64 {
        attributes?[.size] as? UInt64 ?? UInt64(0)
    }

    var fileSizeString: String {
        ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }

    var creationDate: Date? {
        attributes?[.creationDate] as? Date
    }
}
