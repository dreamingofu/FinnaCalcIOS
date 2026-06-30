//
//  APIClient.swift
//  FinnaCalcIOS
//
//  Thin client for the existing FinnaCalc Next.js API (the same backend the
//  website uses). All feature networking goes through here. The web routes do
//  not yet verify the Authorization header (PLAN.md Phase 0), but we send the
//  Supabase access token as a Bearer when available so it's forward-compatible.
//

import Foundation

enum APIConfig {
    /// Base URL of the FinnaCalc API. The production site is www.finnacalc.com.
    static var baseURL = URL(string: "https://www.finnacalc.com")!
}

enum APIError: LocalizedError {
    /// A normal failure with a server-provided (or synthesized) message.
    case message(String)
    /// The feature's backend isn't configured (HTTP 503 from the route).
    case notConfigured(String)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .message(let m), .notConfigured(let m): return m
        case .decoding: return "Couldn’t read the server’s response."
        }
    }

    /// Build an error from a non-2xx body. Plaid routes return `{ "error": "…" }`;
    /// the budget-advisor/chat routes return plain text.
    static func from(data: Data, status: Int) -> APIError {
        var message = "Request failed (\(status))."
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let err = obj["error"] as? String, !err.isEmpty {
            message = err
        } else if let text = String(data: data, encoding: .utf8),
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            message = text
        }
        return status == 503 ? .notConfigured(message) : .message(message)
    }
}

final class APIClient {
    static let shared = APIClient()

    var baseURL: URL = APIConfig.baseURL
    /// Supplies the current Supabase access token (set at app launch). Optional —
    /// the API works without it today.
    var tokenProvider: (() async -> String?)?

    private let session: URLSession = .shared

    // MARK: Requests

    /// POST a JSON body and decode the JSON response.
    func postJSON<Body: Encodable, Response: Decodable>(_ path: String, body: Body) async throws -> Response {
        let data = try await postData(path, body: body)
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    /// POST a JSON body and return the raw response data (2xx only; throws an
    /// `APIError` with the server message otherwise).
    @discardableResult
    func postData<Body: Encodable>(_ path: String, body: Body) async throws -> Data {
        let request = try await makeRequest(path, body: body)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.message("No response from the server.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.from(data: data, status: http.statusCode)
        }
        return data
    }

    /// POST a JSON body and return (data, statusCode) WITHOUT throwing on a
    /// non-2xx status, so the caller can decode a structured error body (e.g.
    /// /api/efile returns its `{status,message,...}` result with HTTP 501).
    func postAllowingErrorStatus<Body: Encodable>(_ path: String, body: Body) async throws -> (Data, Int) {
        let request = try await makeRequest(path, body: body)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.message("No response from the server.")
        }
        return (data, http.statusCode)
    }

    /// GET a path with query items and decode the JSON response.
    func getJSON<Response: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> Response {
        let data = try await getData(path, query: query)
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    @discardableResult
    func getData(_ path: String, query: [String: String] = [:]) async throws -> Data {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if !query.isEmpty {
            components?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components?.url else { throw APIError.message("Invalid request URL.") }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let token = await tokenProvider?() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.message("No response from the server.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.from(data: data, status: http.statusCode)
        }
        return data
    }

    /// POST a JSON body and stream the plain-text response. Each yielded value is
    /// the cumulative text received so far (matching the web's `acc` pattern), so
    /// a consumer just assigns it to the message being rendered.
    func postTextStream<Body: Encodable>(_ path: String, body: Body) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try await makeRequest(path, body: body)
                    let (bytes, response) = try await session.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw APIError.message("No response from the server.")
                    }
                    guard (200..<300).contains(http.statusCode) else {
                        var data = Data()
                        for try await byte in bytes { data.append(byte) }
                        throw APIError.from(data: data, status: http.statusCode)
                    }
                    var data = Data()
                    for try await byte in bytes {
                        data.append(byte)
                        // Only emit on a valid UTF-8 boundary so multibyte
                        // characters never render half-decoded.
                        if let text = String(data: data, encoding: .utf8) {
                            continuation.yield(text)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: Helpers

    private func makeRequest<Body: Encodable>(_ path: String, body: Body) async throws -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = await tokenProvider?() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }
}
