//
//  Apt.swift
//  
//
//  Created by Mihael Isaev on 12.09.2022.
//

import Foundation
import WebberTools

struct Apt {
	enum AptError: Error, CustomStringConvertible {
		case unableToInstall(program: String)
		
		var description: String {
			switch self {
			case .unableToInstall(let program): return "Unable to install `\(program)`"
			}
		}
	}
	
	static func install(_ program: String) throws {
		let stdout = Pipe()
		let process = Process()
		process.launchPath = try Bash.which("apt")
		process.arguments = ["install", program, "-qq", "-y"]
		process.standardOutput = stdout
		
		let outHandle = stdout.fileHandleForReading
		outHandle.waitForDataInBackgroundAndNotify()

		process.launch()
		process.waitUntilExit()
		
		guard process.terminationStatus == 0 else {
			throw AptError.unableToInstall(program: program)
		}
	}
}
