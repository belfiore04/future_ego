import Foundation
import CoreLocation

// MARK: - WeatherService

/// Provides live city name + weather by combining CoreLocation
/// reverse-geocoding with the free Open-Meteo API.
@MainActor
class WeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = WeatherService()

    @Published var cityName: String = "定位中"
    @Published var weatherDescription: String = "..."
    @Published var temperature: Double?

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestLocation() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestLocation()
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.first else { return }
        let coordinate = location.coordinate
        Task { @MainActor in
            reverseGeocode(location)
            fetchWeather(lat: coordinate.latitude, lon: coordinate.longitude)
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        Task { @MainActor in
            cityName = "北京"         // fallback
            weatherDescription = "晴"
        }
    }

    // MARK: - Reverse Geocoding

    private func reverseGeocode(_ location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            Task { @MainActor [weak self] in
                guard let self, let placemark = placemarks?.first else { return }
                self.cityName = placemark.locality
                    ?? placemark.administrativeArea
                    ?? "未知"
            }
        }
    }

    // MARK: - Open-Meteo Fetch

    private func fetchWeather(lat: Double, lon: Double) {
        let urlString = "https://api.open-meteo.com/v1/forecast"
            + "?latitude=\(lat)&longitude=\(lon)"
            + "&current=temperature_2m,weather_code&timezone=auto"
        guard let url = URL(string: urlString) else { return }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let result = try JSONDecoder().decode(
                    OpenMeteoResponse.self, from: data
                )
                self.temperature = result.current.temperature2m
                self.weatherDescription = Self.weatherCodeToDescription(
                    result.current.weatherCode
                )
            } catch {
                self.weatherDescription = "晴" // fallback
            }
        }
    }

    // MARK: - WMO Weather Code Mapping

    static func weatherCodeToDescription(_ code: Int) -> String {
        switch code {
        case 0:        return "晴"
        case 1:        return "大部晴"
        case 2:        return "多云"
        case 3:        return "阴"
        case 45, 48:   return "雾"
        case 51, 53, 55: return "毛毛雨"
        case 61, 63, 65: return "雨"
        case 66, 67:   return "冻雨"
        case 71, 73, 75: return "雪"
        case 77:       return "雪粒"
        case 80, 81, 82: return "阵雨"
        case 85, 86:   return "阵雪"
        case 95:       return "雷暴"
        case 96, 99:   return "冰雹"
        default:       return "晴"
        }
    }
}

// MARK: - API Response Models

struct OpenMeteoResponse: Codable {
    let current: OpenMeteoCurrent
}

struct OpenMeteoCurrent: Codable {
    let temperature2m: Double
    let weatherCode: Int

    enum CodingKeys: String, CodingKey {
        case temperature2m = "temperature_2m"
        case weatherCode = "weather_code"
    }
}
