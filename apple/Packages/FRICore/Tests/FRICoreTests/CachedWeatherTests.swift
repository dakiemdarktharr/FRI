import Foundation
import Testing
@testable import FRICore

@Test func importedWeatherUsesMillisecondsAndDisconnectClearsBothFormats() throws {
    let now = Date(timeIntervalSince1970: 1_795_440_000)
    var state = CalendarState()
    state.settings["weather"] = .object([
        "city": .string("Hà Nội"), "temperature": .number(28),
        "fetchedAt": .number(now.timeIntervalSince1970 * 1000)
    ])
    let desktop = try #require(CachedWeather(settings: state.settings))
    #expect(desktop.fetchedAt == now)
    #expect(!desktop.isStale(at: now))
    #expect(desktop.isStale(at: now.addingTimeInterval(3600)))
    #expect(desktop.isStale(at: now.addingTimeInterval(-301)))
    state.settings["appleWeatherCache"] = .object([
        "city": .string("Da Nang"), "summary": .string("Da Nang · 26 °C"),
        "fetchedAt": .number(now.timeIntervalSince1970)
    ])
    #expect(CachedWeather(settings: state.settings)?.city == "Da Nang")
    state.settings["mapsRegion"] = .string("Imported place")
    #expect(state.savedMapName == "Imported place")
    state.settings["mapsLocation"] = .object(["name": .string("More specific place")])
    #expect(state.savedMapName == "More specific place")
    state.disconnectWeather()
    state.disconnectMaps()
    #expect(CachedWeather(settings: state.settings) == nil)
    #expect(state.savedMapName == nil)
    #expect(state.settings.isEmpty)
}

@Test func widgetDoesNotPresentCurrentWeatherAsAFutureForecast() throws {
    let now = try #require(CalendarClock.date("2026-11-23"))
    var state = CalendarState()
    state.settings["appleWeatherCache"] = .object([
        "summary": .string("Hanoi · 28 °C"), "fetchedAt": .number(now.timeIntervalSince1970)
    ])
    #expect(WidgetSnapshot(state: state, day: now, now: now).service == "Hanoi · 28 °C")
    let tomorrow = try #require(CalendarClock.local.date(byAdding: .day, value: 1, to: now))
    #expect(WidgetSnapshot(state: state, day: tomorrow, now: now).service == nil)
    #expect(WidgetSnapshot.refreshDates(state: state, day: now, now: now).contains(now.addingTimeInterval(3600)))
    #expect(WidgetSnapshot(state: state, day: now, now: now.addingTimeInterval(3600)).service == "Hanoi · 28 °C · cached")
    state.settings["appleWeatherCache"] = .object(["summary": .string("Hanoi · 28 °C")])
    #expect(CachedWeather(settings: state.settings)?.isStale(at: now) == true)
    #expect(WidgetSnapshot(state: state, day: now, now: now).service == "Hanoi · 28 °C · cached")
}
