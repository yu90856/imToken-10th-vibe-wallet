import Foundation
import WidgetKit

@MainActor
enum WidgetSyncService {
    private static let hotBitrefillQueries = ["amazon", "steam", "netflix", "uber"]

    static func refreshFromApp() async {
        let market = await loadMarketRows()
        let bitrefill = await loadBitrefillRows()
        let snapshot = WidgetSnapshot(
            updatedAt: Date(),
            marketRows: market,
            bitrefillRows: bitrefill
        )
        WidgetDataStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func loadMarketRows() async -> [WidgetMarketRow] {
        let tokens = await CoinGeckoMarketService.refreshIfNeeded()
        return tokens.prefix(4).map { token in
            let change = token.change24hPercent
            let sign = change >= 0 ? "+" : ""
            return WidgetMarketRow(
                id: token.id,
                symbol: token.symbol,
                priceText: token.formattedPrice,
                changeText: "\(sign)\(String(format: "%.2f", change))%",
                changeIsPositive: change >= 0
            )
        }
    }

    private static func loadBitrefillRows() async -> [WidgetBitrefillRow] {
        guard SecretsReader.string(for: "BITREFILL_API_KEY") != nil else {
            return fallbackBitrefillRows()
        }

        var rows: [WidgetBitrefillRow] = []
        for query in hotBitrefillQueries {
            guard rows.count < 3 else { break }
            switch await BitrefillCatalogService.search(query: query, limit: 1) {
            case .success(let products):
                guard let p = products.first(where: \.inStock) ?? products.first else { continue }
                rows.append(
                    WidgetBitrefillRow(
                        id: p.id,
                        name: p.name,
                        countryName: p.countryName,
                        searchQuery: query
                    )
                )
            case .failure:
                continue
            }
        }
        if rows.isEmpty { return fallbackBitrefillRows() }
        return rows
    }

    private static func fallbackBitrefillRows() -> [WidgetBitrefillRow] {
        [
            WidgetBitrefillRow(id: "demo-amazon", name: "Amazon Gift Card", countryName: "US", searchQuery: "amazon"),
            WidgetBitrefillRow(id: "demo-steam", name: "Steam", countryName: "Global", searchQuery: "steam"),
        ]
    }
}
