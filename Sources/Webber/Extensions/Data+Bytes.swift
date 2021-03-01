//
//  Data+Bytes.swift
//  Webber
//
//  Created by Mihael Isaev on 05.02.2021.
//

import Foundation

extension Data {
    var bytes: [UInt8] { .init(self) }
}
