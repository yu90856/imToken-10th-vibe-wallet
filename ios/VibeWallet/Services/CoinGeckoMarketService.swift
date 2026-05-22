import Foundation
import OSLog

/// CoinGecko 公開行情（主流市值前 50 + meme + trending）
@MainActor
enum CoinGeckoMarketService {
    private static let log = Logger(subsystem: "com.vibe.wallet", category: "Market")

    enum DataSource: String {
        case live = "CoinGecko 即時"
        case partial = "CoinGecko 部分"
        case offline = "離線示範"
    }

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()

    private static var cache: [MarketToken] = []
    private static var lastFetch: Date?
    private static var lastSource: DataSource = .offline
    private static var lastError: String?
    private static let cacheTTL: TimeInterval = 90

    static var dataSourceLabel: String { lastSource.rawValue }
    static var lastLoadError: String? { lastError }

    static func cachedTokens() -> [MarketToken] {
        if cache.isEmpty {
            return ExpandedMarketCatalog.fallbackTokens()
        }
        return cache
    }

    @discardableResult
    static func refreshIfNeeded(force: Bool = false) async -> [MarketToken] {
        if !force,
           let lastFetch,
           Date().timeIntervalSince(lastFetch) < cacheTTL,
           !cache.isEmpty {
            return cache
        }

        var merged: [MarketToken] = []
        var successes = 0
        lastError = nil

        // 分開請求，避免手機網路同時打多支 API 被 CoinGecko 限流
        if let top = await fetchSafely(
            label: "top50",
            work: { try await fetchTopMarkets(perPage: 50, category: .mainstream) }
        ) {
            merged.append(contentsOf: top)
            successes += 1
        }

        try? await Task.sleep(nanoseconds: 350_000_000)

        if let meme = await fetchSafely(
            label: "meme",
            work: { try await fetchCategoryMarkets(categorySlug: "meme-token", perPage: 25) }
        ) {
            merged.append(contentsOf: meme)
            successes += 1
        }

        try? await Task.sleep(nanoseconds: 350_000_000)

        if let trending = await fetchSafely(
            label: "trending",
            work: { try await fetchTrendingMarkets() }
        ) {
            merged.append(contentsOf: trending)
            successes += 1
        }

        let deduped = dedupe(merged)
        if deduped.count >= 8 {
            cache = deduped
            lastFetch = Date()
            lastSource = successes >= 2 ? .live : .partial
            log.info("market loaded \(deduped.count) tokens, source=\(lastSource.rawValue)")
            return cache
        }

        lastError = lastError ?? "無法連線 CoinGecko"
        lastSource = .offline
        if cache.isEmpty || force {
            cache = ExpandedMarketCatalog.fallbackTokens()
        }
        log.warning("market fallback \(cache.count) tokens: \(lastError ?? "unknown", privacy: .public)")
        return cache
    }

    static func token(id: String) -> MarketToken? {
        cachedTokens().first { $0.id == id }
    }

    static func imageURL(forTokenId id: String) -> String? {
        token(id: id)?.imageURL
    }

    // MARK: - Fetch

