//
//  Workflow+Shell.swift
//  Ollama
//
//  Created by Patrick Sy on 29/09/2024.
//

import Foundation

// MARK: Workflow+ExternalTrigger
extension Workflow {
	
	/// `open alfred://runtrigger/{bundle_id}/{trigger_id}}/?argument=the%20argument"`
	@discardableResult
	static func externalTrigger(id triggerId: String, arg: String, exit: Bool = false, process: Process = .init()) -> Never? {
		guard
			let bundleId: String = Environment.workflowBundleID,
			let encoded: String = arg.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
		else {
			preconditionFailure(#function)
		}
		let command: String = "open alfred://runtrigger/\(bundleId)/\(triggerId)/?argument=\(encoded)"
		process.shell(command)
		if exit {
			Self.exit(.success)
		}
		return nil
	}
}

// MARK: Shell / Bash
extension Process {
	
	@discardableResult
	func shell(_ command: String) -> String? {
		let pipe = Pipe()
		
		self.standardOutput = pipe
		self.executableURL = URL(fileURLWithPath: "/bin/bash")
		self.arguments = ["-c", command]
		
		try? self.run()
		self.waitUntilExit()
		
		let data = pipe.fileHandleForReading.readDataToEndOfFile()
		return String(data: data, encoding: .utf8)?.trimmed
	}
}
