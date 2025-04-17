//
//  Ollama+ModelInfo.swift
//  Ollama
//
//  Created by Patrick Sy on 17/04/2025.
//

import Foundation

// MARK: - Data Models

/// Represents a complete model configuration
/// Mirrors `ollama show <model>`
struct ModelConfiguration: Codable, CustomDebugStringConvertible {

	struct Model: Codable {
		let architecture: String
		let parameters: String
		let contextLength: Int
		let embeddingLength: Int
		let quantization: String
	}

	struct License: Codable {
		let name: String
		let notes: String?
	}

	let name: String
	let model: Model
	let capabilities: [String]
	let parameters: [String: String]
	let license: License

	var debugDescription: String {
		var desc = "Model: \(name)\n"
		desc += "Architecture: \(model.architecture)\n"
		desc += "Parameters: \(model.parameters)\n"
		desc += "Context Length: \(model.contextLength)\n"
		desc += "Embedding Length: \(model.embeddingLength)\n"
		desc += "Quantization: \(model.quantization)\n"
		desc += "Capabilities: \(capabilities.joined(separator: ", "))\n"
		desc += "Parameters: \(parameters.map({ k,v in "\n  ~ \(k): \(v)"}).joined())\n"
		desc += "License: \(license.name)"
		if let notes = license.notes, !notes.isEmpty {
			desc += "\n\(notes)"
		}
		return desc
	}

}

// MARK: - Alfred

extension ModelConfiguration {
	/// Creates an array of Alfred items, each showing a specific piece of model information
	var alfredItems: [Item] {
		var items: [Item] = []

		let summary: String = self.debugDescription
		// Model name item
		items.append(.with {
			$0.title = "Model Name: \(name.underlined())"
			$0.autocomplete = "/ "
			$0.text = Text(copy: summary, largetype: summary)
			$0.valid = false
		})

		// Architecture item
		items.append(.with {
			$0.title = "Architecture: \(model.architecture.underlined())"
			$0.autocomplete = "/ "
			$0.valid = false
			$0.icon = .dot
		})

		// Parameters item
		items.append(.with {
			$0.title = "Parameters: \(model.parameters.underlined())"
			$0.autocomplete = "/ "
			$0.valid = false
			$0.icon = .dot
		})

		// Quantization item
		items.append(.with {
			$0.title = "Quantization: \(model.quantization.underlined())"
			$0.autocomplete = "/ "
			$0.valid = false
			$0.icon = .dot
		})
		
		// Context Length item
		items.append(.with {
			$0.title = "Context Length: \(String(model.contextLength).underlined())"
			$0.autocomplete = "/ "
			$0.valid = false
			$0.icon = .dot
		})

		// Embedding Length item
		items.append(.with {
			$0.title = "Embedding Length: \(String(model.embeddingLength).underlined())"
			$0.autocomplete = "/ "
			$0.valid = false
			$0.icon = .dot
		})


		// Capabilities item
		if !capabilities.isEmpty {
			items.append(.with {
				$0.title = "Capabilities: \(capabilities.map({ $0.underlined() }).joined(separator: " · "))"
				$0.autocomplete = "/ "
				$0.valid = false
				if capabilities.contains("vision") {
					$0.icon = .dot // .vision
				} else if capabilities.contains("embedding") {
					$0.icon = .dot // .embedding
				} else {
					$0.icon = .dot
				}
			})
		}

		// Parameters items (if any)
		if !parameters.isEmpty {
			var parametersFormatted: [String] = []
			for (key, value) in parameters.sorted(by: {
				if $0.key == "stop" { return false }
				if $1.key == "stop" { return true }
				return $0.key < $1.key
			}) {
				parametersFormatted.append("\(key): \(value)")
			}
			let paramsDigest: String = parametersFormatted.joined(separator: "\n")
			items.append(.with({
				$0.title = "Parameters"
				$0.subtitle = parametersFormatted.joined(separator: " · ")
				$0.autocomplete = "/ "
				$0.valid = false
				$0.icon = .dot //.params
				$0.text = Text(copy: paramsDigest, largetype: paramsDigest)
			}))
		}

		// License item
		items.append(.with {
			$0.title = "License: \(license.name)"
			$0.autocomplete = "/ "
			$0.valid = false
			$0.icon = .info // .license
			if let notes: String = license.notes?.trimmed, !notes.isEmpty {
				let truncatedNotes = notes.count > 100
					? String(notes.prefix(100)) + "..."
					: notes

				let licenseDigest: String = "License: \(license.name)\n\nNotes: \(truncatedNotes)"
				$0.subtitle = truncatedNotes
				$0.text = Text(copy: licenseDigest, largetype: licenseDigest)
			}
		})

		return items
	}
}


