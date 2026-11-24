import Foundation

/// Reads both Apple and desktop 0.5 cache formats without inventing freshness.
public struct CachedWeather: Sendable {
    public let city: String
    public let summary: String
    public let fetchedAt: Date?
    private let details: [String: JSONValue]

    public init?(settings: [String: JSONValue]) {
        if case .object(let cache) = settings["appleWeatherCache"],
           let summary = cache["summary"]?.string, !summary.isEmpty {
            self.city = cache["city"]?.string ?? ""
            self.summary = summary
            self.fetchedAt = Self.timestamp(cache["fetchedAt"], divisor: 1)
            self.details = [:]
        } else if case .object(let cache) = settings["weather"],
                  let city = cache["city"]?.string, !city.isEmpty,
                  case .number(let temperature) = cache["temperature"], temperature.isFinite {
            self.city = city
            self.summary = "\(city) · \(temperature.formatted(.number.precision(.fractionLength(0)))) °C"
            self.fetchedAt = Self.timestamp(cache["fetchedAt"], divisor: 1000)
            self.details = cache
        } else { return nil }
    }

    public var location: WeatherLocation? {
        guard let latitude = number("latitude"), let longitude = number("longitude") else { return nil }
        let location = WeatherLocation(name: city, country: details["country"]?.string, admin1: details["admin1"]?.string,
                                       latitude: latitude, longitude: longitude)
        return location.isValid ? location : nil
    }

    public var conditions: String? {
        guard let code = number("code") else { return nil }
        switch code {
        case 0: return "Clear sky"
        case 1: return "Mostly clear"
        case 2: return "Partly cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Fog"
        case 51, 53, 55: return "Drizzle"
        case 56, 57: return "Freezing drizzle"
        case 61, 63, 65: return "Rain"
        case 66, 67: return "Freezing rain"
        case 71, 73, 75, 77: return "Snow"
        case 80, 81, 82: return "Rain showers"
        case 85, 86: return "Snow showers"
        case 95, 97: return "Thunderstorm"
        case 96, 99: return "Thunderstorm with hail"
        default: return nil
        }
    }

    public var dailyRange: String? {
        guard let high = number("high"), let low = number("low"), high >= low else { return nil }
        return "High \(high.formatted(.number.precision(.fractionLength(0))))° · Low \(low.formatted(.number.precision(.fractionLength(0))))°"
    }

    private func number(_ key: String) -> Double? {
        guard case .number(let value) = details[key], value.isFinite else { return nil }
        return value
    }

    public func isStale(at now: Date) -> Bool {
        guard let fetchedAt else { return true }
        let age = now.timeIntervalSince(fetchedAt)
        return age >= 3600 || age < -300
    }

    private static func timestamp(_ value: JSONValue?, divisor: Double) -> Date? {
        guard case .number(let number) = value, number.isFinite, number > 0,
              number / divisor < 253_402_300_800 else { return nil }
        return Date(timeIntervalSince1970: number / divisor)
    }
}

public extension CalendarState {
    mutating func disconnectWeather() {
        settings.removeValue(forKey: "appleWeatherCache")
        settings.removeValue(forKey: "weather")
    }

    mutating func disconnectMaps() {
        settings.removeValue(forKey: "mapsLocation")
        settings.removeValue(forKey: "mapsRegion")
    }

    var savedMapName: String? {
        if case .object(let place) = settings["mapsLocation"], let name = place["name"]?.string { return name }
        return settings["mapsLocation"]?.string ?? settings["mapsRegion"]?.string
    }
}
