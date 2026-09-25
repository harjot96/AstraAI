import Foundation

/// Streaming client for the AstraAI proxy, which forwards to the Anthropic Messages
/// API with Claude Haiku 4.5 and returns the same SSE event format (raw HTTP + SSE:
/// there is no official Swift SDK). The app never holds an Anthropic key.
struct ClaudeClient: Sendable {
    static let model = "claude-haiku-4-5"

    struct Message: Encodable, Sendable {
        let role: String
        let content: String
    }

    enum ClientError: LocalizedError {
        case http(Int, String)
        case refused
        case badResponse

        var errorDescription: String? {
            switch self {
            case .http(429, let msg): msg
            case .http(_, let msg): msg
            case .refused: "Astra can't help with that request."
            case .badResponse: "Unexpected response from the server."
            }
        }
    }

    var baseURL: URL = AppConfig.baseURL

    /// Streams text deltas for a single turn.
    func stream(system: String, messages: [Message], maxTokens: Int = 1200) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await run(system: system, messages: messages, maxTokens: maxTokens) { continuation.yield($0) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Convenience: returns the full text of a single turn.
    func complete(system: String, prompt: String, maxTokens: Int = 1200) async throws -> String {
        var text = ""
        for try await chunk in stream(system: system, messages: [.init(role: "user", content: prompt)],
                                      maxTokens: maxTokens) {
            text += chunk
        }
        return text
    }

    private func run(system: String, messages: [Message], maxTokens: Int,
                     onText: @Sendable (String) -> Void) async throws {
        var request = URLRequest(url: baseURL.appending(path: "v1/messages"))
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(AppConfig.deviceID, forHTTPHeaderField: "x-device-id")
        if let token = AppConfig.appToken { request.setValue(token, forHTTPHeaderField: "x-astra-token") }
        if let subscriber = AppConfig.subscriberID { request.setValue(subscriber, forHTTPHeaderField: "x-rc-app-user-id") }

        // The system prompt carries the (stable) chart context, so mark it cacheable.
        let body: [String: Any] = [
            "model": Self.model,
            "max_tokens": maxTokens,
            "stream": true,
            "system": [["type": "text", "text": system, "cache_control": ["type": "ephemeral"]]],
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let bytes: URLSession.AsyncBytes, response: URLResponse
        do {
            (bytes, response) = try await URLSession.shared.bytes(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            #if DEBUG
            throw ClientError.http(0, "Can't reach the AstraAI server at \(baseURL.absoluteString). Start it with `npm start` in the server folder.")
            #else
            throw ClientError.http(0, "Can't reach the stars — check your internet connection.")
            #endif
        }
        guard let http = response as? HTTPURLResponse else { throw ClientError.badResponse }
        guard http.statusCode == 200 else {
            var raw = ""
            for try await line in bytes.lines { raw += line }
            throw ClientError.http(http.statusCode, Self.errorMessage(from: raw))
        }

        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            guard let data = payload.data(using: .utf8),
                  let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = event["type"] as? String else { continue }
            switch type {
            case "content_block_delta":
                if let delta = event["delta"] as? [String: Any],
                   delta["type"] as? String == "text_delta",
                   let text = delta["text"] as? String {
                    onText(text)
                }
            case "message_delta":
                if let delta = event["delta"] as? [String: Any], delta["stop_reason"] as? String == "refusal" {
                    throw ClientError.refused
                }
            case "error":
                let err = event["error"] as? [String: Any]
                throw ClientError.http(0, err?["message"] as? String ?? "The reading was interrupted. Please try again.")
            case "message_stop":
                return
            default:
                continue
            }
        }
    }

    private static func errorMessage(from raw: String) -> String {
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let err = json["error"] as? [String: Any],
              let message = err["message"] as? String else { return raw.isEmpty ? "request failed" : raw }
        return message
    }
}
