import Foundation

enum WeatherCondition: String {
    case clear, cloudy, rain, drizzle, snow, thunder, fog, wind

    var emoji: String {
        switch self {
        case .clear: return "☀️"
        case .cloudy: return "☁️"
        case .rain: return "🌧"
        case .drizzle: return "🌦"
        case .snow: return "❄️"
        case .thunder: return "⛈"
        case .fog: return "🌫"
        case .wind: return "💨"
        }
    }

    var label: String {
        switch self {
        case .clear: return "맑음"
        case .cloudy: return "흐림"
        case .rain: return "비"
        case .drizzle: return "이슬비"
        case .snow: return "눈"
        case .thunder: return "천둥번개"
        case .fog: return "안개"
        case .wind: return "바람"
        }
    }
}

class WeatherService: ObservableObject {
    @Published var condition: WeatherCondition = .clear
    @Published var temperature: Double = 0
    @Published var description: String = ""

    private var timer: Timer?

    init() {
        fetch()
        timer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            self?.fetch()
        }
    }

    func fetch() {
        Task {
            // 1. IP 기반 위치
            guard let locURL = URL(string: "https://ipapi.co/json/"),
                  let (locData, _) = try? await URLSession.shared.data(from: locURL),
                  let locJSON = try? JSONSerialization.jsonObject(with: locData) as? [String: Any],
                  let lat = locJSON["latitude"] as? Double,
                  let lon = locJSON["longitude"] as? Double else { return }

            // 2. Open-Meteo 날씨 조회
            let urlStr = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current_weather=true"
            guard let weatherURL = URL(string: urlStr),
                  let (weatherData, _) = try? await URLSession.shared.data(from: weatherURL),
                  let weatherJSON = try? JSONSerialization.jsonObject(with: weatherData) as? [String: Any],
                  let current = weatherJSON["current_weather"] as? [String: Any],
                  let code = current["weathercode"] as? Int,
                  let temp = current["temperature"] as? Double,
                  let wind = current["windspeed"] as? Double else { return }

            let cond = Self.mapCode(code, windspeed: wind)

            await MainActor.run {
                self.condition = cond
                self.temperature = temp
                self.description = "\(cond.emoji) \(cond.label) \(Int(temp))°"
            }
        }
    }

    static func mapCode(_ code: Int, windspeed: Double) -> WeatherCondition {
        if windspeed > 40 && code < 50 { return .wind }
        switch code {
        case 0: return .clear
        case 1...3: return .cloudy
        case 45, 48: return .fog
        case 51...57: return .drizzle
        case 61...67, 80...82: return .rain
        case 71...77, 85, 86: return .snow
        case 95...99: return .thunder
        default: return .clear
        }
    }
}
