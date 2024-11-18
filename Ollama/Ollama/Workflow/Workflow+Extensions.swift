//
//  Workflow+Extensions.swift
//  Ollama
//
//  Created by Patrick Sy on 29/09/2024.
//

import Foundation


extension Workflow {
	static let isStreaming: Bool = Environment.environment["is_streaming"] == "true"
	static let shouldContinueStreaming: Bool = FileHandler.streamFileExists
	static let beginContinueStreaming: Bool = Environment.environment["stream_continuation_marker"] == "true"
	static let preStreamFeedbackGiven: Bool = Environment.environment["gave_feedback"] == "true"
}

// MARK: Workflow+Chat+Markdown
extension Workflow {
	static func formattedUserMessage(_ message: Message) -> String {
		"\n\n![](icons/chat.user.png)\n\(message.content)\n\n![](icons/chat.assistant.png)\n\n"
	}
}

// MARK: Workflow+Chat+Directive
extension Workflow {
	/// Directive for program state `chat`
	enum DirectiveChat {
		case readStream
		case startStream 	// new chat request
		case writeStream 	// spawn on new process
		case continueStream
		case displayChat
	}
	
	static var chatDirective: DirectiveChat {
		let args: [String] = CommandLine.arguments
		switch true {
		case args.indices.contains(7) && args[7] == Environment.startStreamArgumentToken:
			return .writeStream
		case isStreaming:
			return .readStream
		case shouldContinueStreaming:
			return .continueStream
		case !Ollama.userInput.isEmpty:
			return .startStream
		default:
			return .displayChat
		}
	}
	
}
