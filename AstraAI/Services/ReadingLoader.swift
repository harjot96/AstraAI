import Foundation
import Observation
import SwiftData

/// Streams a generated reading into the UI and caches the final text in SwiftData,
/// so each (profile, period) pair costs one API call.
@MainActor
@Observable
final class ReadingLoader {
    var text = ""
    var isLoading = false
    var errorMessage: String?

    private var task: Task<Void, Never>?

    /// Streams an AI reading. If every AI provider fails and `fallback` is given,
    /// its text (e.g. a published sun-sign horoscope) is shown instead of an error.
    func load(key: String, system: @escaping () -> String, prompt: String,
              context: ModelContext, force: Bool = false, maxTokens: Int = 1200,
              fallback: (@MainActor () async throws -> String)? = nil) {
        task?.cancel()
        errorMessage = nil

        let descriptor = FetchDescriptor<CachedReading>(predicate: #Predicate { $0.key == key })
        let cached = try? context.fetch(descriptor).first
        if let cached, !force {
            text = cached.text
            isLoading = false
            return
        }

        text = ""
        isLoading = true
        task = Task {
            do {
                let client = AIClient()
                var acc = ""
                for try await chunk in client.stream(system: system(), messages: [.init(role: "user", content: prompt)],
                                                     maxTokens: maxTokens) {
                    acc += chunk
                    text = acc
                }
                if !acc.isEmpty {
                    if let cached { context.delete(cached) }
                    context.insert(CachedReading(key: key, text: acc))
                    try? context.save()
                }
            } catch is CancellationError {
                // A newer request replaced this one.
            } catch {
                if text.isEmpty, let fallback, let backup = try? await fallback() {
                    text = backup // not cached, so the AI reading is retried next time
                } else {
                    errorMessage = error.localizedDescription
                }
            }
            isLoading = false
        }
    }

    /// Loads non-AI text (e.g. a published horoscope feed), cached under `key`.
    func loadText(key: String, context: ModelContext, force: Bool = false,
                  fetch: @escaping @MainActor () async throws -> String) {
        task?.cancel()
        errorMessage = nil
        let descriptor = FetchDescriptor<CachedReading>(predicate: #Predicate { $0.key == key })
        let cached = try? context.fetch(descriptor).first
        if let cached, !force { text = cached.text; isLoading = false; return }
        text = ""
        isLoading = true
        task = Task {
            do {
                let result = try await fetch()
                text = result
                if let cached { context.delete(cached) }
                context.insert(CachedReading(key: key, text: result))
                try? context.save()
            } catch is CancellationError {
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
