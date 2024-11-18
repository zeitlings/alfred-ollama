//
//  Accessibility.swift
//  Ollama
//
//  Created by Patrick Sy on 12/06/2024.
//

import AppKit

struct AX {
	let pid: pid_t
	static let shared: AX = {
		guard let frontMostPID: pid_t = NSWorkspace.shared.frontmostApplication?.processIdentifier else {
			Workflow.log("Unable to get PID of frontmost application", .error)
			Workflow.exit(.failure)
		}
		return .init(pid: frontMostPID)
	}()
}

// MARK: - Strat: Simulate Keystrokes
extension AX {
	
	private static func simulateKeystroke(_ character: String, count: Int = 1) {
		
		guard let source = CGEventSource(stateID: .hidSystemState) else {
			return
		}
		let utf16Chars: [UniChar] = .init(character.utf16)
		let strLength: Int = utf16Chars.count
		for _ in (0..<count) {
			let keyDown: CGEvent? = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
			let keyUp: CGEvent? = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
			keyDown?.keyboardSetUnicodeString(stringLength: strLength, unicodeString: utf16Chars)
			keyUp?.keyboardSetUnicodeString(stringLength: strLength, unicodeString: utf16Chars)
			keyDown?.postToPid(AX.shared.pid)
			keyUp?.postToPid(AX.shared.pid)
			usleep(5000) // 5ms
		}
	}
	
	
	/// <https://eastmanreference.com/complete-list-of-applescript-key-codes>
	enum KeyCode: CGKeyCode {
		case arrowRight = 124
		case escape = 53
	}
	
	private static func simulateKeystroke(keyCode: KeyCode, modifiers: CGEventFlags = []) {
		guard let source = CGEventSource(stateID: .hidSystemState) else {
			return
		}
		let keyDown: CGEvent? = CGEvent(keyboardEventSource: source, virtualKey: keyCode.rawValue, keyDown: true)
		let keyUp: CGEvent? = CGEvent(keyboardEventSource: source, virtualKey: keyCode.rawValue, keyDown: false)
		keyDown?.flags = modifiers
		keyUp?.flags = modifiers
		keyDown?.postToPid(AX.shared.pid)
		keyUp?.postToPid(AX.shared.pid)
		usleep(5000) // 5ms
	}
	
	static func requestAccessibilityPermissions() -> Bool {
		let options: CFDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
		let granted: Bool = AXIsProcessTrustedWithOptions(options)
		if !granted {
			Workflow.log("Accessibility permissions are not enabled. Prompting for permissions...", .info)
		}
		return granted
	}
	
	static func deselect() {
		simulateKeystroke(keyCode: .arrowRight)
		simulateKeystroke(keyCode: .arrowRight)
		simulateKeystroke("\n", count: 2)
	}
	
	static func finish() {
		simulateKeystroke("\n", count: 2)
	}
	
	static func stream(chunk text: String) {
		for char in text {
			simulateKeystroke(.init(char))
			//usleep(10000) // 10ms
			//usleep(5000) // 5ms
			//usleep(3000) // 3ms
		}
	}
	
}
