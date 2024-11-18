//
//  Protocols.swift
//  Ollama
//
//  Created by Patrick Sy on 29/09/2024.
//

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
