//
//  AppType.swift
//  Webber
//
//  Created by Mihael Isaev on 21.02.2021.
//

import Foundation

enum AppType: String, LosslessStringConvertible {
    var description: String { rawValue }
    
    init?(_ description: String) {
        switch description {
        case "spa": self = .spa
        case "pwa": self = .pwa
        default: return nil
        }
    }
    
    case spa, pwa
    
    static var all: [String] {
        [AppType.spa, .pwa].map { $0.rawValue }
    }
}
