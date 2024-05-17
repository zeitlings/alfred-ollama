#!/usr/bin/swift
//
//  Ollama.swift
//
//  Created by Patrick Sy on 14/05/2024.
//  <https://github.com/zeitlings/alfred-ollama>
//

import Foundation

struct Models: Codable {
	let models: [Model]
	
	struct Model: Codable {
		let name: String
		let description: String?
		let tags: [String]?
		/// Overload to include installed models
		let id: String?
		let size: String?
		let modified: String?
		
		var installedModelItem: Item {
			return .with {
				let url: String = "https://ollama.com/library/\(name)"
				$0.title = name
				$0.subtitle = "Modified \(modified ?? "n/A") · \(size ?? "n/A")"
				$0.text = Text(copy: name, largetype: "\(name)\n\(id ?? "n/A")\n\($0.subtitle)")
				$0.addVariable(key: "trigger", "open")
				$0.arg = .string(url)
				$0.quicklookurl = url
				
				$0.cmd = Modifier(
					arg: .string(name),
					subtitle: "Remove \(name)",
					icon: .remove,
					variables: .nested(["trigger":.string("remove")]),
					valid: true
				)
			}
		}
		
		var newModelItem: Item {
			
			let url: String = "https://ollama.com/library/\(name)"
			let isInstalled: Bool = {
				if let installed: [Model] = Ollama.installedModels {
					return installed.contains(where: { $0.name.prefix(while: { $0 != ":" }) == name }) // ~
				}
				return false
			}()
			
			return .with {
				$0.title = name
				$0.subtitle = isInstalled ? "Installed | \(description ?? "n/A")" : "\(description ?? "n/A")"
				$0.text = Text(copy: name, largetype: "\(name)\n\n\($0.subtitle)")
				$0.addVariable(key: "trigger", "open")
				$0.arg = .string(url)
				$0.quicklookurl = url
				$0.icon = isInstalled ? .available : nil
				
				if !isInstalled {
					$0.cmd = Modifier(
						arg: .string(name),
						subtitle: "Pull \(name):latest from registry",
						icon: .download,
						variables: .nested(["trigger" : .string("pull")]),
						valid: true
					)
				}
				
				if tags != nil {
					$0.alt = Modifier(
						arg: .string("/\(name)/ "),
						subtitle: "Inspect available versions of '\(name)'",
						icon: .info,
						variables: .nested(["trigger": .string("init")]),
						valid: true
					)
				}
			}
		}
	}
}

enum Directive {
	case findModelsTag
	case loadedModels
	case findModels
	case listModels
	case entry
	
