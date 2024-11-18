//
//  ScriptFilter+Item.swift
//  Ollama
//
//  Created by Patrick Sy on 29/09/2024.
//

struct Item: Codable, Inflatable {
	var uid: String?
	var title: String
	var subtitle: String
	var autocomplete: String?
	var quicklookurl: String?
	var arg: Argument?
	var match: String?
	var variables: Argument?
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
		match: String? = nil,
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
		self.match = match
		self.icon = icon
		self.text = text
		self.uid = uid
		self.arg = arg
		self.cmd = cmd
		self.alt = alt
	}
	
	init() { self.init(title: "") }
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
		try container.encodeIfPresent(match, forKey: .match)
		
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
