//
//  TextView+Response.swift
//  Ollama
//
//  Created by Patrick Sy on 30/05/2024.
//

import Foundation

/// <https://www.alfredapp.com/help/workflows/user-interface/text/json/>
struct TextViewResponse: Codable {
	var response: String?
	var rerun: Double?
	var footer: String?
	var actionoutput: Bool?
	var behaviour: Behaviour?
	var variables: [String:String]?
	
	init(
		response: String? = nil,
		footer: String? = nil,
		actionoutput: Bool? = nil,
		behaviour: Behaviour? = nil,
		variables: [String:String]? = nil,
		rerun: Double? = nil
	) {
		self.response = response
		self.rerun = rerun
		self.footer = footer
		self.actionoutput = actionoutput
		self.behaviour = behaviour
		self.variables = variables
	}
}

extension TextViewResponse: Inflatable {
	init() { response = "" }
}

extension TextViewResponse {
	
	enum EnvironmentSignal {
		case nowStreaming
		case continueStreaming
	}
	
	/// Add the corresponding environment variable to the response for down stream control flow
	///
	mutating func signal(_ variable: EnvironmentSignal) {
		switch variable {
		case .nowStreaming: 	 add(variable: "true", forKey: "is_streaming")
		case .continueStreaming: add(variable: "true", forKey: "stream_continuation_marker")
		}
	}
	
	mutating func add(variable: String, forKey key: String) {
		guard variables != nil else {
			variables = [key:variable]
			return
		}
		variables?[key] = variable
	}
}


extension TextViewResponse {
	
	/// Write the Text View Response as JSON to the standard output
	func output(sortKeys: Bool = false) throws -> String {
		let encoder: JSONEncoder = .init()
		encoder.outputFormatting = [.prettyPrinted]
		if sortKeys {
			encoder.outputFormatting.update(with: .sortedKeys)
		}
		let json: Data = try encoder.encode(self)
		return String(data: json, encoding: .utf8)!
	}
}


extension TextViewResponse {
	
	struct Behaviour: Codable {
		var response: ResponseBehaviour?
		var scroll: ScrollBehaviour?
		var inputfield: InputFieldBehaviour?
		
		init(response: ResponseBehaviour? = nil, scroll: ScrollBehaviour? = nil, inputfield: InputFieldBehaviour? = nil) {
			self.response = response
			self.scroll = scroll
			self.inputfield = inputfield
		}
		
		init(_ response: ResponseBehaviour? = nil, _ scroll: ScrollBehaviour? = nil, _ inputfield: InputFieldBehaviour? = nil) {
			self.response = response
			self.scroll = scroll
			self.inputfield = inputfield
		}
		
		enum ResponseBehaviour: String, Codable {
			case replace, append, prepend, replacelast
		}
		
		enum ScrollBehaviour: String, Codable {
			case auto, start, end
		}
		
		enum InputFieldBehaviour: String, Codable {
			case clear, select
		}
	}
}

// MARK: - Convenience initializers

extension TextViewResponse {
	
	static let preStreamFeedbackResponse: Self = .with {
		$0.response = "![](icons/chat.user.png)\n\(Ollama.userInput)"
		$0.variables = ["gave_feedback":"true"]
		$0.behaviour = .init(.append)
		$0.rerun = 0.1
	}
	
	// FIXME: Unused?
	static func preToolCallFeedbackResponse(streamedMessage: String) -> Self {
		.with {
			$0.response = Workflow.formattedUserMessage(.init(role: .assistant, content: streamedMessage))
			$0.behaviour = .init(.append)
			$0.rerun = 0.1
			$0.variables = ["gave_tool_feedback":"true"]
			$0.signal(.nowStreaming)
		}
	}
	
	static let rerunEmptyBeforeToolCallResponse: Self = .with {
		$0.variables = ["gave_tool_feedback":"true"]
		$0.signal(.nowStreaming)
		$0.rerun = 0.1
	}
		
	static let beginContinueStreamingResponse: Self = .with {
		$0.response = " 􀀁"
		$0.behaviour = .init(.append)
		$0.signal(.nowStreaming)
		$0.rerun = 0.1
	}
	
	static let rerunEmptyWhileStreamingResponse: Self = .with {
		$0.signal(.nowStreaming)
		$0.rerun = 0.1
	}
	
	static func abortWithErrorResponse(preserving streamedMessage: String) throws -> Self {
		let errorMessage: String = try FileHandler.errorFileContent()
		let teardownMessage: String = "\n\(streamedMessage)\n\(errorMessage)"
		let teardownStreamFile: String = "\(streamedMessage)\n\(errorMessage)\(Environment.stopToken)"
		try teardownStreamFile.write(to: .streamFile, atomically: true, encoding: .utf8)
		try FileHandler.removeErrorFile()
		
		let abortResponse: Self = .with {
			$0.response = teardownMessage
			$0.rerun = 0.1
			$0.signal(.nowStreaming)
			$0.behaviour = .init(.replacelast, .end)
		}
		
		return abortResponse
		
	}
	
	static func abortWithStalledConnectionResponse(preserving streamedMessage: String) throws -> Self {
		
		// Ensure that the streamed message was not already persisted.
		let shouldSave: Bool = {
			if let messages: [Message] = try? FileHandler.chatMessages(),
			   let last: Message = messages.last,
			   last.content == streamedMessage
			{
				return false
			}
			return true
		}()
		
		var teardownMessage: String = "\(streamedMessage) __[Connection Stalled]__"
		var teardownStreamFile: String = "\(teardownMessage)\(Environment.stopToken)"
		
		if shouldSave {
			//try FileHandler.appendChat(.assistant, content: teardownMessage)
		} else {
			teardownMessage = " __[Connection Stalled]__"
			teardownStreamFile = "\(teardownMessage)\(Environment.stopToken)"
		}
		
		try? FileHandler.removePIDFile()
		try teardownStreamFile.write(to: .streamFile, atomically: true, encoding: .utf8)
		//try FileHandler.removeStreamFile()
		
		let stalledResponse: Self = .with {
			$0.response = teardownMessage
			$0.rerun = 0.1
			$0.signal(.nowStreaming)
			// FIXME: Sic?
			$0.behaviour = shouldSave ? .init(.replacelast, .auto) : .init(.append, .auto)
		}
		
		return stalledResponse
		
	}
	
}
