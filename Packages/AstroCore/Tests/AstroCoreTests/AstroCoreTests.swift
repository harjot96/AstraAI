import XCTest
@testable import AstroCore

final class AstroCoreTests: XCTestCase {

    /// Albert Einstein, 14 Mar 1879 11:30 LMT, Ulm (48°24′N 9°59′E) → 10:50 UT.
    private var einstein: BirthData {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let date = cal.date(from: DateComponents(year: 1879, month: 3, day: 14, hour: 10, minute: 50))!
        return BirthData(name: "Albert Einstein", date: date, timeKnown: true, latitude: 48.4,
                         longitude: 9.9833, placeName: "Ulm", timeZoneID: "Europe/Berlin")
    }

    private func assertAngle(_ actual: Double, _ expected: Double, tolerance: Double = 1.0,
                             _ label: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertLessThan(separation(actual, expected), tolerance,
                          "\(label): got \(actual), expected \(expected)", file: file, line: line)
    }

    func testEinsteinPlanets() {
        let chart = NatalChart(birth: einstein)
        let expected: [Planet: Double] = [
            .sun: 353.5, .moon: 254.5, .mercury: 3.1, .venus: 17.0, .mars: 296.9,
            .jupiter: 327.5, .saturn: 4.2,
        ]
        for (planet, lon) in expected {
            assertAngle(chart.body(planet).position.longitude, lon, planet.rawValue)
        }
    }

    func testEinsteinAnglesAndHouses() throws {
        let chart = NatalChart(birth: einstein)
        let houses = try XCTUnwrap(chart.houses)
        assertAngle(houses.ascendant, 101.6, "Ascendant")
        assertAngle(houses.midheaven, 342.8, "Midheaven")
        XCTAssertEqual(chart.risingSign, .cancer)
        XCTAssertEqual(houses.cusps.count, 12)
        XCTAssertEqual(houses.cusps[0], houses.ascendant, accuracy: 1e-9)
        XCTAssertEqual(houses.cusps[9], houses.midheaven, accuracy: 1e-9)
        // Sun in Pisces near the MC falls in the 9th or 10th house.
        XCTAssertTrue([9, 10].contains(chart.body(.sun).house ?? 0))
    }

    func testJ2000Sun() {
        let jd = 2_451_545.0
        assertAngle(Ephemeris.position(of: .sun, jd: jd).longitude, 280.4, tolerance: 0.3, "Sun J2000")
    }

