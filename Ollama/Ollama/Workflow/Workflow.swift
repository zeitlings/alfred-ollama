//
//  Workflow.swift
//  Ollama
//
//  Created by Patrick Sy on 29/09/2024.
//

import Foundation

struct Workflow {
	private static let stdOut: FileHandle = .standardOutput
	private static let stdErr: FileHandle = .standardError
}

extension Workflow {
	enum ExitCode { case success, failure }
	static func exit(_ code: ExitCode) -> Never {
		switch code {
		case .success: Darwin.exit(EXIT_SUCCESS)
		case .failure: Darwin.exit(EXIT_FAILURE)
		}
	}
	
	static func quit(
		_ title: String,
		_ subtitle: String = "",
		icon: Icon = .failure,
		_ code: ExitCode = .failure
	) -> Never {
		let text: String = "\(title). \(subtitle)"
		let output: String = try! ScriptFilterResponse(items: [.with {
			$0.title = title
			$0.subtitle = subtitle
			$0.arg = .string(title)
			$0.text = Text(copy: text, largetype: text)
			$0.icon = icon
		}]).encoded()
		try! stdOut.write(contentsOf: Data(output.utf8))
		exit(code)
	}
	
	static func info(_ title: String, _ subtitle: String = "") -> Never {
		quit(title, subtitle, icon: .info, .success)
	}
}

extension Workflow {
	
	static func `return`(_ response: ScriptFilterResponse, nullMessage: String = "No results...") -> Never {
		do {
			
			var response: ScriptFilterResponse = response
			response.skipknowledge = true
			
			// Default no results message
			// Preserve variables if there are any
			guard !response.items.isEmpty else {
				let nullResponse: ScriptFilterResponse = .init(items: [Item.with({
					$0.title = nullMessage
					$0.icon = .info
					$0.valid = false
				})], variables: response.variables)
				
				let json: String = try nullResponse.encoded()
				try stdOut.write(contentsOf: Data(json.utf8))
				exit(.success)
			}
			let json: String = try response.encoded()
			try stdOut.write(contentsOf: Data(json.utf8))
			exit(.success)
			
		} catch let error {
			quit("Error @ \(#function)", error.localizedDescription)
		}
	}
	
}

// MARK: - Workflow+TextView+Response
extension Workflow {
	static func fail(with error: Error) -> Never {
		Workflow.quit(message: error.localizedDescription)
	}
	
	static func `return`(_ response: TextViewResponse) -> Never {
		do {
			let json: String = try response.output()
			try stdOut.write(contentsOf: Data(json.utf8))
			exit(.success)
			
		} catch let error {
			fail(with: error)
		}
	}
	
	/// Write to stdOut and optionally exit.
	@discardableResult
	static func write(_ string: String, exit: Bool = true) -> Never? {
		try? stdOut.write(contentsOf: Data(string.utf8))
		if exit { self.exit(.success) }
		return nil
	}
	
	static func quit(message: String, _ code: ExitCode = .success) -> Never {
		let fatalResponse: TextViewResponse = .init(
			response: "\n\n... \(message)",
			behaviour: .init(response: .append)
		)
		let json: String = try! fatalResponse.output()
		try! stdOut.write(contentsOf: Data(json.utf8))
		exit(code)
	}
}

// MARK: - Workflow+Log
extension Workflow {
	
	enum AnnotationLog: String {
		case warning = "[WARNING] "
		case error = "[ERROR] "
		case info = "[INFO] "
		case debug = "[DEBUG] "
		case none = ""
	}
	static func log(_ message: String, _ annotation: AnnotationLog = .none) {
		try? stdErr.write(contentsOf: Data("\(annotation.rawValue)\(message)\n".utf8))
	}
}