// MARK: - Errors

enum OllamaError: Error, LocalizedError {
	case commandFailed(code: Int32, output: String)
	case invalidOutput
	case parsingFailed(reason: String)

	var errorDescription: String? {
		switch self {
		case .commandFailed(let code, let output):
			return "Command failed with exit code \(code): \(output)"
		case .invalidOutput:
			return "Could not decode command output"
		case .parsingFailed(let reason):
			return "Failed to parse model configuration: \(reason)"
		}
	}
}

// MARK: - Ollama Command

extension ModelConfiguration {

	/// Fetches and parses model configuration from Ollama CLI
	static func fetch(for modelName: String) async throws -> ModelConfiguration {
		let process: Process = .init()
		let pipe: Pipe = .init()

		process.executableURL = URL(file: "/usr/bin/env")
		process.arguments = ["ollama", "show", modelName]
		process.standardOutput = pipe
		process.standardError = pipe

		try process.run()

		let data = pipe.fileHandleForReading.readDataToEndOfFile()
		guard let output = String(data: data, encoding: .utf8) else {
			throw OllamaError.invalidOutput
		}

		process.waitUntilExit()

		if process.terminationStatus != 0 {
			throw OllamaError.commandFailed(code: process.terminationStatus, output: output)
		}

		return try parse(from: output, name: modelName)
	}

	// MARK: - Parser

	/// Parse the command output to extract model configuration
	/// - Parameters:
	///   - output: Raw output from the ollama show command
	///   - name: Name of the model
	/// - Returns: A structured ModelConfiguration object
	static private func parse(from output: String, name: String) throws -> ModelConfiguration {
		var modelInfo: [String: String] = [:]
		var capabilities: [String] = []
		var parameters: [String: String] = [:]
		var licenseLines: [String] = []

		enum Section { case none, model, capabilities, parameters, license }
		var currentSection: Section = .none

		// Process each line of output
		for line in output.components(separatedBy: .newlines) {
			let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
			guard !trimmed.isEmpty else { continue }

			// Detect section headers
			if trimmed == "Model" { currentSection = .model; continue }
			if trimmed == "Capabilities" { currentSection = .capabilities; continue }
			if trimmed == "Parameters" { currentSection = .parameters; continue }
			if trimmed == "License" { currentSection = .license; continue }

			// Process content based on current section
			switch currentSection {
			case .model:
				if let (key, value) = extractKeyValue(from: trimmed) {
					modelInfo[key] = value
				}

			case .capabilities:
				capabilities.append(trimmed)

			case .parameters:
				if let (key, value) = extractKeyValue(from: trimmed) {
					parameters[key] = value
				}

			case .license:
				licenseLines.append(trimmed)

			case .none:
				continue
			}
		}

		// Validate required model fields and convert types
		guard let architecture: String = modelInfo["architecture"] else {
			throw OllamaError.parsingFailed(reason: "Missing architecture")
		}

		guard let paramStr: String = modelInfo["parameters"] else {
			throw OllamaError.parsingFailed(reason: "Missing parameters")
		}

		guard let ctxLengthStr: String = modelInfo["context length"],
			  let contextLength = Int(extractDigits(from: ctxLengthStr)) else {
			throw OllamaError.parsingFailed(reason: "Invalid context length")
		}

		guard let embLengthStr: String = modelInfo["embedding length"],
			  let embeddingLength = Int(extractDigits(from: embLengthStr)) else {
			throw OllamaError.parsingFailed(reason: "Invalid embedding length")
		}

		guard let quantization: String = modelInfo["quantization"] else {
			throw OllamaError.parsingFailed(reason: "Missing quantization")
		}

		// Create the license object
		let license = License(
			name: licenseLines.first ?? "Unknown",
			notes: licenseLines.count > 1 ? licenseLines.dropFirst().joined(separator: "\n") : nil
		)

		// Build and return the configuration
		return ModelConfiguration(
			name: name,
			model: Model(
				architecture: architecture,
				parameters: paramStr,
				contextLength: contextLength,
				embeddingLength: embeddingLength,
				quantization: quantization
			),
			capabilities: capabilities,
			parameters: parameters,
			license: license
		)
	}

}

