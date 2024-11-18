//
//  ChatRequest.swift
//  Ollama
//
//  Created by Patrick Sy on 30/05/2024.
//

import Foundation

struct ChatRequest: Encodable {
	let stream: Bool
	let model: String
	let messages: [Message]?
	let options: Options?
	let keepAlive: String?

	// Generate Endpoint
	let system: String?
	let prompt: String?
				
	/// `/api/chat` endpoint initializer
	init(model: String, messages: [Message], stream: Bool = true, options: Options) {
		self.stream = stream
		self.model = model
		self.messages = messages.injectingSystemPrompt()
		self.prompt = nil
		self.options = options
		self.system = nil
		self.keepAlive = Environment.ollamaModelLifetime
	}
	
	/// `/api/generate` endpoint initializer
	init(model: String, prompt: String, options: Options?, stream: Bool = false, system: String? /*= Environment.systemPrompt*/) {
		self.stream = stream
		self.model = model
		self.messages = nil
		self.prompt = prompt
		self.options = options
		self.system = system
		self.keepAlive = Environment.ollamaModelLifetime
	}
	
}

extension ChatRequest {
	enum CodingKeys: String, CodingKey {
		case stream, model, messages, options, prompt, system
		case keepAlive = "keep_alive"
	}
}

extension ChatRequest {
	// MARK: Chat Request Options
	/// Valid Parameters and Values: <https://github.com/ollama/ollama/blob/main/docs/modelfile.md#valid-parameters-and-values>
	struct Options: Encodable {
		var mirostat: Int?
		var mirostatEta: Float?
		
		/// Controls the balance between coherence and diversity of the output. A lower value will result in more focused and coherent text. (Default: 5.0)
		var mirostatTau: Float?
		var numCtx: Int?
		var numGqa: Int?
		var numGpu: Int?
		var numThread: Int?
		var repeatLastN: Int?
		var repeatPenalty: Float?
		
		/// The default is 0.8
		var temperature: Float?
		var seed: Int?
		var stop: String?
		var tfsZ: Float?
		var numPredict: Int? // max token output
		
		/// Reduces the probability of generating nonsense. A higher value (e.g. 100) will give more diverse answers, while a lower value (e.g. 10) will be more conservative. (Default: 40)
		var topK: Int?
		
		/// Works together with top-k. A higher value (e.g., 0.95) will lead to more diverse text, while a lower value (e.g., 0.5) will generate more focused and conservative text. (Default: 0.9)
		var topP: Float?
		
		/// The default is 5 minutes.
		/// - `-1m` indefinitely
		/// - `20m` 20 minutes, etc.
		/// See [#2146](https://github.com/ollama/ollama/pull/2146)
		var keepAlive: String?
		
		enum CodingKeys: String, CodingKey {
			case mirostat
			case mirostatEta = "mirostat_eta"
			case mirostatTau = "mirostat_tau"
			case numCtx = "num_ctx"
			case numGqa = "num_gqa"
			case numGpu = "num_gpu"
			case numThread = "num_thread"
			case repeatLastN = "repeat_last_n"
			case repeatPenalty = "repeat_penalty"
			case temperature
			case seed
			case stop
			case tfsZ = "tfs_z"
			case numPredict = "num_predict"
			case topK = "top_k"
			case topP = "top_p"
			case keepAlive = "keep_alive"
		}
	}
}

fileprivate extension Array where Element == Message {
	
	func injectingSystemPrompt() -> Self {
		var messages: [Message] = self
		if let systemPrompt: String = Environment.systemPrompt {
			messages = [.init(role: .system, content: systemPrompt)] + self
		}
		
		return messages
	}
	
}
