import SwiftData
import SwiftUI

/// Birth-details form used for onboarding, adding a partner/friend, and editing.
struct ProfileForm: View {
    enum Mode {
        case onboarding
        case add
        case edit(BirthProfile)
    }

    let mode: Mode
    var onSave: ((BirthProfile) -> Void)?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var relationship = "Partner"
    @State private var day = Calendar.current.date(from: DateComponents(year: 1995, month: 6, day: 15))!
    @State private var time = Calendar.current.date(from: DateComponents(year: 1995, month: 6, day: 15, hour: 12))!
    @State private var timeKnown = true
    @State private var placeQuery = ""
    @State private var place: Place?
    @State private var results: [Place] = []
    @State private var searching = false
    @State private var searchError: String?
    @State private var loaded = false

    private let relationships = ["Partner", "Crush", "Spouse", "Friend", "Family", "Colleague"]

    private var isOnboarding: Bool { if case .onboarding = mode { true } else { false } }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && place != nil }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                    .textContentType(.name)
                if !isOnboarding, !(editing?.isPrimary ?? false) {
                    Picker("Relationship", selection: $relationship) {
                        ForEach(relationships, id: \.self) { Text($0) }
                    }
                }
            } header: { SectionLabel(isOnboarding ? "What should Astra call you?" : "Who is this?") }

            Section {
                DatePicker("Date", selection: $day, in: ...Date.now, displayedComponents: .date)
                Toggle("I know my birth time", isOn: $timeKnown)
                if timeKnown {
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                }
            } header: { SectionLabel("Birth date & time") } footer: {
                Text(timeKnown
                     ? "Exact time unlocks your rising sign, houses and Vedic lagna. Check your birth certificate."
                     : "Without a time we'll use noon: planets and signs stay accurate, but houses and rising sign are skipped.")
            }

            Section {
                HStack {
                    TextField("City of birth", text: $placeQuery)
                        .onSubmit(search)
                        .submitLabel(.search)
                    if searching { ProgressView() } else {
                        Button("Search", action: search).disabled(placeQuery.count < 2)
                    }
                }
                if let place {
                    Label(place.name, systemImage: "mappin.circle.fill")
                        .foregroundStyle(Theme.gold)
                }
                ForEach(results) { r in
                    Button {
                        place = r
                        placeQuery = r.name
                        results = []
                    } label: {
                        VStack(alignment: .leading) {
                            Text(r.name).foregroundStyle(Theme.text)
                            Text(String(format: "%.2f°, %.2f° · %@", r.latitude, r.longitude, r.timeZoneID))
                                .font(Theme.mono(10)).foregroundStyle(Theme.secondary)
                        }
                    }
                }
                if let searchError { Text(searchError).foregroundStyle(Theme.tense).font(.footnote) }
            } header: { SectionLabel("Birthplace") }

            Section {
                Button(isOnboarding ? "Reveal my chart" : "Save", action: save)
                    .buttonStyle(PillButtonStyle())
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.4)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
        }
        .scrollContentBackground(.hidden)
        .background(StarfieldBackground())
        .navigationTitle(isOnboarding ? "Your birth details" : (editing == nil ? "Add a person" : "Edit details"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isOnboarding {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .onAppear(perform: loadExisting)
    }

    private var editing: BirthProfile? { if case .edit(let p) = mode { p } else { nil } }

    private func loadExisting() {
        guard !loaded, let p = editing else { return }
        loaded = true
        name = p.name
        relationship = p.relationship
        let wall = PlaceSearch.wallClock(p.birthDate, in: p.timeZoneID)
        day = wall
        time = wall
        timeKnown = p.timeKnown
        place = Place(name: p.placeName, latitude: p.latitude, longitude: p.longitude, timeZoneID: p.timeZoneID)
        placeQuery = p.placeName
    }

    private func search() {
        searching = true
        searchError = nil
        Task {
            do {
                results = try await PlaceSearch.search(placeQuery)
                if results.isEmpty { searchError = "No matches — try adding the country." }
            } catch {
                searchError = "Couldn't find that place. Check your connection or spelling."
            }
            searching = false
        }
    }

    private func save() {
        guard let place else { return }
        let instant = PlaceSearch.instant(day: day, time: timeKnown ? time : day, in: place.timeZoneID)
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let p = editing {
            p.name = trimmed
            p.relationship = p.isPrimary ? "Me" : relationship
            p.birthDate = instant
            p.timeKnown = timeKnown
            p.latitude = place.latitude
            p.longitude = place.longitude
            p.placeName = place.name
            p.timeZoneID = place.timeZoneID
            // Chart changed → old readings are stale.
            try? context.delete(model: CachedReading.self)
            try? context.save()
            onSave?(p)
        } else {
            let p = BirthProfile(name: trimmed, birthDate: instant, timeKnown: timeKnown,
                                 latitude: place.latitude, longitude: place.longitude, placeName: place.name,
                                 timeZoneID: place.timeZoneID, isPrimary: isOnboarding,
                                 relationship: isOnboarding ? "Me" : relationship)
            context.insert(p)
            try? context.save()
            onSave?(p)
        }
        if !isOnboarding { dismiss() }
    }
}
