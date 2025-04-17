//
//  Ollama+Generate.swift
//  Ollama
//
//  Created by Patrick Sy on 01/06/2024.

import Foundation

// MARK: - Action ScriptFilter Methods
extension Ollama {
	
	static func listActions() {
		do {
			let inferenceActionJSON: Data = try Data(contentsOf: URL.inferenceActionsFile)
			let actions: [InferenceAction] = try ActionsWrapper.decoded(from: inferenceActionJSON).actions
			let items: [Item] = actions.compactMap({ $0.alfredItem })
			Workflow.return(ScriptFilterResponse(items: items))
			
		} catch let DecodingError.dataCorrupted(context) {
			let debugMessage: String = "[Data Corrupted] \(context.debugDescription).\n Coding Path: \(context.codingPath)"
			Workflow.quit(debugMessage)
			
		} catch let DecodingError.keyNotFound(key, context) {
			let debugMessage: String = "[Decoding Failure] Key <\(key.stringValue)> not found. Debug description: \(context.debugDescription). Context coding path: \(context.codingPath)"
			Workflow.quit(debugMessage)
			
		} catch {
			Workflow.quit(error.localizedDescription)
		}
	}
	
	static func generateStreaming() {
		do {
			guard let actionId: String = Environment.inferenceActionIdentifier else {
				Workflow.quit("Cannot find identifier for inference task.")
			}
			guard let payload: String = Environment.inferenceActionPayload else {
				Workflow.quit("No user input.")
			}
			let inferenceActionJSON: Data = try Data(contentsOf: URL.inferenceActionsFile)
			let actions: [InferenceAction] = try ActionsWrapper.decoded(from: inferenceActionJSON).actions
			guard let action: InferenceAction = actions.first(where: { $0.identifier == actionId }) else {
				Workflow.quit("Cannot find action with identifier '\(actionId)'.")
			}
			
			let request: ChatRequest = action.chatRequest(payload: payload, stream: true)
			
			// TODO: Handle `InferenceTaskCompletion`
			
			// TODO: Validate that the frontmost app's selected UIElement is a text field.
			// Only then the result should be streamed via AX keystroke simulations.
			
			Task {
				do {
					AX.deselect()
					let router = Router(endpoint: .generate)
					do {
						//outputStream.open()
						// ===---------------------------------------------------------------------------------------------------=== //
						//var signalStop: Bool = true
						let asyncStream: AsyncThrowingStream<ChatResponse, any Error> = try await router.generateStream(request: request)
						// ===---------------------------------------------------------------------------------------------------=== //
						
						for try await response: ChatResponse in asyncStream {
							if let content: String = response.response, !content.isEmpty {
								AX.stream(chunk: content)
							}
							if response.done {
								//try outputStream.write(Environment.stopToken)
								//signalStop = false
								break
							}
						}
						//if signalStop {
						//	/// Just-in-case failsafe
						//	//try outputStream.write(Environment.stopToken)
						//}
						AX.finish()
						Workflow.exit(.success)
					} catch {
						throw error
					}
					
					
//					// TODO: HUD notification?
//					if action.paste {
//						if action.preserveSelection {
//							Workflow.write("\(payload)\n\n\(result)")
//						} else {
//							Workflow.write(result)
//						}
//					} else {
//						Workflow.exit(.success)
//					}
				} catch let DecodingError.keyNotFound(key, context) {
					let debugMessage: String = "\n\nKey '\(key.stringValue)' not found: \(context.debugDescription). CodingPath: \(context.codingPath)"
					Workflow.log(.debug, "\(debugMessage)")
					Workflow.exit(.failure)
					
				} catch let DecodingError.dataCorrupted(context) {
					let debugMessage: String = "\n\n__[Decoding Error > Data Corrupted]__ \(context.debugDescription).  \n> __Coding Path:__ \(context.codingPath)."
					Workflow.log(.debug, "\(debugMessage)")
					Workflow.exit(.failure)
				} catch {
					// TODO: Extra error handling
					Workflow.log(.debug, "[Generate] Error Description: \(error.localizedDescription)")
					Workflow.exit(.failure)
				}
			}
			RunLoop.current.run()
			
			
		} catch {
			Workflow.log(.error, error.localizedDescription)
			Workflow.exit(.failure)
		}
		
	}
	
}
