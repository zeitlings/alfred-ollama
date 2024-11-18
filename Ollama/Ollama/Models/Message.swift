//
//  Message.swift
//  Ollama
//
//  Created by Patrick Sy on 30/05/2024.
//

import Foundation

struct Message: Codable {
	let role: Role
	var content: String
	var images: [String]?
	
	init(role: Role, content: String, images: [String]? = nil) {
		self.role = role
		self.content = content
		self.images = images
	}
	
	enum Role: String, Codable {
		case system
		case assistant
		case user
	}
}
