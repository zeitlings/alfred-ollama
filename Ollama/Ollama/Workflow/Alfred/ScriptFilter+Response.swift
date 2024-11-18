//
//  ScriptFilter+Response.swift
//  Ollama
//
//  Created by Patrick Sy on 29/09/2024.
//

import Foundation

struct ScriptFilterResponse: Codable {
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

extension ScriptFilterResponse {
	
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


extension ScriptFilterResponse {
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
