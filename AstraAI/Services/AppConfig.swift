import Foundation
import UIKit

/// Build-time configuration (Config/Secrets.xcconfig → Info.plist). Users never enter an
/// API key: the app calls the AstraAI proxy (see /server), which holds the Anthropic key.
enum AppConfig {
    static var baseURL: URL {
        plist("CLAUDE_BASE_URL").flatMap(URL.init(string:)) ?? URL(string: "http://localhost:8787")!
    }

    static var appToken: String? { plist("ASTRA_APP_TOKEN") }

    /// Stable per-install ID used by the proxy for per-device daily limits.
    static var deviceID: String {
        let key = "astra.deviceID"
        if let id = UserDefaults.standard.string(forKey: key) { return id }
        let id = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        UserDefaults.standard.set(id, forKey: key)
        return id
    }

    static let termsURL = URL(string: "https://macdissect.com/apps/astraai/terms")!
    static let privacyURL = URL(string: "https://macdissect.com/apps/astraai/privacy")!
    static let supportURL = URL(string: "https://macdissect.com/apps/astraai/support")!

    /// RevenueCat app user ID, mirrored by ProStore so the proxy can verify Pro server-side.
    static var subscriberID: String? {
        get { UserDefaults.standard.string(forKey: "astra.rcAppUserID") }
        set { UserDefaults.standard.set(newValue, forKey: "astra.rcAppUserID") }
    }

    private static func plist(_ key: String) -> String? {
        guard let s = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !s.isEmpty, !s.hasPrefix("$(") else { return nil }
        return s
    }
}
