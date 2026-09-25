import CoreLocation
import Foundation

struct Place: Identifiable, Hashable {
    let name: String
    let latitude: Double
    let longitude: Double
    let timeZoneID: String
    var id: String { "\(name)|\(latitude)|\(longitude)" }
}

/// Resolves a typed birthplace into coordinates and its time zone via CLGeocoder.
enum PlaceSearch {
    static func search(_ query: String) async throws -> [Place] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { return [] }
        let marks = try await CLGeocoder().geocodeAddressString(trimmed)
        return marks.compactMap { mark in
            guard let loc = mark.location else { return nil }
            let parts = [mark.locality, mark.administrativeArea, mark.country].compactMap { $0 }
            let name = parts.isEmpty ? (mark.name ?? trimmed) : parts.joined(separator: ", ")
            return Place(name: name, latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude,
                         timeZoneID: mark.timeZone?.identifier ?? TimeZone.current.identifier)
        }
    }

    /// Combines a wall-clock date and time entered by the user with the
    /// birthplace's time zone (not the phone's) into an absolute instant.
    static func instant(day: Date, time: Date, in timeZoneID: String) -> Date {
        let local = Calendar.current
        let d = local.dateComponents([.year, .month, .day], from: day)
        let t = local.dateComponents([.hour, .minute], from: time)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: timeZoneID) ?? .current
        return cal.date(from: DateComponents(year: d.year, month: d.month, day: d.day,
                                             hour: t.hour, minute: t.minute)) ?? day
    }

    /// Inverse of `instant`: wall-clock components in the birthplace time zone,
    /// re-expressed in the phone's calendar for editing in DatePickers.
    static func wallClock(_ instant: Date, in timeZoneID: String) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: timeZoneID) ?? .current
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute], from: instant)
        return Calendar.current.date(from: c) ?? instant
    }
}