// MARK: - Helper Functions

extension ModelConfiguration {

	/// Extract key-value pairs from a line of text
	/// - Parameter line: Input line to parse
	/// - Returns: Tuple of key and value if extraction succeeded
	static private func extractKeyValue(from line: String) -> (String, String)? {
		let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
		guard components.count >= 2 else { return nil }

		// Find the split point between key and value
		// The key is usually 1-2 words (like "context length") and the value is the rest
		// This is more reliable than assuming the value is just the last word

		let keyParts: [String]
		let valueParts: [String]

		// Common cases with known key patterns
		let lowered: String = line.lowercased()
		switch true {
		case lowered.hasPrefix("architecture"):
			keyParts = [components[0]]
			valueParts = Array(components.dropFirst(1))
		case lowered.hasPrefix("parameters"):
			keyParts = [components[0]]
			valueParts = Array(components.dropFirst(1))
		case lowered.hasPrefix("context length"):
			keyParts = [components[0], components[1]]
			valueParts = Array(components.dropFirst(2))
		case lowered.hasPrefix("embedding length"):
			keyParts = [components[0], components[1]]
			valueParts = Array(components.dropFirst(2))
		case lowered.hasPrefix("quantization"):
			keyParts = [components[0]]
			valueParts = Array(components.dropFirst(1))
		case lowered.hasPrefix("num_"):
			// Parameters like num_gpu, num_ctx
			keyParts = [components[0]]
			valueParts = Array(components.dropFirst(1))
		case components.count == 2:
			// Simple case: exactly two components
			keyParts = [components[0]]
			valueParts = [components[1]]
		default:
			// Default: assume the last component is the value
			keyParts = Array(components.dropLast(1))
			valueParts = [components.last!]
		}

		let key = keyParts.joined(separator: " ").lowercased()
		let value = valueParts.joined(separator: " ")

		return (key, value)
	}

	/// Extract only digits from a string (for numeric parsing)
	/// - Parameter text: Input text that might contain non-numeric characters
	/// - Returns: String containing only digits
	static private func extractDigits(from text: String) -> String {
		return text.components(separatedBy: .decimalDigits.inverted).joined()
	}

}

// MARK: - Debug

extension ModelConfiguration {

	static func debugPrint(model: String = "gemma3:27b") async {
		do {
			let config = try await ModelConfiguration.fetch(for: model)
			Workflow.log(.debug, config.debugDescription)

			Workflow.log(.debug, "\nSpecific properties:")
			Workflow.log(.debug, "Architecture: \(config.model.architecture)")
			Workflow.log(.debug, "Context length: \(config.model.contextLength)")

			// Check if model supports specific capabilities
			if config.capabilities.contains("vision") {
				Workflow.log(.debug, "This model supports vision!")
			}

			// Get specific parameters
			if let temperature = config.parameters["temperature"] {
				Workflow.log(.debug, "Temperature setting: \(temperature)")
			}
		} catch {
			Workflow.log(.debug, "Error: \(error.localizedDescription)")
		}
	}
}
