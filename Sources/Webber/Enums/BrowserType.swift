//
//  BrowserType.swift
//  
//
//  Created by Mihael Isaev on 28.11.2022.
//

import Foundation

enum BrowserType: String, LosslessStringConvertible {
    var description: String { rawValue }
    
    init?(_ description: String) {
        switch description.lowercased() {
        case "safari": self = .safari
        case "chrome": self = .chrome
        case "google chrome": self = .chrome
        default: return nil
        }
    }
    
    case safari, chrome
    
    var appName: String {
        switch self {
        case .safari: return "Safari"
        case .chrome: return "Google Chrome"
        }
    }
    
    static var all: [String] {
        [BrowserType.safari, .chrome].map { $0.rawValue }
    }
}
