//
//  Router.swift
//  Ollama
//
//  Created by Patrick Sy on 30/05/2024.
//

import Foundation



struct Router {
	let scheme: String = Environment.ollamaScheme
	let host: String = Environment.ollamaHost
	let port: Int = Environment.ollamaPort
	let path: String
	let httpMethod: String = "POST"
	let session: URLSession = .shared
	let decoder: JSONDecoder = .init()
	
	init(endpoint: Endoint = .chat) {
		self.path = endpoint.rawValue
	}
	
	enum Endoint: String {
		case chat = "/api/chat"
		case generate = "/api/generate"
	}
}

extension Router {
	func request(body: ChatRequest) throws -> URLRequest {
		let urlComponents: URLComponents = {
			var components: URLComponents = .init()
			components.scheme = scheme
			components.host = host
			components.port = port
			components.path = path
			return components
		}()
		guard let url: URL = urlComponents.url else {
			throw URLError(.badURL, userInfo: ["Message": "URL request error, attempted: <\(scheme)://\(host):\(port)\(path)>"])
		}
		var request = URLRequest(url: url)
		request.addValue("application/json", forHTTPHeaderField: "Content-Type")
		request.httpBody = try JSONEncoder().encode(body)
		request.httpMethod = httpMethod
		return request
	}
}


extension Router {
	func stream(_ query: ChatRequest) async throws -> AsyncThrowingStream<ChatResponse, Error> {
		let request: URLRequest = try request(body: query)
		let (stream, httpResponse): (URLSession.AsyncBytes, URLResponse)
		do {
			(stream, httpResponse) = try await session.bytes(for: request)
		} catch {
			throw URLError(.cannotLoadFromNetwork, userInfo: ["Message": "[Router>Stream] Network request failed: \(error.localizedDescription)"])
		}
		guard let httpResponse = httpResponse as? HTTPURLResponse else {
			throw URLError(.badServerResponse, userInfo: ["Message": "[Router>Stream] URLRequest failed, unable to evaluate HTTP URL Response."])
		}
		guard httpResponse.statusCode == 200 else {
			throw URLError(.badServerResponse, userInfo: ["Message": "[Router>Stream] \(httpResponse.description)\n\nStatus Code: \(httpResponse.statusCode)"])
		}
		return AsyncThrowingStream { continuation in
			let task = Task {
				do {
					for try await line in stream.lines {
						let decoded = try decoder.decode(ChatResponse.self, from: Data(line.utf8))
						continuation.yield(decoded)
					}
				} catch {
					continuation.finish(throwing: error)
				}
			}
			continuation.onTermination = { @Sendable _ in
				task.cancel()
			}
		}
	}
}

extension Router {
	func generate(request: ChatRequest) async throws -> String {
		let request: URLRequest = try self.request(body: request)
		let (jsonData, httpResponse): (Data, URLResponse)
		do {
			(jsonData, httpResponse) = try await session.data(for: request)
		} catch {
			// TODO: Properly handle the URLError instances
			throw URLError(.cannotLoadFromNetwork, userInfo: ["Message": "[Router>Generate] Network request failed: \(error.localizedDescription)"])
		}
		guard let httpResponse = httpResponse as? HTTPURLResponse else {
			throw URLError(.badServerResponse, userInfo: ["Message": "[Router>Generate] URLRequest failed, unable to evaluate HTTP URL Response."])
		}
		guard httpResponse.statusCode == 200 else {
			throw URLError(.badServerResponse, userInfo: ["Message": "[Router>Generate] \(httpResponse.description)\n\nStatus Code: \(httpResponse.statusCode)"])
		}
		let response: ChatResponse = try JSONDecoder().decode(ChatResponse.self, from: jsonData)
		return response.response ?? "DEBUG: Something went wrong."
		//return response.message?.content ?? "\(response)"
	}
	
	func generateStream(request: ChatRequest) async throws -> AsyncThrowingStream<ChatResponse, Error> {
		let request: URLRequest = try self.request(body: request)
		let (stream, httpResponse): (URLSession.AsyncBytes, URLResponse)
		do {
			(stream, httpResponse) = try await session.bytes(for: request)
		} catch {
			throw URLError(.cannotLoadFromNetwork, userInfo: ["Message": "[Router>Stream] Network request failed: \(error.localizedDescription)"])
		}
		guard let httpResponse = httpResponse as? HTTPURLResponse else {
			throw URLError(.badServerResponse, userInfo: ["Message": "[Router>Stream] URLRequest failed, unable to evaluate HTTP URL Response."])
		}
		guard httpResponse.statusCode == 200 else {
			throw URLError(.badServerResponse, userInfo: ["Message": "[Router>Stream] \(httpResponse.description)\n\nStatus Code: \(httpResponse.statusCode)"])
		}
		return AsyncThrowingStream { continuation in
			let task = Task {
				do {
					for try await line in stream.lines {
						let decoded = try decoder.decode(ChatResponse.self, from: Data(line.utf8))
						continuation.yield(decoded)
					}
				} catch {
					continuation.finish(throwing: error)
				}
			}
			continuation.onTermination = { @Sendable _ in
				task.cancel()
			}
		}
	}
}
