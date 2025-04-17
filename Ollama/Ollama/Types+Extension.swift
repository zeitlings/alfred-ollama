//
//  Types+Extension.swift
//  Ollama
//
//  Created by Patrick Sy on 29/09/2024.
//

import Foundation

extension URL {
	init(file path: String) {
		if #available(macOS 14, *) {
			self = URL(filePath: path)
		} else {
			self = URL(fileURLWithPath: path)
		}
	}
	
	static func / (lhs: URL, rhs: String) -> URL {
		lhs.appendingPathComponent(rhs)
	}
	
	static func + (lhs: URL, rhs: String) -> URL {
		lhs.appendingPathExtension(rhs)
	}
	
}

extension StringProtocol {
	func hasSubstring<T: StringProtocol>(
		_ other: T, options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
	) -> Bool {
		range(of: other, options: options) != nil
	}
	var trimmed: String { self.trimmingCharacters(in: .whitespacesAndNewlines) }
	
	func underlined(unicodeModifier: UnicodeScalar = .init(Int("0331", radix: 16)!)!) -> String {
		guard Environment.underlineModelInfo else { return String(self) }
		return map({
			($0.isWhitespace || $0.isSymbol || $0.isPunctuation ) ? "\($0)" : "\($0)\(unicodeModifier)"
		}).joined()
	}
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
