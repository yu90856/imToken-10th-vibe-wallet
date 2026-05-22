import CoreLocation
import Foundation
import Observation

extension Notification.Name {
    static let homeWeatherDidUpdate = Notification.Name("homeWeatherDidUpdate")
}

@MainActor
@Observable
final class HomeWeatherService: NSObject, CLLocationManagerDelegate {
    static let shared: HomeWeatherService = {
        let service = HomeWeatherService()
        service.configureLocationManager()
        return service
    }()

    private(set) var weatherLine = "載入天氣中…"
    private(set) var authorizationDenied = false

    private let locationManager = CLLocationManager()
    private var isFetchingLocation = false
    private var loadingWatchdogTask: Task<Void, Never>?
    private var lastFetchCoordinate: CLLocationCoordinate2D?
    private var lastFetchAt: Date?

    private override init() {
        super.init()
    }

    /// App 啟動時呼叫，會觸發「使用 App 期間」定位授權詢問
    func beginLocationAndWeather() {
        configureLocationManager()
        startLoadingWatchdog()
        refreshIfNeeded()
    }

    func refreshIfNeeded() {
        configureLocationManager()
        let status = locationManager.authorizationStatus

        switch status {
        case .notDetermined:
            authorizationDenied = false
            updateWeatherLine("取得定位權限中…")
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            authorizationDenied = false
            updateWeatherLine("取得位置中…")
            requestLocation()
        case .denied, .restricted:
            authorizationDenied = true
            updateWeatherLine("未授權定位 · 請至設定開啟")
        @unknown default:
            updateWeatherLine("天氣暫不可用")
        }
    }

    private func configureLocationManager() {
        guard locationManager.delegate == nil else { return }
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    private func requestLocation() {
        guard !isFetchingLocation else { return }
        isFetchingLocation = true
        locationManager.requestLocation()
    }

    private func startLoadingWatchdog() {
        loadingWatchdogTask?.cancel()
        loadingWatchdogTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 12_000_000_000)
            guard !Task.isCancelled else { return }
            if weatherLine.contains("載入") || weatherLine.contains("取得") {
                updateWeatherLine(seasonalFallback())
            }
        }
    }

    private func updateWeatherLine(_ line: String) {
        guard weatherLine != line else { return }
        weatherLine = line
        NotificationCenter.default.post(name: .homeWeatherDidUpdate, object: nil)
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            isFetchingLocation = false
            refreshIfNeeded()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        Task { @MainActor in
            isFetchingLocation = false
            loadingWatchdogTask?.cancel()
            await fetchWeather(for: coordinate)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            isFetchingLocation = false
            updateWeatherLine(fallbackWeatherDescription())
        }
    }

    @MainActor
    private func fetchWeather(for coordinate: CLLocationCoordinate2D) async {
        if let lastFetchCoordinate, let lastFetchAt,
           lastFetchCoordinate.latitude == coordinate.latitude,
           lastFetchCoordinate.longitude == coordinate.longitude,
           Date().timeIntervalSince(lastFetchAt) < 1_800 {
            return
        }

        guard let apiKey = SecretsReader.string(for: "OPENWEATHER_API_KEY") else {
            updateWeatherLine(seasonalFallback())
            return
        }

        updateWeatherLine("查詢天氣中…")

        var components = URLComponents(string: "https://api.openweathermap.org/data/2.5/weather")!
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(coordinate.latitude)),
            URLQueryItem(name: "lon", value: String(coordinate.longitude)),
            URLQueryItem(name: "appid", value: apiKey),
            URLQueryItem(name: "units", value: "metric"),
            URLQueryItem(name: "lang", value: "zh_tw"),
        ]
        guard let url = components.url else {
            updateWeatherLine(seasonalFallback())
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                updateWeatherLine(seasonalFallback())
                return
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let main = json["main"] as? [String: Any],
                  let temp = main["temp"] as? Double,
                  let weather = (json["weather"] as? [[String: Any]])?.first,
                  let description = weather["description"] as? String else {
                updateWeatherLine(seasonalFallback())
                return
            }
            let rounded = Int(temp.rounded())
            let short = String(description.prefix(8))
            updateWeatherLine("\(short) \(rounded)°C")
            lastFetchCoordinate = coordinate
            lastFetchAt = Date()
            loadingWatchdogTask?.cancel()
        } catch {
            updateWeatherLine(seasonalFallback())
        }
    }

    private func fallbackWeatherDescription() -> String {
        authorizationDenied ? "未授權定位 · 請至設定開啟" : seasonalFallback()
    }

    private func seasonalFallback() -> String {
        let month = Calendar.current.component(.month, from: Date())
        switch month {
        case 6...8: return "晴時多雲，28°C"
        case 12, 1, 2: return "多雲，18°C"
        case 3...5: return "微雨，22°C"
        default: return "多雲，24°C"
        }
    }
}
