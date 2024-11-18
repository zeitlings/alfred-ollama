//
//  Workflow+Environment.swift
//  Ollama
//
//  Created by Patrick Sy on 29/09/2024.
//

import Foundation

struct Environment {
	
	static let environment: [String:String] = ProcessInfo.processInfo.environment
	static let workflowCacheDirectory: String = environment["alfred_workflow_cache"]!
	static let workflowDataDirectory: String = environment["alfred_workflow_data"]!
	static let workflowBundleID: String? = environment["alfred_workflow_bundleid"]
	private static let preferences: String = environment["alfred_preferences"]!
	private static let workflowUID: String = environment["alfred_workflow_uid"]!
	static let workflowPath: String = "\(preferences)/workflows/\(workflowUID)"
	
	
	// MARK: Program State
	enum ProgramState: String {
		case manage
		case chat
		case generate
		case actions // list the available inference actions
	}
	static let programState: ProgramState = .init(rawValue: getDefined("workflow_program_state") ?? "manage")!
	static let responseGenerationWasCancelled: Bool = environment["was_canceled"] == "true"
	
	static let timeout: TimeInterval = getDefined("timeout") ?? 30.0
	static let preferredModel: String? = getDefined("chat_preferred_model")
	static let systemPrompt: String? = getDefined("system_prompt")
	static let ollamaPort: Int = getDefined("workflow_port") ?? 11434
	static let ollamaHost: String = getDefined("workflow_host") ?? "localhost"
	static let ollamaScheme: String = getDefined("workflow_scheme") ?? "http"
	
	// MARK: Stream Constants
	static let startStreamArgumentToken: String = "--START_STREAM"
	static let stopToken: String = "[MESSAGE_STOP]"
	
	// MARK: Ollama Chat Configuration
	static let ollamaModelLifetime: String = environment["keep_alive"] ?? "5m" // Doesn't work currently with the /api/chat endpoint
	static let ollamaTemparature: Float = getDefined("temperature")!
	static let ollamaContext: Int = getDefined("context_size")!
	static let ollamaMirostat: Int? = getDefined("mirostat")
	static let ollamaMirostatEta: Float? = getDefined("mirostat_eta")
	static let ollamaMirostatTau: Float? = getDefined("mirostat_tau")
	static let ollamaNumCtx: Int? = getDefined("num_ctx")
	static let ollamaRepeatLastN: Int? = getDefined("repeat_last_n")
	static let ollamaRepeatPenalty: Float? = getDefined("repeat_penalty")
	static let ollamaSeed: Int? = getDefined("seed")
	static let ollamaStop: String? = getDefined("stop")
	static let ollamaTfsZ: Float? = getDefined("tfs_z")
	static let ollamaNumPredict: Int? = getDefined("num_predict")
	static let ollamaTopK: Int? = getDefined("top_k")
	static let ollamaTopP: Float? = getDefined("top_p")
	static let ollamaNumGPU: Int? = getDefined("num_gpu")
	static let ollamaNumGQA: Int? = getDefined("num_gqa")
	static let ollamaNumThread: Int? = getDefined("num_thread")
	static let completionOptions: ChatRequest.Options = .init(
		mirostat: ollamaMirostat,
		mirostatEta: ollamaMirostatEta,
		mirostatTau: ollamaMirostatTau,
		numCtx: ollamaNumCtx,
		numGqa: ollamaNumGPU,
		numGpu: ollamaNumGQA,
		numThread: ollamaNumThread,
		repeatLastN: ollamaRepeatLastN,
		repeatPenalty: ollamaRepeatPenalty,
		temperature: ollamaTemparature,
		seed: ollamaSeed,
		stop: ollamaStop,
		tfsZ: ollamaTfsZ,
		numPredict: ollamaNumPredict,
		topK: ollamaTopK,
		topP: ollamaTopP,
		keepAlive: ollamaModelLifetime
	)
	
	// MARK: Ollama Generate
	// Inference Tasks
	
	/// The target content of an inference task, e.g. text sent by the user via an universal action.
	static let inferenceActionPayload: String? = getDefined("action_payload")
	static let inferenceActionIdentifier: String? = getDefined("action_dispatch_id")
	static let exportLocation: String = getDefined("workflow_export_location") ?? workflowDataDirectory
	
	
	@inline(__always)
	//@_specialize(where T == String)
	static func getDefined<T: LosslessStringConvertible>(_ variable: String) -> T? {
		if let value: String = environment[variable]?.trimmed, !value.isEmpty {
			return .init(value)
		}
		return nil
	}
}
