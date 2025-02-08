//
//  Types+Extension.swift
//  Ollama
//
//  Created by Patrick Sy on 29/09/2024.
//

import Foundation

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
		range(of: other, options: options) != nil
	}
	var trimmed: String { self.trimmingCharacters(in: .whitespacesAndNewlines) }
}

// MARK: Chat Markdown Formatting
extension Array where Element == Message {
	var formattedMarkdown: String {
		return reduce(into: "", { partialResult, message in
			switch message.role {
			case .assistant: partialResult += "\(message.content)\n"
			case .user: partialResult += Workflow.formattedUserMessage(message)
			default: ()
			}
		})
	}
}

extension Decodable {
	static func decoded(from data: Data, decoder: JSONDecoder = .init()) throws -> Self {
		try decoder.decode(Self.self, from: data)
	}
}
