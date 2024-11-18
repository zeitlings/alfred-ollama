//
//  InferenceAction.swift
//  Ollama
//
//  Created by Patrick Sy on 03/06/2024.
//

fileprivate let promptTemplatePlaceholder: String = "{input}"

struct ActionsWrapper: Decodable {
	let version: String
	let author: String
	let updated: String
	let actions: [InferenceAction]
}

enum InferenceTaskCompletion: String, Decodable {
	/// Persist the result for later review.
	case store
	/// Start new chat and stream the result.
	case chat
	/// Create calendar file(s) from the result
	case makeICS = "mk.ics"
}

struct InferenceAction: Decodable {
	let identifier: String
	let name: String
	let description: String
	let note: String?
	let systemPrompt: String
	let promptTemplate: String?
	let keywords: String?
	let contributors: [String]?
	let paste: Bool
	let preserveSelection: Bool
	let keycombosBefore: [KeyCombo]?
	let keycombosAfter: [KeyCombo]?
	let completion: InferenceTaskCompletion?
	let usePasteboard: Bool
	let isPublic: Bool
	let frontmostApplication: String?
	let modelOverride: String?
	let options: Options?
}

extension InferenceAction {
	struct Options: Decodable {
		let mirostat: Int?
		let mirostatEta: Float?
		let mirostatTau: Float?
		let numCtx: Int?
		let repeatLastN: Int?
		let repeatPenalty: Float?
		let temperature: Float?
		let seed: Int?
		let stop: String?
		let tfsZ: Float?
		let numPredict: Int?
		let topK: Int?
		let topP: Float?
		let numGqa: Int?
		let numGpu: Int?
		let numThread: Int?
	}
	
	struct KeyCombo: Decodable {
		let sequence: String
		let count: Int
	}
}

extension InferenceAction.Options {
	func into() -> ChatRequest.Options {
		ChatRequest.Options(
			mirostat: mirostat,
			mirostatEta: mirostatEta,
			mirostatTau: mirostatTau,
			numCtx: numCtx,
			numGqa: numGqa,
			numGpu: numGpu,
			numThread: numThread,
			repeatLastN: repeatLastN,
			repeatPenalty: repeatPenalty,
			temperature: temperature,
			seed: seed,
			stop: stop,
			tfsZ: tfsZ,
			numPredict: numPredict,
			topK: topK,
			topP: topP,
			keepAlive: Environment.ollamaModelLifetime
		)
	}
}


// MARK: - InferenceAction+Alfred
extension InferenceAction {
	var alfredItem: Item? {
		guard isPublic else { return nil }
		return .with {
			$0.title = name
			$0.subtitle = description
			$0.text = Text(copy: name, largetype: "\(name)\n\(description)\n\(note ?? "")")
			$0.valid = true
			$0.match = "\(name) \(description) \(keywords ?? "")"
			/// NB: The user input is expected to exist in the environment variables as `action_payload`.
			/// Set throught the workflow canvas.
			$0.variables = .nested([
				"action_dispatch_id": .string(identifier),
				"workflow_program_state": .string(Environment.ProgramState.generate.rawValue)
			])
		}
	}
}


// MARK: - InferenceAction+ChatRequest
extension InferenceAction {
	
	func chatRequest(payload: String, stream: Bool = false) -> ChatRequest {
		let model: String = {
			guard let installed: [Models.Model] = Ollama.installedModels else {
				Workflow.quit("No models installed.")
			}
			if let modelOverride, installed.first(where: { $0.name == modelOverride }) != nil {
				return modelOverride
			}
			return Ollama.preferredModel!
		}()
		
		let prompt: String = {
			if let promptTemplate: String {
				return promptTemplate.replacing(promptTemplatePlaceholder, with: "'\(payload)'")
			}
			return payload
		}()
		
		return .init(model: model, prompt: prompt, options: options?.into(), stream: stream, system: systemPrompt)
	}
	
}


// MARK: - InferenceAction+Workflow
// Workflow behaviour, e.g. paste, make ics, chat, store...
