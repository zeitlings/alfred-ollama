//
//  ScriptFilter+Modifiers.swift
//  Ollama
//
//  Created by Patrick Sy on 29/09/2024.
//

// MARK: - Mods
struct Mods: Codable {
	let cmd: Modifier?
	let alt: Modifier?
	let cmdShift: Modifier?
	init(cmd: Modifier? = nil, alt: Modifier? = nil, cmdShift: Modifier? = nil) {
		self.cmd = cmd
		self.alt = alt
		self.cmdShift = cmdShift
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

extension Mods {
	enum CodingKeys: String, CodingKey {
		case cmd, alt
		case cmdShift = "cmd+shift"
	}
	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encodeIfPresent(cmd, forKey: .cmd)
		try container.encodeIfPresent(alt, forKey: .alt)
		try container.encodeIfPresent(cmdShift, forKey: .cmdShift)
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
