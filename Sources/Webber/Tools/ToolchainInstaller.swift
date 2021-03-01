//
//  ToolchainInstaller.swift
//  Webber
//
//  Created by Mihael Isaev on 02.02.2021.
//

import Foundation

class ToolchainInstaller {
    let context: WebberContext
    let url: URL
    
    init (_ context: WebberContext, _ url: URL) {
        self.context = context
        self.url = url
    }
}
