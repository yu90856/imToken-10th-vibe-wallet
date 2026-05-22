import Foundation

enum MarketChartTimeframe: String, CaseIterable, Identifiable {
    case m15 = "15m"
    case h1 = "1h"
    case h4 = "4h"
    case d1 = "1d"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .m15: return "15分"
        case .h1: return "1小時"
        case .h4: return "4小時"
        case .d1: return "1D"
        }
    }

    var coinGeckoDays: String {
        switch self {
        case .m15, .h1: return "1"
        case .h4: return "7"
        case .d1: return "30"
        }
    }
}

struct MarketChartSeriesPack: Equatable {
    let labels: [String]
    let prices: [Double]
    let changePct: Double
    let high: Double
    let low: Double
}

enum MarketChartSeriesService {
    @MainActor
    static func loadSeries(tokenId: String, timeframe: MarketChartTimeframe) async -> MarketChartSeriesPack {
        if let live = await fetchCoinGeckoSeries(tokenId: tokenId, timeframe: timeframe),
           live.prices.count >= 4 {
            return live
        }
        return mockSeries(for: tokenId, timeframe: timeframe)
    }

    private static func fetchCoinGeckoSeries(
        tokenId: String,
        timeframe: MarketChartTimeframe
    ) async -> MarketChartSeriesPack? {
        var components = URLComponents(string: "https://api.coingecko.com/api/v3/coins/\(tokenId)/market_chart")!
        components.queryItems = [
            URLQueryItem(name: "vs_currency", value: "usd"),
            URLQueryItem(name: "days", value: timeframe.coinGeckoDays),
        ]
        guard let url = components.url else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let pricesRaw = json["prices"] as? [[Double]] else {
                return nil
            }
            let usdPrices = pricesRaw.compactMap { row -> Double? in
                guard row.count >= 2 else { return row.last }
                return row[1]
            }
            let sampled = downsample(usdPrices, target: pointCount(for: timeframe))
            guard sampled.count >= 4 else { return nil }
            return pack(from: sampled, timeframe: timeframe, labelStyle: .time)
        } catch {
            return nil
        }
    }

    private enum LabelStyle { case time, weekday }

    private static func pack(
        from prices: [Double],
        timeframe: MarketChartTimeframe,
        labelStyle: LabelStyle
    ) -> MarketChartSeriesPack {
        let labels = makeLabels(count: prices.count, timeframe: timeframe, style: labelStyle)
        let first = prices.first ?? 0
        let last = prices.last ?? 0
        let change = first > 0 ? ((last - first) / first) * 100 : 0
        return MarketChartSeriesPack(
            labels: labels,
            prices: prices,
            changePct: change,
            high: prices.max() ?? last,
            low: prices.min() ?? last
        )
    }

    private static func downsample(_ values: [Double], target: Int) -> [Double] {
        guard values.count > target, target > 0 else { return values }
        let step = Double(values.count - 1) / Double(target - 1)
        return (0..<target).map { i in
            let index = min(values.count - 1, Int((Double(i) * step).rounded()))
            return values[index]
        }
    }

    private static func pointCount(for timeframe: MarketChartTimeframe) -> Int {
        switch timeframe {
        case .m15, .h1: return 10
        case .h4: return 8
        case .d1: return 8
        }
    }

    private static func makeLabels(
        count: Int,
        timeframe: MarketChartTimeframe,
        style: LabelStyle
    ) -> [String] {
        guard count > 0 else { return [] }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        if style == .weekday {
            formatter.dateFormat = "E"
            let weekdays = ["週一", "週二", "週三", "週四", "週五", "週六", "週日", "今日"]
            return (0..<count).map { i in
                i == count - 1 ? "今日" : weekdays[min(i, weekdays.count - 2)]
            }
        }
        switch timeframe {
        case .m15:
            formatter.dateFormat = "HH:mm"
            let now = Date()
            return (0..<count).map { i in
                formatter.string(from: now.addingTimeInterval(TimeInterval((i - count + 1) * 5 * 60)))
            }
        case .h1:
            formatter.dateFormat = "HH:mm"
            let now = Date()
            return (0..<count).map { i in
                formatter.string(from: now.addingTimeInterval(TimeInterval((i - count + 1) * 15 * 60)))
            }
        case .h4:
            formatter.dateFormat = "HH:mm"
            let anchors = ["08:00", "10:00", "12:00", "14:00", "16:00", "18:00", "20:00", "22:00"]
            return (0..<count).map { anchors[$0 % anchors.count] }
        case .d1:
            return makeLabels(count: count, timeframe: .d1, style: .weekday)
        }
    }

    static func mockSeries(for tokenId: String, timeframe: MarketChartTimeframe) -> MarketChartSeriesPack {
        let fallbackPrice = ExpandedMarketCatalog.fallbackTokens().first { $0.id == tokenId }?.priceUSD ?? 1
        let base = NSDecimalNumber(decimal: fallbackPrice).doubleValue
        let bump = max(base * 0.08, 0.00001)
        let templates: [MarketChartTimeframe: [Double]] = [
            .m15: [-0.03, -0.01, 0.01, 0, 0.02, 0.03, 0.02, 0.04, 0.03, 0.02],
            .h1: [-0.06, -0.04, -0.02, 0.01, 0.02, 0.04, 0.03, 0.02],
            .h4: [-0.08, -0.04, -0.02, 0, 0.02, 0.01, 0.03, 0.02],
            .d1: [-0.12, -0.08, -0.05, -0.02, 0.01, 0.03, 0.04, 0.05],
        ]
        let offsets = templates[timeframe] ?? templates[.d1]!
        let prices = offsets.map { base + bump * $0 }
        let style: LabelStyle = timeframe == .d1 ? .weekday : .time
        return pack(from: prices, timeframe: timeframe, labelStyle: style)
    }
}