    private static func fetchTopMarkets(perPage: Int, category: MarketTokenCategory) async throws -> [MarketToken] {
        var components = URLComponents(string: "https://api.coingecko.com/api/v3/coins/markets")!
        components.queryItems = [
            URLQueryItem(name: "vs_currency", value: "usd"),
            URLQueryItem(name: "order", value: "market_cap_desc"),
            URLQueryItem(name: "per_page", value: "\(perPage)"),
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "sparkline", value: "false"),
            URLQueryItem(name: "price_change_percentage", value: "24h"),
        ]
        let data = try await get(components.url!)
        return try parseMarkets(data, category: category)
    }

    private static func fetchCategoryMarkets(categorySlug: String, perPage: Int) async throws -> [MarketToken] {
        var components = URLComponents(string: "https://api.coingecko.com/api/v3/coins/markets")!
        components.queryItems = [
            URLQueryItem(name: "vs_currency", value: "usd"),
            URLQueryItem(name: "category", value: categorySlug),
            URLQueryItem(name: "order", value: "volume_desc"),
            URLQueryItem(name: "per_page", value: "\(perPage)"),
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "sparkline", value: "false"),
            URLQueryItem(name: "price_change_percentage", value: "24h"),
        ]
        let data = try await get(components.url!)
        return try parseMarkets(data, category: .onChain)
    }

    private static func fetchTrendingMarkets() async throws -> [MarketToken] {
        let url = URL(string: "https://api.coingecko.com/api/v3/search/trending")!
        let data = try await get(url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let coins = json["coins"] as? [[String: Any]] else {
            return []
        }
        let ids = coins.compactMap { ($0["item"] as? [String: Any])?["id"] as? String }
        guard !ids.isEmpty else { return [] }

        var components = URLComponents(string: "https://api.coingecko.com/api/v3/coins/markets")!
        components.queryItems = [
            URLQueryItem(name: "vs_currency", value: "usd"),
            URLQueryItem(name: "ids", value: ids.prefix(15).joined(separator: ",")),
            URLQueryItem(name: "sparkline", value: "false"),
            URLQueryItem(name: "price_change_percentage", value: "24h"),
        ]
        let marketsData = try await get(components.url!)
        return try parseMarkets(marketsData, category: .onChain)
    }

    private static func fetchSafely(
        label: String,
        work: () async throws -> [MarketToken]
    ) async -> [MarketToken]? {
        do {
            let items = try await work()
            log.info("\(label) ok: \(items.count) tokens")
            return items
        } catch {
            lastError = error.localizedDescription
            log.error("\(label) failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private static func get(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        if http.statusCode == 429 {
            throw URLError(.resourceUnavailable, userInfo: [
                NSLocalizedDescriptionKey: "CoinGecko 請求過於頻繁，請稍後再試",
            ])
        }
        guard (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse, userInfo: [
                NSLocalizedDescriptionKey: "HTTP \(http.statusCode)",
            ])
        }
        return data
    }

    private static func parseMarkets(_ data: Data, category: MarketTokenCategory) throws -> [MarketToken] {
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return rows.compactMap { row in parseRow(row, category: category) }
    }

    private static func parseRow(_ row: [String: Any], category: MarketTokenCategory) -> MarketToken? {
        guard let cgId = row["id"] as? String,
              let symbol = row["symbol"] as? String,
              let name = row["name"] as? String else { return nil }

        let price = (row["current_price"] as? Double) ?? 0
        let change = (row["price_change_percentage_24h"] as? Double) ?? 0
        let volume = (row["total_volume"] as? Double) ?? 0
        let image = row["image"] as? String

        return MarketToken(
            id: cgId,
            symbol: symbol.uppercased(),
            name: name,
            contractAddress: SepoliaTokenRegistry.contractAddress(coingeckoId: cgId) ?? "",
            priceUSD: Decimal(price),
            change24hPercent: change,
            volume24hUSD: Decimal(volume),
            category: category,
            walletBalance: nil,
            imageURL: image
        )
    }

    /// 將鏈上持倉餘額寫入行情列表（Sepolia 錢包）
    @MainActor
    static func mergeWalletBalances(into tokens: [MarketToken]) async -> [MarketToken] {
        guard ChainConfig.usesTestnet,
              let address = WalletSession.shared.account?.address,
              let snapshot = try? await WalletOnChainHoldingsService.load(address: address) else {
            return tokens
        }

        var balancesByMarketId: [String: Decimal] = [:]
        for holding in snapshot.holdings {
            guard let marketId = SepoliaSwapTokenCatalog.marketTokenId(forHoldingId: holding.id),
                  let dec = Decimal(string: holding.balance.replacingOccurrences(of: ",", with: "")) else {
                continue
            }
            balancesByMarketId[marketId] = dec
        }

        return tokens.map { token in
            if let balance = balancesByMarketId[token.id] {
                return token.with(walletBalance: balance)
            }
            if token.id == "usd-coin", let vusdc = balancesByMarketId[SepoliaSwapDemoConfig.vUSDCMarketId] {
                return token.with(walletBalance: vusdc)
            }
            return token
        }
    }

    private static func dedupe(_ tokens: [MarketToken]) -> [MarketToken] {
        var seen = Set<String>()
        var out: [MarketToken] = []
        for token in tokens {
            if seen.insert(token.id).inserted {
                out.append(token)
            }
        }
        return out
    }
}

