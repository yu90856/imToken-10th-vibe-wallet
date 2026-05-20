import Foundation

/// CoinGecko 圖示（靜態備援 + id 對照）
enum TokenLogoCatalog {
    private static let coingeckoToTokenId: [String: String] = [
        "ethereum": "eth",
        "bitcoin": "btc",
        "usd-coin": "usdc",
        "tether": "usdt",
        "wrapped-bitcoin": "wbtc",
        "chainlink": "link",
        "uniswap": "uni",
        "aave": "aave",
        "dai": "dai",
        "pepe": "pepe",
        "dogecoin": "doge",
        "shiba-inu": "shib",
        "bonk": "bonk",
        "floki": "floki",
        "lido-staked-ether": "steth",
    ]

    private static let urls: [String: String] = [
        "eth": "https://assets.coingecko.com/coins/images/279/small/ethereum.png",
        "btc": "https://assets.coingecko.com/coins/images/1/small/bitcoin.png",
        "usdt": "https://assets.coingecko.com/coins/images/325/small/Tether.png",
        "usdc": "https://assets.coingecko.com/coins/images/6319/small/usdc.png",
        "link": "https://assets.coingecko.com/coins/images/877/small/chainlink-new-logo.png",
        "uni": "https://assets.coingecko.com/coins/images/12504/small/uniswap-logo.png",
        "aave": "https://assets.coingecko.com/coins/images/12645/small/aave-token-round.png",
        "dai": "https://assets.coingecko.com/coins/images/9956/small/Badge_Dai.png",
        "pepe": "https://assets.coingecko.com/coins/images/29850/small/pepe-token.jpeg",
        "doge": "https://assets.coingecko.com/coins/images/5/small/dogecoin.png",
        "shib": "https://assets.coingecko.com/coins/images/11939/small/shiba.png",
        "bonk": "https://assets.coingecko.com/coins/images/28600/small/bonk.jpg",
        "weth": "https://assets.coingecko.com/coins/images/279/small/ethereum.png",
        "wbtc": "https://assets.coingecko.com/coins/images/7598/small/wrapped_bitcoin_wbtc.png",
        "bnb": "https://assets.coingecko.com/coins/images/825/small/bnb-icon2_2x.png",
    ]

    static func tokenId(fromCoingeckoId id: String) -> String {
        coingeckoToTokenId[id] ?? id.replacingOccurrences(of: "-", with: "")
    }

    static func url(for tokenId: String) -> URL? {
        if let raw = urls[tokenId] { return URL(string: raw) }
        return nil
    }

    static func url(from imageURLString: String?) -> URL? {
        guard let imageURLString, let url = URL(string: imageURLString) else { return nil }
        return url
    }
}
