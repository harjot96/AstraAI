import AstroCore
import Foundation

/// Free, keyless published daily horoscopes per sun sign.
/// Primary: ohmanda.com. Backup: horoscope-app-api.vercel.app.
enum HoroscopeFeed {
    enum FeedError: LocalizedError {
        case unavailable
        var errorDescription: String? { "Today's horoscope isn't available right now. Pull to refresh." }
    }

    static func daily(for sign: ZodiacSign) async throws -> String {
        if let text = try? await ohmanda(sign), !text.isEmpty { return text }
        if let text = try? await horoscopeAppAPI(sign), !text.isEmpty { return text }
        throw FeedError.unavailable
    }

    private static func ohmanda(_ sign: ZodiacSign) async throws -> String {
        let url = URL(string: "https://ohmanda.com/api/horoscope/\(sign.name.lowercased())/")!
        let json = try await fetchJSON(url)
        return (json["horoscope"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func horoscopeAppAPI(_ sign: ZodiacSign) async throws -> String {
        var c = URLComponents(string: "https://horoscope-app-api.vercel.app/api/v1/get-horoscope/daily")!
        c.queryItems = [URLQueryItem(name: "sign", value: sign.name), URLQueryItem(name: "day", value: "TODAY")]
        let json = try await fetchJSON(c.url!)
        let data = json["data"] as? [String: Any]
        return (data?["horoscope"] as? String ?? data?["horoscope_data"] as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func fetchJSON(_ url: URL) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request) // follows redirects
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FeedError.unavailable
        }
        return json
    }
}
