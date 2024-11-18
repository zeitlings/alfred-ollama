#!/usr/bin/swift
//
//  Archive.swift
//  GPT Nexus
//
//  Created by Patrick Sy on 04/05/2024.
//

import Foundation

protocol Inflatable {
	init()
}

extension Inflatable {
	static func with(_ populator: (inout Self) throws -> ()) rethrows -> Self {
		var item = Self()
		try populator(&item)
		return item
	}
}

// MARK: - Item

struct Item: Codable, Inflatable {
	var arg: String?
	var uid: String?
	var type: String?
	var title: String
	var subtitle: String
	var quicklookurl: String?
	var icon: [String:String]?
	var text: [String:String]?
	var valid: Bool?
	var alt: Modifier?
	
	init() {
		self.arg = nil
		self.uid = nil
		self.icon = ["path":"icons/archive.chat.png"]
		self.valid = true
		self.title = ""
		self.subtitle = ""
		self.quicklookurl = nil
		self.type = nil
		self.alt = nil
		self.text = nil
	}
	
	private enum CodingKeys: String, CodingKey {
		case uid, title, subtitle, arg, icon,
			 valid, autocomplete, type, mods,
			 quicklookurl, text
	}
	
	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(subtitle, forKey: .subtitle)
		try container.encode(title, forKey: .title)
		try container.encode(valid, forKey: .valid)
		if let uid = uid { try container.encode(uid, forKey: .uid) }
		if let arg = arg { try container.encode(arg, forKey: .arg) }
		if let icon = icon { try container.encode(icon, forKey: .icon) }
		if let text = text { try container.encode(text, forKey: .text) }
		if let type = type { try container.encode(type, forKey: .type) }
		if let quicklookurl = quicklookurl { try container.encode(quicklookurl, forKey: .quicklookurl) }
		if ![alt].allSatisfy({ $0 == nil }) {
			let wrapper = Mods(alt: alt)
			try container.encode(wrapper, forKey: .mods)
		}
	}
	
	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		subtitle = try container.decode(String.self, forKey: .subtitle)
		valid = try container.decode(Bool.self, forKey: .valid)
		title = try container.decode(String.self, forKey: .title)
		text = try container.decodeIfPresent([String:String].self, forKey: .text)
		type = try container.decodeIfPresent(String.self, forKey: .type)
		uid = try container.decodeIfPresent(String.self, forKey: .uid)
		arg = try container.decodeIfPresent(String.self, forKey: .arg)
		icon = try container.decodeIfPresent([String:String].self, forKey: .icon)
		quicklookurl = try container.decodeIfPresent(String.self, forKey: .quicklookurl)
		let wrapper: Mods? = try container.decodeIfPresent(Mods.self, forKey: .mods)
		alt = wrapper?.alt ?? nil
	}
}

// MARK: - Response

struct Response: Codable {
	var items: [Item]
	
	/// Return the Script Filter Response as json string
	var encoded: String {
		let encoder: JSONEncoder = .init()
		let response: Response = {
			guard !items.isEmpty else {
				return Response(items: [.with({
					$0.title = "No results."
					$0.valid = false
					$0.icon = ["path":"icons/info.png"]
				})])
			}
			return self
		}()
		let json: Data = try! encoder.encode(response)
		return String(data: json, encoding: .utf8)!
	}
}

// MARK: - Mods wrapper

struct Mods: Codable {
	let alt: Modifier?
	init(alt: Modifier?) {
		self.alt = alt
	}
}

// MARK: - Modifier

struct Modifier: Codable {
	var subtitle: String?
	var arg: String?
	var icon: [String:String]?
	var variables: [String:String]?
	var valid: Bool
	
	init(
		arg: String = "",
		subtitle: String? = nil,
		icon: [String:String] = ["path":"icons/info.png"],
		variables: [String:String]? = nil,
		valid: Bool = false
	) {
		self.subtitle = subtitle
		self.valid = valid
		self.icon = icon
		self.arg = arg
		self.variables = variables
	}
}

struct Message: Codable {
	let role: String
	let content: String
	let service: String?
}


extension String {
	@inline(__always)
	func hasSubstring(
		_ other: String,
		options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
	) -> Bool {
		range(of: other, options: options) != nil
	}
	var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines )}
}


// MARK: - Main

let fm: FileManager = .default
let arguments: [String] = CommandLine.arguments
let query: String? = {
	guard arguments.indices.contains(1) else {
		return nil
	}
	let userInput: String = arguments[1].trimmed
	return userInput.isEmpty ? nil : userInput
	
}()
let env: [String:String] = ProcessInfo.processInfo.environment
let archive: URL = URL(fileURLWithPath: "\(env["alfred_workflow_data"]!)/archive")


/// Get a view of the matching segment of the string to preview as subtitle
func previewSlice(
	line: String,
	query: String,
	underlineModifier: UnicodeScalar = .init(Int("0331", radix: 16)!)!
) -> String {
	
	// TODO: If lower == startIndex, extend the range to make the subtitles more uniform in width.
	
	var line: String = line.replacing("\n", with: " ")
	let range: Range<String.Index> = line.range(of: query, options: [.caseInsensitive, .diacriticInsensitive])!
	let underlinedMatch: String = line[range].map({ $0.isWhitespace ? "\($0)" : "\($0)\(underlineModifier)" }).joined()
	line.replaceSubrange(range, with: underlinedMatch)
	let lower: String.Index = line.index(range.lowerBound, offsetBy: -40, limitedBy: line.startIndex) ?? line.startIndex
	let upper: String.Index = line.index(range.upperBound, offsetBy: 50, limitedBy: line.endIndex) ?? line.endIndex
	let isLowerStartIndex: Bool = lower == line.startIndex
	let isUpperEndIndex: Bool = upper == line.endIndex
	let previewSlice: String = "\(isLowerStartIndex ? "" : "...")\(line[lower..<upper])\(isUpperEndIndex ? "" : "...")"
	return previewSlice
}



