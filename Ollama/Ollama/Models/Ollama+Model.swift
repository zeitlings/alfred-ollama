//
//  Ollama+Model.swift
//  Ollama
//
//  Created by Patrick Sy on 29/09/2024.
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
	}
}

extension Models.Model {
	var installedModelItem: Item {
		return .with {
			let url: String = "https://ollama.com/library/\(name)"
			$0.title = name
			$0.subtitle = "Modified \(modified ?? "n/A") · \(size ?? "n/A")"
			if Environment.preferredModel == name {
				$0.subtitle += " ★"
			}
			$0.text = Text(copy: name, largetype: "\(name)\n\(id ?? "n/A")\n\($0.subtitle)")
			//$0.addVariable(key: "trigger", "open")
			$0.arg = .string(url)
			$0.quicklookurl = url
			$0.autocomplete = "\(name)/ "
			$0.valid = false
			
			$0.cmd = Modifier(
				arg: .string(url),
				subtitle: "Open model page for '\(name)'",
				icon: .info,
				variables: .nested(["trigger":.string("open")]),
				valid: true
			)
			
			$0.cmdShift = Modifier(
				arg: .string(name),
				subtitle: "Remove \(name)",
				icon: .remove,
				variables: .nested(["trigger":.string("remove")]),
				valid: true
			)
			
			$0.alt = Modifier(
				arg: .string(name),
				subtitle: "Set as preferred model ★",
				icon: .info,
				variables: .nested(["trigger":.string("model.set.preference")]),
				valid: true
			)
		}
	}
	
	var newModelItem: Item {
		let url: String = "https://ollama.com/library/\(name)"
		let isInstalled: Bool = {
			if let installed: [Self] = Ollama.installedModels {
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
			$0.autocomplete = "/\(name)/ "
			
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
