//
//  Ollama+Chat.swift
//  Ollama
//
//  Created by Patrick Sy on 30/05/2024.
//

import Foundation

// MARK: - Ollama Chat Start
extension Ollama {
	
	static func chat() {
		do {
			switch Workflow.chatDirective {
			case .readStream:  	  try self.readStream()
			case .displayChat: 	  try self.displayConversation()
			case .continueStream: try self.continueStreaming()
			case .startStream: 	  try self.startStreamBySpawning()
			case .writeStream: 	  try self.writeStreamFromSpawned()
			}
		} catch {
			Workflow.fail(with: error)
		}
	}
}

// MARK: Ollama Chat Error

enum OllamaChatError: Error, LocalizedError {
	case noInstalledModels
	var errorDescription: String? {
		switch self {
		case .noInstalledModels:
			return "[Error] No models installed."
		}
	}
}


// MARK: - Read Stream
extension Ollama {
	static func readStream() throws {
		if Workflow.beginContinueStreaming {
			Workflow.return(.beginContinueStreamingResponse)
		}
		
		let (streamedMessage, finished, streamFileIsStale) = try FileHandler.streamFileContent()
		
		guard !FileHandler.errorFileExists else {
			Workflow.return(try .abortWithErrorResponse(preserving: streamedMessage))
		}
		
		if !finished, streamFileIsStale {
			Workflow.return(try .abortWithStalledConnectionResponse(preserving: streamedMessage))
		}
		
		if !Environment.responseGenerationWasCancelled, streamedMessage.isEmpty {
			Workflow.return(.rerunEmptyWhileStreamingResponse)
		}
		
		var response: TextViewResponse = .init(response: streamedMessage)
		
		if !finished {
			response.rerun = 0.1
			response.signal(.nowStreaming)
			response.response?.append(" 􀀁")
			response.behaviour = .init(.replacelast, .auto) // .end
		} else {
			let messages: [Message] = try FileHandler.appendChat(.assistant, content: streamedMessage)
			response.response = messages.formattedMarkdown
			response.behaviour = .init(.replace, .auto) // .end
			try? FileHandler.removeStreamFile()
			try? FileHandler.removePIDFile()
			//Self.setLifetime()
		}
		Workflow.return(response)
	}
}


// MARK: - Continue Stream
extension Ollama {
	static func continueStreaming() throws -> Never {
		let previousChat: [Message] = try FileHandler.chatMessages()
		var markdown: String = previousChat.formattedMarkdown
		if let (streamedMessage, _, _) = try? FileHandler.streamFileContent() {
			markdown.append("\n\(streamedMessage)")
		}
		let response: TextViewResponse = .with {
			$0.response = markdown
			$0.behaviour = .init(scroll: .end)
			$0.signal(.continueStreaming)
			$0.signal(.nowStreaming)
			$0.rerun = 0.1
		}
		Workflow.return(response)
	}
}

// MARK: - View Chat
extension Ollama {
	static func displayConversation() throws {
		let messages: [Message] = {
			if let messages: [Message] = try? FileHandler.chatMessages() {
				return messages
			}
			let placeholder: String = "__Assistant__  ·  Hello! How can I help you today?"
			return [.init(role: .assistant, content: placeholder)]
		}()
		
		if !preferredModelIsLoaded {
			preloadModel()
		}

		Workflow.return(.with({
			$0.response = messages.formattedMarkdown
			$0.behaviour = .init(scroll: .end)
		}))
	}
}

// MARK: - Start Stream: Setup
extension Ollama {
	static func startStreamBySpawning() throws {
		guard !userInput.isEmpty else {
			preconditionFailure("User Input was empty.")
		}
		if !Workflow.preStreamFeedbackGiven {
			Workflow.return(.preStreamFeedbackResponse)
		}
		try FileHandler.createStreamFile()
		let messages: [Message] = FileHandler.chatFileExists
			? try FileHandler.appendChat(.user, content: userInput)
			: try FileHandler.createChat(.user, content: userInput)
		// ===--------------------------------------------------------=== //
		Task { try await triggerStreamSpawning() }
		// ===--------------------------------------------------------=== //
		RunLoop.current.run(until: Calendar.current.date(byAdding: .nanosecond, value: 200_000_000, to: .now)!) // 200ms
		
		let response: TextViewResponse = .with {
			$0.response = "\(messages.formattedMarkdown)"
			$0.behaviour = .init(.replace, .end)
			$0.rerun = 0.1
			$0.signal(.nowStreaming)
			$0.signal(.continueStreaming)
		}
		
		Workflow.return(response)
	}
}

// MARK: - Start Stream: Spawn
extension Ollama {
	static func triggerStreamSpawning() async throws {
		let executablePath: String = CommandLine.arguments[0]
		let token: String = Environment.startStreamArgumentToken
		// TODO: Handle the arguments with environment variables...
		let command: String = "\"\(executablePath)\" \"\(userInput)\" \"\(modelFile.absoluteString)\" \"true\" \"\(installedModelsRaw)\" \"\(loadedModelsRaw.joined(separator: "\n"))\" \"\(ollamaVersion)\" \"\(token)\""
		let process: Process = .init()
		process.shell(command)
	}
	