    func testMercuryRetrogradeApril2024() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let date = cal.date(from: DateComponents(year: 2024, month: 4, day: 10))!
        XCTAssertTrue(Ephemeris.position(of: .mercury, jd: JulianDay.from(date)).isRetrograde)
        let later = cal.date(from: DateComponents(year: 2024, month: 6, day: 1))!
        XCTAssertFalse(Ephemeris.position(of: .mercury, jd: JulianDay.from(later)).isRetrograde)
    }

    func testPlacidusFallsBackAtPolarLatitude() {
        let jd = 2_460_000.5
        let cusps = Houses.compute(jd: jd, latitude: 78, longitude: 15, system: .placidus)
        XCTAssertEqual(cusps.cusps.count, 12)
        for i in 0..<12 {
            XCTAssertEqual(cusps.house(of: cusps.cusps[i] + 0.01), i + 1)
        }
    }

    func testVedicChartAndDasha() {
        let natal = NatalChart(birth: einstein)
        let vedic = VedicChart(natal: natal)
        XCTAssertEqual(vedic.ayanamsa, 22.0, accuracy: 0.3) // ~22° in 1879
        XCTAssertEqual(vedic.moonSign, .scorpio)             // tropical Sag 14° − 22° → Scorpio
        XCTAssertEqual(vedic.dashas.count, 9)
        let total = vedic.dashas.last!.end.timeIntervalSince(vedic.dashas.first!.start) / (365.2425 * 86_400)
        XCTAssertEqual(total, 120, accuracy: 0.01)
        XCTAssertTrue(vedic.dashas.first!.contains(einstein.date))
        let antar = Vimshottari.antarDashas(of: vedic.dashas[1])
        XCTAssertEqual(antar.first?.lord, vedic.dashas[1].lord)
        XCTAssertEqual(antar.last!.end.timeIntervalSince1970, vedic.dashas[1].end.timeIntervalSince1970, accuracy: 1)
    }

    func testNakshatraAttributes() {
        XCTAssertEqual(Nakshatra(siderealLongitude: 0.5), .ashwini)
        XCTAssertEqual(Nakshatra(siderealLongitude: 359.9), .revati)
        XCTAssertEqual(Nakshatra.ashwini.lord, .ketu)
        XCTAssertEqual(Nakshatra.rohini.lord, .moon)
        XCTAssertEqual(Nakshatra.ardra.nadi, .adi)
        XCTAssertEqual(Nakshatra.uttaraPhalguni.nadi, .adi)
        XCTAssertEqual(Nakshatra.revati.nadi, .antya)
    }

    func testGunaMilanIsBoundedAndSymmetricForSelf() {
        let v = VedicChart(natal: NatalChart(birth: einstein))
        let self_ = GunaMilan(first: v, second: v)
        XCTAssertEqual(self_.kootas.count, 8)
        XCTAssertEqual(self_.kootas.reduce(0) { $0 + $1.max }, 36)
        XCTAssertEqual(self_.kootas.first { $0.name == "Nadi" }?.score, 0) // same nadi
        XCTAssertLessThanOrEqual(self_.total, 36)
        XCTAssertGreaterThanOrEqual(self_.total, 0)
    }

    func testSynastryScoreRange() {
        var other = einstein
        other.date = other.date.addingTimeInterval(86_400 * 200)
        let s = Synastry(NatalChart(birth: einstein), NatalChart(birth: other))
        XCTAssertTrue((12...98).contains(s.score))
    }

    func testNumerology() {
        let n = NumerologyProfile(name: "Albert Einstein", birthDate: einstein.date)
        XCTAssertEqual(n.lifePath, 6)
        XCTAssertEqual(Numerology.reduce(29), 11)
        XCTAssertEqual(Numerology.reduce(38), 11)
        XCTAssertEqual(Numerology.reduce(29, keepMasters: false), 2)
    }

    func testMoonPhaseNaming() {
        XCTAssertEqual(MoonPhase(angle: 0).name, "New Moon")
        XCTAssertEqual(MoonPhase(angle: 180).name, "Full Moon")
        XCTAssertEqual(MoonPhase(angle: 180).illumination, 1, accuracy: 1e-9)
    }

    func testUnknownBirthTimeHasNoHouses() {
        var b = einstein
        b.timeKnown = false
        let chart = NatalChart(birth: b)
        XCTAssertNil(chart.houses)
        XCTAssertNil(chart.risingSign)
        XCTAssertTrue(ChartSummary.natal(chart).contains("Birth time unknown"))
    }

    func testPanchang() {
        // 2024-04-08 18:21 UT was a new moon (solar eclipse) → Amavasya.
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let newMoon = cal.date(from: DateComponents(year: 2024, month: 4, day: 8, hour: 16))!
        let p = Panchang(date: newMoon, timeZone: cal.timeZone)
        XCTAssertEqual(p.tithi, 30)
        XCTAssertEqual(p.tithiName, "Amavasya")
        XCTAssertEqual(p.weekday, 2) // Monday
        XCTAssertEqual(p.varaLord, .moon)
        // Full moon 2024-04-23 23:49 UT → Purnima shortly before.
        let fullMoon = cal.date(from: DateComponents(year: 2024, month: 4, day: 23, hour: 20))!
        XCTAssertEqual(Panchang(date: fullMoon).tithiName, "Purnima")
        XCTAssertTrue((0..<27).contains(p.yogaIndex))
        XCTAssertFalse(p.karanaName.isEmpty)
    }

    func testTarotDeck() {
        XCTAssertEqual(TarotDeck.cards.count, 78)
        XCTAssertEqual(Set(TarotDeck.cards.map(\.id)).count, 78)
        XCTAssertEqual(TarotDeck.cards[21].name, "The World")
        XCTAssertEqual(TarotDeck.cards[21].label, "XXI")
        XCTAssertEqual(TarotDeck.cards[77].name, "King of Pentacles")
        let spread = TarotDeck.draw(.pastPresentFuture)
        XCTAssertEqual(spread.map(\.position), ["Past", "Present", "Future"])
        XCTAssertEqual(Set(spread.map(\.card.id)).count, 3)
    }

    func testDailyCardIsStablePerDayAndPerson() {
        let day = Date(timeIntervalSince1970: 1_790_000_000)
        let a = TarotDeck.dailyCard(seed: "ada", date: day)
        XCTAssertEqual(a, TarotDeck.dailyCard(seed: "ada", date: day))
        let others = (1...10).map { TarotDeck.dailyCard(seed: "ada", date: day.addingTimeInterval(Double($0) * 86_400)).card.id }
        XCTAssertGreaterThan(Set(others).count, 3)
    }
}
