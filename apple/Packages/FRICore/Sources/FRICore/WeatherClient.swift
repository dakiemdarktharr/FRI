import Foundation

public struct WeatherLocation: Decodable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let name: String
    public let country: String?
    public let admin1: String?
    public let latitude: Double
    public let longitude: Double

    public init(id: Int = -1, name: String, country: String? = nil, admin1: String? = nil,
                latitude: Double, longitude: Double) {
        self.id = id; self.name = name; self.country = country; self.admin1 = admin1
        self.latitude = latitude; self.longitude = longitude
    }

    public var label: String {
        [name, admin1 == name ? nil : admin1, country].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 200 &&
        latitude.isFinite && longitude.isFinite && (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }
}

public struct WeatherForecast: Sendable {
    public let location: WeatherLocation
    public let temperature: Double
    public let code: Int
    public let high: Double
    public let low: Double
    public let time: String
    public let timezone: String
    public let fetchedAt: Date

    /// Same keys and millisecond timestamp as desktop 0.5.
    public var setting: JSONValue {
        var fields: [String: JSONValue] = [
            "city": .string(location.name), "latitude": .number(location.latitude), "longitude": .number(location.longitude),
            "temperature": .number(temperature), "code": .number(Double(code)),
            "high": .number(high), "low": .number(low), "time": .string(time), "timezone": .string(timezone),
            "fetchedAt": .number(fetchedAt.timeIntervalSince1970 * 1000)
        ]
        if let country = location.country { fields["country"] = .string(country) }
        if let admin1 = location.admin1 { fields["admin1"] = .string(admin1) }
        return .object(fields)
    }
}

public struct WeatherClient: Sendable {
    public typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)
    private let transport: Transport

    public init(transport: @escaping Transport = { try await URLSession.shared.data(for: $0) }) {
        self.transport = transport
    }

    public func search(_ city: String) async throws -> [WeatherLocation] {
        struct Search: Decodable { let results: [WeatherLocation]? }
        let query = city.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else { return [] }
        let result: Search = try await request(host: "geocoding-api.open-meteo.com", path: "/v1/search", fields: [
            "name": String(query.prefix(100)), "count": "5", "language": "en", "format": "json"
        ])
        var seen = Set<Int>()
        return (result.results ?? []).filter { $0.isValid && seen.insert($0.id).inserted }.prefix(5).map { $0 }
    }

    public func forecast(for location: WeatherLocation) async throws -> WeatherForecast {
        struct Response: Decodable {
            struct Current: Decodable { let temperature_2m: Double; let weather_code: Int; let time: String }
            struct Daily: Decodable { let temperature_2m_max: [Double?]; let temperature_2m_min: [Double?] }
            let current: Current
            let daily: Daily
            let timezone: String
        }
        guard location.isValid else { throw URLError(.badURL) }
        let response: Response = try await request(host: "api.open-meteo.com", path: "/v1/forecast", fields: [
            "latitude": String(location.latitude), "longitude": String(location.longitude),
            "current": "temperature_2m,weather_code", "daily": "temperature_2m_max,temperature_2m_min",
            "timezone": "auto", "forecast_days": "1", "temperature_unit": "celsius"
        ])
        guard let high = response.daily.temperature_2m_max.first ?? nil,
              let low = response.daily.temperature_2m_min.first ?? nil,
              high.isFinite, low.isFinite, high >= low, response.current.temperature_2m.isFinite,
              !response.current.time.isEmpty, !response.timezone.isEmpty else { throw URLError(.badServerResponse) }
        return WeatherForecast(location: location, temperature: response.current.temperature_2m,
                               code: response.current.weather_code, high: high, low: low,
                               time: response.current.time, timezone: response.timezone, fetchedAt: .now)
    }

    private func request<T: Decodable>(host: String, path: String, fields: [String: String]) async throws -> T {
        try Task.checkCancellation()
        var components = URLComponents()
        components.scheme = "https"; components.host = host; components.path = path
        components.queryItems = fields.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url else { throw URLError(.badURL) }
        let (data, response) = try await transport(URLRequest(url: url, timeoutInterval: 12))
        // Some transports can still finish after cancel; never publish that response.
        try Task.checkCancellation()
        guard data.count < 128_000, let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
