//
//  Ollama.swift
//  Ollama
//
//  Created by Patrick Sy on 29/09/2024.
//

import Foundation

// MARK: - Ollama
struct Ollama {
	typealias Model = Models.Model
	static let arguments: [String] = CommandLine.arguments

	// FIXME: The Double-Quote Mystery
	static var userInput: String = arguments.indices.contains(1)
		? (arguments[1].applyingTransform(StringTransform("[:Punctuation:] Publishing"), reverse: false) ?? arguments[1])
		: ""

	static let modelFile: URL = URL(file: arguments[2])
	static let isRunning: Bool = Bool(arguments[3])!
	static let installedModelsRaw: String = arguments[4]
	static let ollamaVersion: String = arguments[6]
	static let progressFile: URL = modelFile.deletingLastPathComponent() / "pull_progress" + "txt"
	static let progressInfoFile: URL = modelFile.deletingLastPathComponent() / "pull_info" + "txt"
	static let loadedModelsRaw: ArraySlice<Substring> = arguments[5].split(separator: "\n").dropFirst()

	// MARK: Ollama Run Main
	static func run() async {
		switch Environment.programState {
		case .manage: await manage()
		case .chat: chat()
		case .generate: generateStreaming()
		case .actions: listActions()
		}
		
	}
}

extension Ollama {
	
	static let preferredModel: String? = {
		guard let installedModels: [Model] else {
			return nil
		}
		if let preferred: String = Environment.preferredModel {
			guard installedModels.contains(where: { $0.name == preferred }) else {
				return installedModels.first?.name
			}
			return preferred
		}
		return installedModels.first?.name
	}()
	
	static let loadedModelsInfo: [(name: String, size: String, processor: String, remaining: String)] = loadedModelsRaw.map({ slice in
		let slice: Substring = slice.replacing("    ", with: "\t")
		let components: [String] = slice.components(separatedBy: "\t").map({ $0.trimmed }).filter({ !$0.isEmpty})
		
		let name: String = components[0]
		//let id: String = components[1]
		let size: String = components[2]
		let processor: String = components[3]
		let remaining: String = components[4]
		
		return (name: name, size: size, processor: processor, remaining: remaining)
	})
	
	static let preferredModelIsLoaded: Bool = preferredModel
		.map({ pref in loadedModelsInfo.contains(where: { $0.name == pref }) }) ?? false
	
	
	static let installedModels: [Model]? = {
		let m: [Model] = installedModelsRaw
			.split(separator: "\n")
			.filter({ !$0.hasPrefix("NAME") })
			.map({ line in
				let line: Substring = line.replacing("    ", with: "\t")
				let parts: [String] = String(line).components(separatedBy: "\t").map({ $0.trimmed }).filter({ !$0.isEmpty})
				return Model(name: parts[0], description: nil, tags: nil, id: parts[1], size: parts[2], modified: parts[3])
			})
		return m.isEmpty ? nil : m
	}()
	
	/// Models available through <https://ollama.com/library>.
	static let availableModels: [Model] = {
		
		let modelJSON: String = {
			if #available(macOS 15, *) {
				if let json: String = try? String(contentsOf: modelFile, encoding: .utf8) {
					return json
				}
			} else {
				if let json: String = try? String(contentsOf: modelFile) {
					return json
				}
			}
			Workflow.quit("Unable to retrieve models from JSON file.")
		}()
		
		
		do {
			//let models: [Model] = try JSONDecoder().decode(Models.self, from: Data(modelJSON.utf8)).models
			let models: [Model] = try JSONDecoder().decode([Model].self, from: Data(modelJSON.utf8))
			return models
		} catch let DecodingError.keyNotFound(key, context) {
			let debugMessage: String = "Decoding failure. Key <\(key.stringValue)> not found. Debug description: \(context.debugDescription). Context coding path: \(context.codingPath)"
			Workflow.quit(debugMessage)
		} catch {
			Workflow.quit(error.localizedDescription)
		}
	}()
	
}


// MARK: - Ollama+Manage

