//
//  FileHandler.swift
//  Ollama
//
//  Created by Patrick Sy on 30/05/2024.
//

import Foundation

struct FileHandler {
	static let fm: FileManager = .default
	static let streamFileExists: Bool = fm.fileExists(.streamFile)
	static let chatFileExists: Bool = fm.fileExists(.chatFile)
	static let errorFileExists: Bool = fm.fileExists(.errorFile)
}

// MARK: - FileHandler Stream File

extension FileHandler {
	
	static func createStreamFile() throws {
		try createCacheDirectory()
		fm.createFile(.streamFile)
	}
	
	static func removeStreamFile() throws {
		try fm.removeItem(at: .streamFile)
	}
	
	static func streamFileContent(function: String = #function) throws -> (content: String, finished: Bool, isStale: Bool) {
		
		guard fm.fileExists(.streamFile) else {
			Workflow.log(function)
			if Environment.responseGenerationWasCancelled {
				return ("", true, false)
			} else {
				throw FileHandlerError.streamFileDoesNotExist
			}
		}
		
		let content: String = try URL.streamFile.contents()
		let finished: Bool = content.hasSuffix(Environment.stopToken)
		return finished
			? (String(content.dropLast(Environment.stopToken.count)), finished, false)
			: (content, finished, URL.streamFile.isStale)
		
	}
}

// MARK: - FileHandler Chat File
extension FileHandler {
	static func createChat(_ role: Message.Role, content: String) throws -> [Message] {
		assert(role == .user)
		try createCacheDirectory()
		let message: Message = .init(role: role, content: content)
		let contents: Data = try JSONEncoder().encode([message])

		//if fm.fileExists(.chatFile) {
		//	// =================================================
		//	// TODO: Archive chat file?
		//	// Note: Creating a file overwrites the existing one
		//	// =================================================
		//	Workflow.logWarning(.chatFileExists)
		//}
		
		fm.createFile(.chatFile, contents: contents)
		return [message]
	}
	
	static func chatMessages(function: String = #function) throws -> [Message] {
		guard fm.fileExists(.chatFile) else {
			throw FileHandlerError.chatFileDoesNotExist
			//return try createChat(.user, content: "Precondition failure: Chat File must exist. (\(function))")
		}
		let content: Data = try Data(contentsOf: .chatFile)
		let messages: [Message] = try JSONDecoder().decode([Message].self, from: content)
		return messages
	}
	
	/// Append message to chat, saving the entire conversation.
	@discardableResult
	//static func appendChat(_ role: Message.Role, content: String) throws -> [Message] {
	static func appendChat(
		_ role: Message.Role,
		content: String
	) throws -> [Message] {
		var chat: [Message] = try chatMessages()
		chat.append(
			Message(role: role, content: content)
		)
		try save(chat: chat)
		return chat
	}
	
	
	private static func save(chat: [Message]) throws {
		let encoded: Data = try JSONEncoder().encode(chat)
		fm.createFile(.chatFile, contents: encoded)
	}
	
}


// MARK: - File Handler PID File
extension FileHandler {
	static func removePIDFile() throws {
		if fm.fileExists(.pidFile) {
			try fm.removeItem(at: .pidFile)
		}
	}
	
	static func writePIDFile() throws {
		let pid: String = "\(ProcessInfo.processInfo.processIdentifier)"
		try pid.write(to: .pidFile, atomically: true, encoding: .utf8)
	}
}

// MARK: - File Handler Error file
extension FileHandler {

	static func removeErrorFile() throws {
		if fm.fileExists(.errorFile) {
			try fm.removeItem(at: .errorFile)
		}
	}
	
	//static func writeError(message: String, file: String = #file, function: String = #function, line: String = "\(#line)") throws {
	static func writeError(message: String) throws {
		try message.write(to: .errorFile, atomically: true, encoding: .utf8)
	}
	
	static func errorFileContent() throws -> String {
		guard fm.fileExists(.errorFile) else {
			throw FileHandlerError.errorFileDoesNotExist
		}
		
		let content: String = try String(contentsOf: .errorFile)
		return content
	}
}

// MARK: - File Handler Debug File

extension FileHandler {
	static func writeDebugFile(message: String, randomize: Bool = false) throws {
		var debugFile: URL = .debugFile
		if randomize {
			let file: URL = .debugFile
				.deletingPathExtension()
				.appendingPathExtension(UUID().uuidString.lowercased())
				.appendingPathExtension("txt")
			debugFile = file
		}
		try message.write(to: debugFile, atomically: true, encoding: .utf8)
	}
}




// MARK: - FileHandler Utils
extension FileHandler {
	static func createCacheDirectory() throws {
		let cachePath: String = Environment.workflowCacheDirectory
		if !fm.fileExists(atPath: cachePath) {
			try fm.createDirectory(atPath: cachePath, withIntermediateDirectories: true)
		}
	}
	
	static func createDataDirectory() throws {
		let dataPath: String = Environment.workflowDataDirectory
		if !fm.fileExists(atPath: dataPath) {
			try fm.createDirectory(atPath: dataPath, withIntermediateDirectories: true)
		}
	}
}




// MARK: - File Handler Error
extension FileHandler {
	enum FileHandlerError: Error, LocalizedError {
		case streamFileDoesNotExist
		case chatFileDoesNotExist
		case errorFileDoesNotExist
		
		var errorDescription: String? {
			// TODO: Wrap in horizontal rule to match StreamGenerationErrors
			switch self {
			case .streamFileDoesNotExist:
				return "\n\n[File System Error] Stream file does not exist."
			case .chatFileDoesNotExist:
				return "\n\n[File System Error] Chat file does not exist."
			case .errorFileDoesNotExist:
				return "\n\n[File System Error] Unreachable (Error file does not exist)."
			}
		}
	}

}

// MARK: - File Handler Extensions
extension URL {
	static let streamFile: URL = .init(path: Environment.workflowCacheDirectory).appending(component: "stream").appendingPathExtension("txt")
	static let chatFile: URL = .init(path: Environment.workflowCacheDirectory).appending(component: "chat").appendingPathExtension("json")
	static let pidFile: URL = .init(path: Environment.workflowCacheDirectory).appending(component: "pid").appendingPathExtension("txt")
	static let errorFile: URL = .init(path: Environment.workflowCacheDirectory).appending(component: "error").appendingPathExtension("txt")
	static let debugFile: URL = .init(path: Environment.workflowCacheDirectory).appending(component: "debug").appendingPathExtension("txt")

	static let inferenceActionsFile: URL = .init(path: Environment.workflowPath).appending(component: "actions").appending(component: "actions").appendingPathExtension("json")
}

extension URL {
	var isStale: Bool {
		guard let rv = try? self.resourceValues(forKeys: [.contentModificationDateKey]),
			  let modificationDate: Date = rv.contentModificationDate
		else {
			/// Keep going, do no harm.
			return false
		}
		/// Wait one second longer than the server is willing to wait.
		/// Handles only cases where something went wrong internally.
		return modificationDate < .now.addingTimeInterval(-(Environment.timeout))
	}
	
	func contents() throws -> String {
		var data = try Data(contentsOf: self)
		data += Data("".utf8) // NSData Bridging
		return data.withUnsafeBytes { String(decoding: $0, as: UTF8.self) }
	}
}

extension FileManager {
	func fileExists(_ url: URL) -> Bool {
		fileExists(atPath: url.path(percentEncoded: false))
	}
	func createFile(_ url: URL, contents: Data? = nil) {
		createFile(atPath: url.path(percentEncoded: false), contents: contents)
	}
}