/// API 失敗時的擴充示範列表（含真實圖示 URL）
enum ExpandedMarketCatalog {
    static func fallbackTokens() -> [MarketToken] {
        let specs: [(id: String, sym: String, name: String, cat: MarketTokenCategory, price: Double, vol: Double, chg: Double)] = [
            ("ethereum", "ETH", "Ethereum", .mainstream, 3000, 12e9, 1.5),
            ("bitcoin", "BTC", "Bitcoin", .mainstream, 76000, 25e9, 0.8),
            ("usd-coin", "USDC", "USD Coin", .mainstream, 1, 5e9, 0.01),
            ("tether", "USDT", "Tether", .mainstream, 1, 40e9, 0.02),
            ("chainlink", "LINK", "Chainlink", .mainstream, 14, 400e6, -0.5),
            ("uniswap", "UNI", "Uniswap", .mainstream, 8, 200e6, 2.1),
            ("aave", "AAVE", "Aave", .mainstream, 95, 150e6, 1.2),
            ("dai", "DAI", "Dai", .mainstream, 1, 100e6, 0),
            ("wrapped-bitcoin", "WBTC", "Wrapped Bitcoin", .mainstream, 76000, 200e6, 0.7),
            ("pepe", "PEPE", "Pepe", .onChain, 0.00001, 800e6, 5.2),
            ("dogecoin", "DOGE", "Dogecoin", .onChain, 0.15, 1e9, 3.1),
            ("shiba-inu", "SHIB", "Shiba Inu", .onChain, 0.00002, 500e6, 2.8),
            ("bonk", "BONK", "Bonk", .onChain, 0.00002, 300e6, 4.5),
            ("floki", "FLOKI", "FLOKI", .onChain, 0.0001, 120e6, 6.0),
            ("render-token", "RNDR", "Render", .onChain, 7, 90e6, 1.8),
            ("fetch-ai", "FET", "Artificial Superintelligence Alliance", .onChain, 1.2, 80e6, -1.2),
            ("the-graph", "GRT", "The Graph", .onChain, 0.2, 60e6, 0.5),
            ("arbitrum", "ARB", "Arbitrum", .mainstream, 0.8, 200e6, 1.1),
            ("optimism", "OP", "Optimism", .mainstream, 1.5, 150e6, 0.9),
            ("polygon-ecosystem-token", "POL", "Polygon", .mainstream, 0.4, 180e6, -0.3),
        ]

        return specs.map { s in
            MarketToken(
                id: s.id,
                symbol: s.sym,
                name: s.name,
                contractAddress: SepoliaTokenRegistry.contractAddress(coingeckoId: s.id) ?? "",
                priceUSD: Decimal(s.price),
                change24hPercent: s.chg,
                volume24hUSD: Decimal(s.vol),
                category: s.cat,
                walletBalance: nil,
                imageURL: TokenLogoCatalog.url(for: TokenLogoCatalog.tokenId(fromCoingeckoId: s.id))?.absoluteString
            )
        }
    }
}

/// Sepolia 測試網常見合約（展示用）
enum SepoliaTokenRegistry {
    static func contractAddress(coingeckoId: String) -> String? {
        let map: [String: String] = [
            "ethereum": "0x0000000000000000000000000000000000000000",
            "usd-coin": "0x1c7D4B196Cb0C7B19694695c6190F8A4a4a4a4a4",
            "chainlink": "0x779877A7B0D9E8603169Ddb44Eb52e8e0d1c1c1c",
        ]
        return map[coingeckoId]
    }
}
