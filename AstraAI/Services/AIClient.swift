import Foundation

typealias AIMessage = ClaudeClient.Message

/// Single entry point for AI text.
/// - Premium (Pro, or everyone while the app is free): Claude proxy first, then the free
///   Pollinations.ai API as a fallback.
/// - Free tier when the paywall is on: Pollinations only, so free users cost nothing to serve.
struct AIClient: Sendable {
    /// Kept in sync with the user's entitlement by `ProStore`.
    @MainActor static var premiumByDefault = true

    var premium: Bool

    @MainActor init() { premium = AIClient.premiumByDefault }

    func stream(system: String, messages: [AIMessage], maxTokens: Int = 1200) -> AsyncThrowingStream<String, Error> {
        guard premium else { return FreeAIClient().stream(system: system, messages: messages) }
        return AsyncThrowingStream { continuation in
            let task = Task {
                var yielded = false
                do {
                    for try await chunk in ClaudeClient().stream(system: system, messages: messages, maxTokens: maxTokens) {
                        yielded = true
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                    return
                } catch is CancellationError {
                    continuation.finish(throwing: CancellationError())
                    return
                } catch {
                    // Only fall back if nothing was shown yet; a half-streamed answer is kept as is.
                    if yielded { continuation.finish(throwing: error); return }
                }
                do {
                    for try await chunk in FreeAIClient().stream(system: system, messages: messages) {
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

/// Pollinations.ai text API (https://text.pollinations.ai/openai): free, no key.
/// Streams OpenAI-style SSE chunks; reasoning deltas are skipped, only `content` is shown.
struct FreeAIClient: Sendable {
    static let endpoint = URL(string: "https://text.pollinations.ai/openai")!

    func stream(system: String, messages: [AIMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await run(system: system, messages: messages) { continuation.yield($0) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func run(system: String, messages: [AIMessage], onText: @Sendable (String) -> Void) async throws {
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        let body: [String: Any] = [
            "model": "openai",
            "stream": true,
            "referrer": "astraai-ios",
            "private": true,
            "messages": [["role": "system", "content": system]]
                + messages.map { ["role": $0.role, "content": $0.content] },
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let bytes: URLSession.AsyncBytes, response: URLResponse
        do {
            (bytes, response) = try await URLSession.shared.bytes(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw ClaudeClient.ClientError.http(0, "Can't reach the stars — check your internet connection.")
        }
        guard let http = response as? HTTPURLResponse else { throw ClaudeClient.ClientError.badResponse }
        guard http.statusCode == 200 else {
            let message = http.statusCode == 429
                ? "The free astrologer is busy right now. Please try again in a minute."
                : "The stars are cloudy right now (\(http.statusCode)). Please try again."
            throw ClaudeClient.ClientError.http(http.statusCode, message)
        }

        var gotText = false
        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if payload == "[DONE]" { break }
            guard let data = payload.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any] else { continue }
            if let text = delta["content"] as? String, !text.isEmpty {
                gotText = true
                onText(text)
            }
        }
        if !gotText { throw ClaudeClient.ClientError.http(0, "The stars were silent. Please try again.") }
    }
}
