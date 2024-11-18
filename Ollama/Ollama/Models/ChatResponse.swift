//
//  ChatResponse.swift
//  Ollama
//
//  Created by Patrick Sy on 30/05/2024.
//

import Foundation


/// Response <https://github.com/ollama/ollama/blob/main/docs/api.md#response-11>
struct ChatResponse: Decodable {
	let model: String
	//let createdAt: Date // "2024-05-30T20:49:18.099431Z"
	let createdAt: String
	let message: Message? // /api/chat
	let response: String? // /api/generate
	let done: Bool
	let totalDuration: Int?
	let loadDuration: Int?
	let promptEvalCount: Int?
	let promptEvalDuration: Int?
	let evalCount: Int?
	let evalDuration: Int?
	
	enum CodingKeys: String, CodingKey {
		case model, message, response, done
		case createdAt = "created_at"
		case evalCount = "eval_count"
		case loadDuration = "load_duration"
		case evalDuration = "eval_duration"
		case totalDuration = "total_duration"
		case promptEvalCount = "prompt_eval_count"
		case promptEvalDuration = "prompt_eval_duration"
	}
}
