import Foundation

enum MockCryptoNewsService {
    /// 近 6 小時內、討論度最高的三則幣圈消息（示範資料）
    static func topHotNews(withinHours: Int = 6, limit: Int = 3) -> [CryptoHotNewsItem] {
        let now = Date()
        let all: [CryptoHotNewsItem] = [
            CryptoHotNewsItem(
                id: "eth-etf-flow",
                title: "ETH 現貨 ETF 淨流入連三日為正",
                summary: "機構資金回流 L1，Gas 與質押話題升溫。",
                body: """
                鏈上監測顯示過去 72 小時以太坊現貨 ETF 淨流入轉正，社群討論聚焦「L1 敘事是否回歸」。\
                分析師指出若流入持續，可能帶動 Sepolia / 主網測試活動與 L2 橋接量，但短期仍受總經與美元流動性影響。\
                本則為示範熱門消息，非投資建議。
                """,
                publishedAt: now.addingTimeInterval(-2 * 3600),
                discussionScore: 4_820,
                source: "CryptoPulse",
                articleURL: nil
            ),
            CryptoHotNewsItem(
                id: "sepolia-faucet",
                title: "Sepolia 測試幣水龍頭排隊時間拉長",
                summary: "開發者社群分享多個備用水龍頭與防 Sybil 技巧。",
                body: """
                隨著黑客松與 AA 錢包原型增加，Sepolia ETH 水龍頭在高峰時段常需排隊。\
                社群整理 Google Cloud、Chainlink、Alchemy 等入口，並提醒測試網資產無實值、勿與主網地址混淆。\
                Vibe Wallet 用戶可在錢包頁底部快速領水。
                """,
                publishedAt: now.addingTimeInterval(-3.5 * 3600),
                discussionScore: 3_150,
                source: "DevETH Weekly",
                articleURL: nil
            ),
            CryptoHotNewsItem(
                id: "uniswap-v4",
                title: "Uniswap v4 Hook 模組化引發 DEX 討論",
                summary: "自訂池邏輯與 MEV 防護成為 DeFi 焦點。",
                body: """
                Uniswap v4 的 Hook 設計讓流動性池可嵌入自訂邏輯，社群熱議對聚合器路由、MEV 與錢包簽名體驗的影響。\
                多數觀點認為終端用戶仍需要更清晰的交易預覽與硬體級確認（如 Passkey / Face ID）。\
                本 App 交換頁目前為示範 UI，尚未連接真實路由。
                """,
                publishedAt: now.addingTimeInterval(-5 * 3600),
                discussionScore: 2_940,
                source: "DeFi Notebook",
                articleURL: nil
            ),
            CryptoHotNewsItem(
                id: "btc-halving-after",
                title: "BTC 減半後礦工拋壓話題降溫",
                summary: "市場注意力轉向 ETH 質押與 L2 費用。",
                body: "較舊消息，用於過濾示範。",
                publishedAt: now.addingTimeInterval(-9 * 3600),
                discussionScore: 900,
                source: "ChainBrief",
                articleURL: nil
            ),
        ]

        let cutoff = now.addingTimeInterval(-Double(withinHours) * 3600)
        return all
            .filter { $0.publishedAt >= cutoff }
            .sorted { $0.discussionScore > $1.discussionScore }
            .prefix(limit)
            .map { $0 }
    }
}
