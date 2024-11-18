//
//  ScriptFilter+Argument+Icon+Text.swift
//  Ollama
//
//  Created by Patrick Sy on 29/09/2024.
//

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
	
	// MARK: Icon Constants
	static let failure: Icon = "icons/failure.png"
	static let success: Icon = "icons/success.png"
	static let info: Icon = "icons/info.png"
	static let available: Icon = "icons/available.png"
	static let unavailable: Icon = "icons/unavailable.png"
	static let stop: Icon = "icons/stop.png"
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