extension Ollama {
	private static func manage(fm: FileManager = .default) async {
		var response = ScriptFilterResponse(items: [.with({
			$0.title = "\(isRunning ? "Ollama is running" : "Ollama is sleeping")"
			$0.valid = false
			$0.uid = "Ollama"
			
			if !isRunning {
				$0.icon = .unavailable
				$0.cmd = Modifier(
					subtitle: "Wake Ollama",
					icon: .available,
					variables: .nested(["trigger": .string("start")]),
					valid: true
				)
				$0.variables = .nested(["trigger": .string("start")])
				$0.valid = true
			} else {
				if !(installedModels?.isEmpty ?? true) {
					//$0.subtitle = "⏎ Chat"
					$0.valid = true
					$0.variables = .nested(["trigger": .string("chat.continue")])
				}
				$0.alt = Modifier(
					subtitle: ollamaVersion,
					icon: .info,
					valid: false
				)
				$0.cmd = Modifier(
					subtitle: "Quit Ollama",
					icon: .stop,
					variables: .nested(["trigger": .string("stop")]),
					valid: true
				)
			}
		})])
		
		guard isRunning else {
			Workflow.return(response)
		}
		
		switch DirectiveManage(&userInput) {
		case .entry:
			
			if installedModels != nil {
				response.append(item: .with({
					$0.title = "View local models"
					$0.valid = false
					$0.autocomplete = "/ \(userInput)"
					$0.icon = .dot
					$0.uid = "Ollama local"
				}))
			}
			
			// Display the currently loaded models
			if !loadedModelsRaw.isEmpty {
				response.append(item: .with({
					$0.title = "View loaded models"
					$0.valid = false
					$0.autocomplete = "/// "
					$0.icon = .dot
					$0.uid = "Ollama loaded"
				}))
			}
			
			response.append(item: .with({
				$0.title = "Find new models"
				$0.valid = false
				$0.autocomplete = "// \(userInput)"
				$0.icon = .dot
				$0.uid = "Ollama new"
			}))
			

			// Display the download progress while some model is being pulled
			if fm.fileExists(atPath: progressFile.path(percentEncoded: false)) {
				
				do {
					assert(fm.fileExists(atPath: progressInfoFile.path(percentEncoded: false)))
					
					// TODO: Find a way to overwrite the progress log instead of appending to it
					let line: String = try {
						var lines: [String] = []
						var data: Data = try .init(contentsOf: progressFile)
						data += Data("".utf8) // NSData bridging
						data.withUnsafeBytes { rawPointer in
							for line in rawPointer.split(separator: UInt8(ascii: "\n")) {
								lines.append(String(decoding: UnsafeRawBufferPointer(rebasing: line), as: UTF8.self))
							}
						}
						return lines.last ?? "..."
					}()
					
					let info: String = try String(contentsOf: progressInfoFile).trimmed
					
					var item: Item = .with({
						$0.title = "~ \(info)"
						$0.valid = false
						$0.icon = .download
						$0.uid = "Ollama progress"
						$0.cmd = Modifier(
							subtitle: "Cancel download",
							icon: .remove,
							variables: .nested(["trigger":.string("cancel")]),
							valid: true
						)
					})
					
					switch true {
					case line.hasPrefix("pulling"):
						var trimmed: String = line.prefix(while: { $0 != "[" }).dropFirst(23).trimmed
						
						if let lower: String.Index = trimmed.firstIndex(of: "▕"),
						   let upper: String.Index = trimmed.firstIndex(of: "▏")
						{
							// Make it look more consistent w/ Alfred
							var substring = trimmed[lower..<upper]
							substring.replace(" ", with: "▁")
							trimmed.replaceSubrange(lower..<upper, with: substring)
						}
						item.subtitle = trimmed
						
					case line.hasPrefix("["):
						item.subtitle = "pulling manifest"
					
					default:
						item.subtitle = line
					}
					
					response.append(item: item)
					response.rerun = 0.5
					
				} catch {
					Workflow.quit(error.localizedDescription)
				}
				
			}
			
		case .findModels:
			
			response.items.removeAll()
			let components: [String] = userInput.components(separatedBy: .whitespaces)
			let models: [Model] = availableModels.filter { model in
				userInput.isEmpty || (
					components.allSatisfy { c in
						model.name.hasSubstring(c) ||
						model.description?.hasSubstring(c) ?? false ||
						model.tags?.contains(where: { $0.hasSubstring(c) }) ?? false
					}
				)
			}
			response.append(contentsOf: models.map({ $0.newModelItem }))
			
		case .findModelsTag:
			
			response.items.removeAll()
			let targetModel: String = userInput.dropFirst().prefix(while: { $0 != "/" }).trimmed
			userInput = userInput[userInput.index(userInput.startIndex, offsetBy: targetModel.count + 2)...].trimmed
			var tags: [String] = {
				guard let tags: [String] = Self.availableModels.first(where: { $0.name == targetModel })?.tags else {
					Workflow.quit("Cannot find tags for '\(targetModel)'")
				}
				return tags
			}()
			
			
			if !userInput.isEmpty {
				let components: [String] = userInput.components(separatedBy: .whitespaces)
				tags = tags.filter({ tag in components.allSatisfy({ tag.hasSubstring($0) }) })
			}
			
			let items: [Item] = tags.map({ tag in
				let name: String = "\(targetModel):\(tag)"
				let url: String = "https://ollama.com/library/\(name)"
				let isInstalled: Bool = {
					if let installed: [Model] = Ollama.installedModels {
						return installed.contains(where: { $0.name == name })
					}
					return false
				}()
				
				return .with {
					$0.title = name
					$0.subtitle = isInstalled ? "Installed" : ""
					$0.text = Text(copy: name, largetype: name)
					$0.addVariable(key: "trigger", "open")
					$0.arg = .string(url)
					$0.quicklookurl = url
					$0.icon = isInstalled ? .available : nil
					
					if !isInstalled {
						// TODO: temporary marker while the model is being pulled
						$0.cmd = Modifier(
							arg: .string(name),
							subtitle: "Pull from registry",
							icon: .download,
							variables: .nested(["trigger" : .string("pull")]),
							valid: true
						)
					}
				}
			})
			
			response.append(contentsOf: items)
			
		case .listModels:
			
			response.items.removeAll()
			if var installedModels: [Model] {
				if !userInput.isEmpty {
					let queryComponents: [String] = userInput.components(separatedBy: .whitespaces)
					installedModels = installedModels.filter({ model in
						queryComponents.allSatisfy({ model.name.hasSubstring($0) })
					})
				}
				response.append(contentsOf: installedModels.map({ $0.installedModelItem }))
			}
			
		case .showInfo:
			
			response.items.removeAll()
			do {
				let input: [String] = userInput.components(separatedBy: "/")
				guard input.count == 2 else {
					throw NSError(domain: "Invalid command structure", code: 0, userInfo: nil)
				}
				let model: String = input[0]
				let query: [String] = input[1].trimmed.isEmpty ? []
					: input[1].components(separatedBy: .whitespaces).filter({ !$0.isEmpty })
				
				let info: [Item] = try await ModelConfiguration.fetch(for: model).alfredItems
					.filter({ item in
						query.isEmpty || (
							query.allSatisfy { c in
								item.title.hasSubstring(c) ||
								item.subtitle.hasSubstring(c)
							}
						)
					})
				
				response.append(contentsOf: info)
				
			} catch {
				Workflow.log(.error, error.localizedDescription)
				response.append(item: .with({
					$0.title = "Something went wrong..."
					//$0.subtitle = error.localizedDescription
					let components: [String] = userInput.components(separatedBy: "/")
					$0.subtitle = "\(error.localizedDescription) | Model: \(components[0])"
					$0.valid = false
					$0.icon = .stop
				}))
			}
			
			
		case .loadedModels:
			
			response.items.removeAll()
			let loaded: [(name: String, size: String, processor: String, remaining: String)] = loadedModelsInfo
			for model in loaded {
				// TODO: Set run forever
				/// Unloading a model is easy to implement. However,
				/// to keep a model alive for longer requires any subsequent request to
				/// include the relevant value for the `keep_alive` parameter (localhost)
				/// See [#2146](https://github.com/ollama/ollama/pull/2146)
				/// __This has been fixed.__
				///
				// TODO: Use new CLI option to unload
				response.append(item: .with({
					$0.title = "\(model.name)"
					$0.subtitle = "\(model.processor) · \(model.size) · Until: \(model.remaining)"
					$0.valid = false
					$0.cmd = Modifier(
						arg: .string(model.name),
						subtitle: "Unload model",
						icon: .info,
						variables: .nested(["trigger":.string("unload")]),
						valid: true
					)
				}))
			}
		}
		
		Workflow.return(response)
	}
	
}



// MARK: - Directive Manage
/// Directive for program state `manage`
enum DirectiveManage {
	case findModelsTag
	case loadedModels
	case findModels
	case listModels
	case showInfo
	case entry
	
	init(_ query: inout String) {
		switch true {
		case query.firstMatch(of: /\/[\w.-]+?\//) != nil:
			self = .findModelsTag
			
		case query.firstMatch(of: /[\w.-]+?\//) != nil:
			self = .showInfo

		case query.hasPrefix("///"):
			query = query.dropFirst(3).trimmed
			self = .loadedModels
			
		case query.hasPrefix("//"):
			query = query.dropFirst(2).trimmed
			self = .findModels
		
		case query.hasPrefix("/"):
			query = query.dropFirst().trimmed
			self = .listModels
			
		default:
			self = .entry
		}
	}
}