	init(_ query: inout String) {
		switch true {
		case query.firstMatch(of: /\/[\w-]+?\//) != nil:
			self = .findModelsTag

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

struct Ollama {
	typealias Model = Models.Model
	static let arguments: [String] = CommandLine.arguments
	static var userInput: String = arguments[1]
	static let modelFile: URL = URL(path: arguments[2])
	static let isRunning: Bool = Bool(arguments[3])!
	static let installedModelsRaw: String = arguments[4]
	static let loadedModelsRaw: ArraySlice<Substring> = arguments[5].split(separator:  "\n").dropFirst()
	
	
	static let progressFile: URL = modelFile.deletingLastPathComponent()
		.appending(component: "pull_progress")
		.appendingPathExtension("txt")
	
	static let progressInfoFile: URL = modelFile.deletingLastPathComponent()
		.appending(component: "pull_info")
		.appendingPathExtension("txt")
	
	static let fm: FileManager = .default

	static let installedModels: [Model]? = {
		let m: [Model] = installedModelsRaw
			.split(separator: "\n")
			.filter({ !$0.hasPrefix("NAME") })
			.map({ line in
				let parts: [String] = String(line).components(separatedBy: "\t")
				return Model(name: parts[0].trimmed, description: nil, tags: nil, id: parts[1], size: parts[2], modified: parts[3])
			})
		return m.isEmpty ? nil : m
	}()
	
	
	static func run() {
		
		var response = Response(items: [.with({
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
		
		switch Directive(&userInput) {
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
			

			// Display the download progress if a model is being pulled
			if fm.fileExists(atPath: progressFile.path(percentEncoded: false)) {
				
				do {
					assert(fm.fileExists(atPath: progressInfoFile.path(percentEncoded: false)))
					
					// TODO: Find a way to overwrite the progress log instead of appending
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
			
			
		case .loadedModels:
			
			response.items.removeAll()
			let loaded: [(name: String, size: String, processor: String, remaining: String)] = loadedModelsRaw.map({ slice in
				let components = slice.components(separatedBy: "\t")
				let name: String = components[0]
				//let id: String = components[1]
				let size: String = components[2]
				let processor: String = components[3]
				let remaining: String = components[4]
				return (name: name, size: size, processor: processor, remaining: remaining)
			})
			
			for model in loaded {
				// TODO: Set run forever
				/// Unloading a model is easy to implement. However,
				/// to keep a model alive for longer requires any subsequent request to
				/// include the relevant value for the `keep_alive` parameter (localhost)
				/// See `#2146`
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

extension Ollama {
	
	static let availableModels: [Model] = {
		guard  let modelJSON: String = try? String(contentsOf: modelFile) else {
			Workflow.quit("Unable to retrieve models from JSON file.")
		}
		do {
			let models: [Model] = try JSONDecoder().decode(Models.self, from: Data(modelJSON.utf8)).models
			return models
		} catch let DecodingError.keyNotFound(key, context) {
			let debug: String = "Decoding failure. Key <\(key.stringValue)> not found. Debug description: \(context.debugDescription)"
			let codingPath: String = "Context coding path: \(context.codingPath)"
			let debugMessage: String = "\(debug) | \(codingPath)"
			Workflow.quit(debugMessage)
		} catch {
			Workflow.quit(error.localizedDescription)
		}
	}()
	
}



Ollama.run()






extension URL {
	init(path: String) {
		if #available(macOS 14, *) {
			self = URL(filePath: path)
		} else {
			self = URL(fileURLWithPath: path)
		}
	}
}


extension StringProtocol {
	func hasSubstring<T: StringProtocol>(
		_ other: T,
		options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
	) -> Bool {
		self.lowercased() == other.lowercased() ? true : range(of: other, options: options) != nil
	}
	var trimmed: String { self.trimmingCharacters(in: .whitespacesAndNewlines) }
}





// MARK: - Sparse Alfred Models

protocol ItemProtocol {
	init()
}

extension ItemProtocol {
	static func with(_ populator: (inout Self) throws -> ()) rethrows -> Self {
		var item = Self()
		try populator(&item)
		return item
	}
}

// MARK: - Response

struct Response: Codable {
	var items: [Item]
	var rerun: Double?
	var variables: [String:String]?
	var skipknowledge: Bool?
	
	init(
		items: [Item] = [],
		rerun: Double? = nil,
		skipknowledge: Bool? = nil,
		variables: [String:String]? = nil
	) {
		self.items = items
		self.rerun = rerun
		self.variables = variables
		self.skipknowledge = skipknowledge
	}
	
}

// MARK: - Item

struct Item: Codable, ItemProtocol {
	var uid: String?
	var title: String
	var subtitle: String
	var autocomplete: String?
	var quicklookurl: String?
	var arg: Argument? // string, array
	var variables: Argument? // `Argument.nested` where all values are `Argument.string`
	var valid: Bool
	var icon: Icon?
	var text: Text?
	var cmd: Modifier?
	var alt: Modifier?

	init(
		title: String,
		icon: Icon? = nil,
		text: Text? = nil,
		uid: String? = nil,
		valid: Bool = true,
		arg: Argument? = nil,
		cmd: Modifier? = nil,
		alt: Modifier? = nil,
		subtitle: String = "",
		variables: Argument? = nil,
		quicklookurl: String? = nil,
		autocomplete: String? = nil
	) {
		self.autocomplete = autocomplete
		self.quicklookurl = quicklookurl
		self.variables = variables
		self.subtitle = subtitle
		self.title = title
		self.valid = valid
		self.icon = icon
		self.text = text
		self.uid = uid
		self.arg = arg
		self.cmd = cmd
		self.alt = alt
	}
	
	init() { self.init(title: "") }
}

// MARK: - Mods

struct Mods: Codable {
	let cmd: Modifier?
	let alt: Modifier?
	init(cmd: Modifier? = nil, alt: Modifier? = nil) {
		self.cmd = cmd
		self.alt = alt
	}
}


// MARK: - Modifier

struct Modifier: Codable, Equatable {
	var variables: Argument?
	var subtitle: String?
	var arg: Argument
	var icon: Icon?
	var valid: Bool
	
	init(
		arg: Argument = .string(""),
		subtitle: String? = nil,
		icon: Icon? = nil,
		variables: Argument? = nil,
		valid: Bool = true
	) {
		self.variables = variables
		self.subtitle = subtitle
		self.valid = valid
		self.icon = icon
		self.arg = arg
	}
}

// MARK: - Argument

enum Argument: Codable, Equatable {
	case string(String)
	case nested([String:Argument])
}


// MARK: - Icon

struct Icon: Codable, Equatable, ExpressibleByStringLiteral {
	enum IconType: String, Codable {
		case fileicon, filetype
	}
	var type: IconType?
	var path: String
	
	init(path: String, type: IconType? = nil) {
		self.path = path
		self.type = type
	}
	
	init(stringLiteral value: String) {
		self = Icon(path: value)
	}
	
	static let failure: Icon = "icons/failure.png"
	static let success: Icon = "icons/success.png"
	static let info: Icon = "icons/info.png"
	static let available: Icon = "icons/available.png"
	static let unavailable: Icon = "icons/unavailable.png"
	static let stop: Icon = "icons/stop.png"
	static let empty: Icon = "icons/empty.png"
	static let download: Icon = "icons/download.png"
	static let remove: Icon = "icons/remove.png"
	static let dot: Icon = "icons/dot.png"
	
}

// MARK: - Text

struct Text: Codable, Equatable {
	var copy: String?
	var largetype: String?
	
	init(copy: String? = nil, largetype: String? = nil) {
		self.copy = copy
		self.largetype = largetype
	}
}

// MARK: - Extensions

extension Item {
	mutating func addVariable(key: String, _ value: String) {
		if case var .nested(variables) = variables {
			variables[key] = .string(value)
			self.variables = .nested(variables)
		} else {
			self.variables = .nested([key: .string(value)])
		}
	}
}

extension Response {
	
	/// Return the Script Filter Response as json string
	func encoded(encoder: JSONEncoder = .init()) throws -> String {
		let json: Data = try encoder.encode(self)
		return String(data: json, encoding: .utf8)!
	}
	
	mutating func append(item: Item) { items.append(item) }
	mutating func append(contentsOf items: [Item]) {
		self.items.append(contentsOf: items)
	}

}


// MARK: - Alfred+Codable

extension Response {
	enum CodingKeys: CodingKey {
		case items, rerun, variables, skipknowledge
	}
	
	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(items, forKey: .items)
		try container.encodeIfPresent(rerun, forKey: .rerun)
		try container.encodeIfPresent(variables, forKey: .variables)
		try container.encodeIfPresent(skipknowledge, forKey: .skipknowledge)
	}
	
	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		variables = try container.decodeIfPresent([String:String].self, forKey: .variables)
		skipknowledge = try container.decodeIfPresent(Bool.self, forKey: .skipknowledge)
		rerun = try container.decodeIfPresent(Double.self, forKey: .rerun)
		items = try container.decode([Item].self, forKey: .items)
	}
}


extension Item {
	private enum CodingKeys: String, CodingKey {
		case uid, title, subtitle, arg, icon,
			 valid, autocomplete, type, mods,
			 quicklookurl, text, action, match,
			 variables
	}
	
	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(subtitle, forKey: .subtitle)
		try container.encode(title, forKey: .title)
		try container.encode(valid, forKey: .valid)
		try container.encodeIfPresent(uid, forKey: .uid)
		try container.encodeIfPresent(arg, forKey: .arg)
		try container.encodeIfPresent(icon, forKey: .icon)
		try container.encodeIfPresent(text, forKey: .text)
		try container.encodeIfPresent(autocomplete, forKey: .autocomplete)
		try container.encodeIfPresent(quicklookurl, forKey: .quicklookurl)
		try container.encodeIfPresent(variables, forKey: .variables)
		
		if ![cmd, alt].allSatisfy({ $0 == nil }) {
			let wrapper = Mods(cmd: cmd, alt: alt)
			try container.encode(wrapper, forKey: .mods)
		}
	}
	
	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		subtitle = try container.decode(String.self, forKey: .subtitle)
		valid = try container.decode(Bool.self, forKey: .valid)
		title = try container.decode(String.self, forKey: .title)
		text = try container.decodeIfPresent(Text.self, forKey: .text)
		uid = try container.decodeIfPresent(String.self, forKey: .uid)
		arg = try container.decodeIfPresent(Argument.self, forKey: .arg)
		icon = try container.decodeIfPresent(Icon.self, forKey: .icon)
		autocomplete = try container.decodeIfPresent(String.self, forKey: .autocomplete)
		quicklookurl = try container.decodeIfPresent(String.self, forKey: .quicklookurl)
		let wrapper: Mods? = try container.decodeIfPresent(Mods.self, forKey: .mods)
		cmd = wrapper?.cmd ?? nil
		alt = wrapper?.alt ?? nil
	}
}


extension Mods {
	enum CodingKeys: String, CodingKey {
		case cmd, alt
	}
	
	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encodeIfPresent(cmd, forKey: .cmd)
		try container.encodeIfPresent(alt, forKey: .alt)
	}
	
}

extension Modifier {
	enum CodingKeys: String, CodingKey {
		case arg, subtitle, valid, variables, icon
	}
	
	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(arg, forKey: .arg)
		try container.encode(subtitle, forKey: .subtitle)
		try container.encode(valid, forKey: .valid)
		try container.encode(icon, forKey: .icon)
		try container.encodeIfPresent(variables, forKey: .variables)
	}
}


extension Argument {
	func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		switch self {
		case .string(let strn): try container.encode(strn)
		case .nested(let nest): try container.encode(nest)
		}
	}
	
	init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		let string = try? container.decode(String.self)
		let nested = try? container.decode([String:Argument].self)
		
		switch (string, nested) {
		case let (.some(value),_): self = .string(value)
		case let (_,.some(value)): self = .nested(value)
		default:
			throw DecodingError.dataCorrupted(
				DecodingError.Context(
					codingPath: container.codingPath,
					debugDescription: "Unable to decode Argument"
				)
			)
		}
	}
}


// MARK: - Workflow

struct Workflow {
	private static let stdOut: FileHandle = .standardOutput
}

extension Workflow {
	enum ExitCode { case success, failure }
	static func exit(_ code: ExitCode) -> Never {
		switch code {
		case .success: Darwin.exit(EXIT_SUCCESS)
		case .failure: Darwin.exit(EXIT_FAILURE)
		}
	}
	
	static func quit(
		_ title: String,
		_ subtitle: String = "",
		icon: Icon = .failure,
		_ code: ExitCode = .failure
	) -> Never {
		let text: String = "\(title). \(subtitle)"
		let output: String = try! Response(items: [.with {
			$0.title = title
			$0.subtitle = subtitle
			$0.arg = .string(title)
			$0.text = Text(copy: text, largetype: text)
			$0.icon = icon
		}]).encoded()
		try! stdOut.write(contentsOf: Data(output.utf8))
		exit(code)
	}
	
	static func info(_ title: String, _ subtitle: String = "") -> Never {
		quit(title, subtitle, icon: .info, .success)
	}
}

extension Workflow {
	
	static func `return`(_ response: Response, nullMessage: String = "No results...") -> Never {
		do {
			
			var response: Response = response
			response.skipknowledge = true
			
			// Default no results message
			// Preserve variables if there are any
			guard !response.items.isEmpty else {
				let nullResponse: Response = .init(items: [Item.with({
					$0.title = nullMessage
					$0.icon = .info
					$0.valid = false
				})], variables: response.variables)
				
				let json: String = try nullResponse.encoded()
				try stdOut.write(contentsOf: Data(json.utf8))
				exit(.success)
			}
			let json: String = try response.encoded()
			try stdOut.write(contentsOf: Data(json.utf8))
			exit(.success)
			
		} catch let error {
			quit("Error @ \(#function)", error.localizedDescription)
		}
	}
	
}
