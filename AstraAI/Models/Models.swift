import AstroCore
import Foundation
import SwiftData

@Model
final class BirthProfile {
    var id: UUID = UUID()
    var name: String = ""
    var birthDate: Date = Date()
    var timeKnown: Bool = true
    var latitude: Double = 0
    var longitude: Double = 0
    var placeName: String = ""
    var timeZoneID: String = TimeZone.current.identifier
    /// The app owner's own chart (exactly one profile is primary).
    var isPrimary: Bool = false
    var relationship: String = "Me"
    var createdAt: Date = Date()

    init(name: String, birthDate: Date, timeKnown: Bool, latitude: Double, longitude: Double,
         placeName: String, timeZoneID: String, isPrimary: Bool, relationship: String) {
        self.name = name
        self.birthDate = birthDate
        self.timeKnown = timeKnown
        self.latitude = latitude
        self.longitude = longitude
        self.placeName = placeName
        self.timeZoneID = timeZoneID
        self.isPrimary = isPrimary
        self.relationship = relationship
    }

    var birthData: BirthData {
        BirthData(name: name, date: birthDate, timeKnown: timeKnown, latitude: latitude,
                  longitude: longitude, placeName: placeName, timeZoneID: timeZoneID)
    }

    var natalChart: NatalChart { NatalChart(birth: birthData) }
    var vedicChart: VedicChart { VedicChart(natal: natalChart) }
    var numerology: NumerologyProfile { NumerologyProfile(name: name, birthDate: birthDate) }
}

@Model
final class ChatMessage {
    var id: UUID = UUID()
    var profileID: UUID
    /// "user" or "assistant" — matches the Messages API roles.
    var role: String
    var text: String
    /// Which astrologer (AstrologerExpert.rawValue) the message belongs to.
    var expert: String = "astra"
    var createdAt: Date = Date()

    init(profileID: UUID, role: String, text: String, expert: String) {
        self.profileID = profileID
        self.role = role
        self.text = text
        self.expert = expert
    }
}

/// Generated readings are cached so each (profile, period) costs one API call.
@Model
final class CachedReading {
    @Attribute(.unique) var key: String
    var text: String
    var createdAt: Date = Date()

    init(key: String, text: String) {
        self.key = key
        self.text = text
    }
}