func run() {
	
	guard fm.fileExists(atPath: archive.path(percentEncoded: false)) else {

		let item: Item = .with {
			$0.title = "No previous chats archived!"
			$0.subtitle = "The chat history grows as you start new conversations."
			$0.icon = ["path":"icons/info.png"]
			$0.valid = false
		}
		print(Response(items: [item]).encoded, terminator: "")
		return
	}
	
	var files: [URL] = try! fm.contentsOfDirectory(
		at: archive,
		includingPropertiesForKeys: [.contentModificationDateKey, .creationDateKey],
		options: .skipsHiddenFiles)
	
	files.sort(by: { a, b in
		let aRV: URLResourceValues = try! a.resourceValues(forKeys: [.contentModificationDateKey])
		let bRV: URLResourceValues = try! b.resourceValues(forKeys: [.contentModificationDateKey])
		return aRV.contentModificationDate! > bRV.contentModificationDate!
	})
	
	let chats: [(Data, URL)] = files.compactMap({ url in
		do {
			var raw: Data = try Data(contentsOf: url)
			raw += Data("".utf8)
			return (raw, url)
		} catch {
			// TODO: Remove invalid files or fix them.
			return nil
		}
	})
	
	let decoder: JSONDecoder = .init()
	let allMessages: [([Message], URL)] = chats.map({ chat, url in
		(try! decoder.decode([Message].self, from: chat), url)
	})
	
	var response: Response = .init(items: [])
	for (messages, url) in allMessages { // , url) in zip
		guard let first: String = messages.first(where: { $0.role == "user" })?.content else {
			// remove empty chat file
			try! fm.removeItem(at: url)
			continue
		}
		
		var item: Item = .with({
			$0.title = first.trimmed
			$0.arg = url.path(percentEncoded: false)
			$0.quicklookurl = url.path(percentEncoded: false)
			$0.type = "file"
			$0.text = ["largetype":"First question\n==============================\n\(first.trimmed)"]
			
			if let resourceValues: URLResourceValues = try? url.resourceValues(forKeys: [
				.contentModificationDateKey,
				.creationDateKey
			]),
				// FIXME: The dates are always identical!?
				// The creation date won't be maintained, because the chat is basically overwritten every time.
				// Requires a more complex chat-wrapper for the messages or timestamps on each message.
			   //let creationDate: Date = resourceValues.creationDate,
			   let modificationDate: Date = resourceValues.contentModificationDate
			{
				let dates: String = "Modified: \(modificationDate.formatted())"
				$0.alt = Modifier(subtitle: dates)
				$0.text = ["largetype":"\(dates)\n\n\($0.text!["largetype"]!)"] // Just the modification date for now.
			}
		})
		
		if let query: String {
			
			// Prioritize the answers of the LLM
			guard let firstMatch: String = messages.dropFirst()
				.lazy
				.filter({ $0.role == "assistant" })
				.first(where: { $0.content.hasSubstring(query) })?
				//.first(where: { $0.content.hasSubstring(query) || $0.service.map({ s in s.hasSubstring(query) }) ?? false })?
				.content
			else {
				
				if 
					let firstUserMatch: String = messages.dropFirst()
						.lazy
						.filter({ $0.role == "user" })
						.first(where: { $0.content.hasSubstring(query) })?
						//.first(where: { $0.content.hasSubstring(query) || $0.service.map({ s in s.hasSubstring(query) }) ?? false })?
						.content
				{
					let preview: String = previewSlice(line: firstUserMatch, query: query)
					item.subtitle = preview
					item.text!["largetype"]?.append("\n\nMatching subsequent question slice\n==============================\n\(item.subtitle)")
					
					response.items.append(item)
					
				}

				// assert(is the previous message with role == "user")
				// If the first message contains the searched query, 
				// but nothing else, preserve it anyway.
				// Return the last occurrence of a user message.
				// TODO: skip if last == first? (drop first again)
				else if messages[0].content.hasSubstring(query),
				   let last: String = messages.last(where: { $0.role == "user" })?.content
				{
					
					// TODO: Underline here, too? I.e. in the title...
					
					item.subtitle = last.trimmed
					item.text!["largetype"]?.append("\n\nLast user question\n==============================\n\(item.subtitle)")

					response.items.append(item)
				}
				continue
			}
			
			
			let preview: String = previewSlice(line: firstMatch, query: query)
			item.subtitle = preview

			item.text!["largetype"]?.append("\n\nMatching answer slice\n==============================\n\(item.subtitle)")
			
		}  else {
			if let lastUserMessage: String = messages.last(where: { $0.role == "user" })?.content {
				item.subtitle = lastUserMessage
				item.text!["largetype"]?.append("\n\nLast question\n==============================\n\(item.subtitle)")
			}
		}

		response.items.append(item)
	}
	
	print(response.encoded, terminator: "")
	
}

run()