	/// Workaround while the `keep_alive` parameter doesn't work with the `/api/chat` endpoint.
	/// - Note: Called on `readStream()` completion.
	static func setLifetime() {
		let body: String = "{\"model\": \"\(preferredModel!)\", \"keep_alive\": \"\(Environment.ollamaModelLifetime)\"}"
		let keepAliveCommand: String = "curl \(Environment.ollamaScheme)://\(Environment.ollamaHost):\(Environment.ollamaPort)/api/generate -d '\(body)'"
		let process: Process = .init()
		Task {
			process.shell(keepAliveCommand)
		}
		RunLoop.current.run(until: Calendar.current.date(byAdding: .nanosecond, value: 200_000_000, to: .now)!) // 200ms
	}
	
	/// Preload the model when opening the chat window
	/// - Note:Dispatched at `displayConversation()` if the preferred model is not already loaded. Ignores `Environment.ollamaModelLifetime`.
	static func preloadModel() {
		guard let preferredModel else { return }
		//Workflow.log("Preloading preferred model", .info)
		let body: String = "{\"model\": \"\(preferredModel)\"}"
		let preloadCommand: String = "curl \(Environment.ollamaScheme)://\(Environment.ollamaHost):\(Environment.ollamaPort)/api/generate -d '\(body)'"
		let process: Process = .init()
		Task {
			process.shell(preloadCommand)
		}
		RunLoop.current.run(until: Calendar.current.date(byAdding: .nanosecond, value: 200_000_000, to: .now)!) // 200ms
	}
}

// MARK: - Write Stream
extension Ollama {
	
	static func writeStreamFromSpawned() throws {
		try FileHandler.writePIDFile()
		let messages: [Message] = try {
			let messages: [Message] = try FileHandler.chatMessages()
			let slice = messages.suffix(Environment.ollamaContext+1)
			/// Make sure the first message is a user-message.
			return .init(slice.first?.role == .user ? slice : slice.dropFirst())
			
			/// Wow, that's a new one: "Cannot convert value of type 'Message?' to expected argument type 'Morphology'"
			/// `return .init(slice.first? == .user ? slice : messages.suffix(Environment.ollamaContext+1))`
		}()
		guard preferredModel != nil else {
			throw OllamaChatError.noInstalledModels
		}
		 // ====================================================================
		Task {
			do {
				try await chatCompletion(messages: messages)
			} catch let DecodingError.keyNotFound(key, context) {
				let debugMessage: String = "\n\n> Key '\(key.stringValue)' not found: \(context.debugDescription). CodingPath: \(context.codingPath)"
				try FileHandler.writeError(message: "\n\n> 􀇾 \(debugMessage)")
				
			} catch let DecodingError.dataCorrupted(context) {
				let debugMessage: String = "\n\n> __[Decoding Error > Data Corrupted]__ \(context.debugDescription).  \n> __Coding Path:__ \(context.codingPath)."
				try FileHandler.writeError(message: "\n\n> 􀇾 \(debugMessage)")
			} catch {
				/// The Standard Output is not connected to Alfred anymore.
				/// To still be able to handle errors, we have to write them out a file that
				/// contains the error message. The error file is be handled at `readStream()`.
				try! FileHandler.writeError(message: "\n\n> 􀇾 \(error.localizedDescription)")
				Workflow.exit(.failure)
			}
		}
		
		// =========================================================================
		// The process will shut down when it is done, fails or is killed externally.
		RunLoop.current.run()
	}
}

// MARK: - Output Stream
extension Foundation.OutputStream {
	
	enum OutputStreamError: Error, LocalizedError {
		case bufferFailure
		case initFailure
		var errorDescription: String? {
			switch self {
			case .bufferFailure: return "[Output Stream Error] Failure writing output stream to file."
			case .initFailure: return "[Output Stream Error] Failure initializing output stream."
			}
		}
	}
	
	func write(_ string: String) throws {
		try Data(string.utf8).withUnsafeBytes { (buffer: UnsafeRawBufferPointer) throws in
			guard let pointer: UnsafePointer<UInt8> = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
				throw OutputStreamError.bufferFailure
			}
			write(pointer, maxLength: buffer.count)
		}
	}
}


// MARK: - Ollama Stream
extension Ollama {
	static func chatCompletion(messages: [Message]) async throws {
		guard let outputStream: OutputStream = .init(url: .streamFile, append: true) else {
			throw OutputStream.OutputStreamError.initFailure
		}
		let router: Router = .init()
		let query: ChatRequest = .init(model: preferredModel!, messages: messages, options: Environment.completionOptions)
		do {
			outputStream.open()
			// ===---------------------------------------------------------------------------------------------------=== //
			var signalStop: Bool = true
			let asyncStream: AsyncThrowingStream<ChatResponse, any Error> = try await router.stream(query)
			// ===---------------------------------------------------------------------------------------------------=== //
			for try await response: ChatResponse in asyncStream {
				if let content: String = response.message?.content, !content.isEmpty {
					try outputStream.write(content)
				}
				if response.done {
					try outputStream.write(Environment.stopToken)
					signalStop = false
					break
				}
			}
			if signalStop {
				/// Just-in-case failsafe
				try outputStream.write(Environment.stopToken)
			}
			outputStream.close()
			Workflow.exit(.success)
		} catch {
			outputStream.close()
			throw error
		}
	}
}
