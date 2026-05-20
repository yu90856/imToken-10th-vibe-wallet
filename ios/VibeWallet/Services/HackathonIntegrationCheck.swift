import Foundation

/// 評審用：一鍵驗證本 App 是否實際串接 GitHub 開源元件與即時服務
enum HackathonIntegrationCheck {
    struct Result: Identifiable, Sendable {
        enum Status: String, Sendable {
            case pass
            case fail
            case info
        }

        let id: String
        let title: String
        let repo: String
        let status: Status
        let detail: String
    }

    @MainActor
    static func runAll(hasWallet: Bool) async -> [Result] {
        var results: [Result] = []

        results.append(await checkTokenCore())
        results.append(checkTokenCoreBundle())
        results.append(await checkCoinGecko())
        results.append(await checkCryptoNews())
        results.append(checkSepolia())
        results.append(checkDAppBrowser())
        results.append(checkSecuritySkill())
        results.append(checkFaceID())
        results.append(checkWalletKeystore(hasWallet: hasWallet))
        results.append(checkContactRecovery())
        results.append(checkDuressMode())

        return results
    }

    // MARK: - Checks

    @MainActor
    private static func checkTokenCore() async -> Result {
        let id = "token-core"
        do {
            try await TokenCoreBridge.shared.ensureReady()
            let valid = await TokenCoreService.isValidMnemonic(
                "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
            )
            if valid {
                return Result(
                    id: id,
                    title: "Token Core WASM 就緒",
                    repo: "consenlabs/token-core-monorepo",
                    status: .pass,
                    detail: "WKWebView 已載入 tcx-wasm，助記詞校驗通過（測試向量）。"
                )
            }
            return Result(
                id: id,
                title: "Token Core WASM 就緒",
                repo: "consenlabs/token-core-monorepo",
                status: .fail,
                detail: "WASM 已載入，但助記詞校驗未通過。"
            )
        } catch {
            return Result(
                id: id,
                title: "Token Core WASM 就緒",
                repo: "consenlabs/token-core-monorepo",
                status: .fail,
                detail: error.localizedDescription
            )
        }
    }

    private static func checkTokenCoreBundle() -> Result {
        let wasm = TokenCoreSchemeHandler.loadBundledFile(named: "tcx_wasm_bg.wasm")
        let js = TokenCoreSchemeHandler.loadBundledFile(named: "tcx_wasm.js")
        let ok = wasm != nil && js != nil
        let size = wasm?.count ?? 0
        return Result(
            id: "token-core-bundle",
            title: "Token Core 資源已打包",
            repo: "consenlabs/token-core-monorepo",
            status: ok ? .pass : .fail,
            detail: ok
                ? "tcx_wasm_bg.wasm（\(size / 1024) KB）+ tcx_wasm.js 已內嵌 App。"
                : "缺少 WASM，請執行 ios/scripts/sync-token-core-ios.sh"
        )
    }

    private static func checkCoinGecko() async -> Result {
        let tokens = await CoinGeckoMarketService.refreshIfNeeded(force: true)
        let source = CoinGeckoMarketService.dataSourceLabel
        let ok = tokens.count >= 8 && source.contains("CoinGecko")
        return Result(
            id: "coingecko",
            title: "CoinGecko 行情 API",
            repo: "coingecko/api (公開端點)",
            status: ok ? .pass : .fail,
            detail: "\(source) · 共 \(tokens.count) 檔代幣"
        )
    }

    private static func checkCryptoNews() async -> Result {
        let news = await CryptoNewsService.fetchRecentNews(limit: 1)
        let ok = !news.isEmpty
        return Result(
            id: "cryptocompare",
            title: "CryptoCompare 新聞 API",
            repo: "cryptocompare/api",
            status: ok ? .pass : .fail,
            detail: ok
                ? "已取得：\(news[0].title.prefix(40))…"
                : "無法取得新聞（可能離線或 API 限流）"
        )
    }

    private static func checkSepolia() -> Result {
        let chain = ChainConfig.active
        let ok = ChainConfig.usesTestnet && chain.isTestnet && chain.id == 11155111
        return Result(
            id: "sepolia",
            title: "Sepolia 測試網",
            repo: "以太坊 Sepolia",
            status: ok ? .pass : .info,
            detail: "\(chain.name) · chainId \(chain.id) · \(chain.rpcURL)"
        )
    }

    private static func checkDAppBrowser() -> Result {
        let ok = ChainConfig.active.chainIdHex == "0xaa36a7"
        return Result(
            id: "dapp-browser",
            title: "DApp 瀏覽器 EIP-1193",
            repo: "探索 · 內建 WKWebView",
            status: ok ? .pass : .info,
            detail: "注入 window.ethereum · chainId \(ChainConfig.active.chainIdHex) · 可連 Uniswap / thirdweb"
        )
    }

    private static func checkSecuritySkill() -> Result {
        Result(
            id: "security-skill",
            title: "Security Skill 規範",
            repo: "consenlabs/token-ui/security",
            status: .info,
            detail: "倉庫含 security/SKILL.md；助記詞／簽名流程依測試網與本機 Keychain 實作。"
        )
    }

    private static func checkFaceID() -> Result {
        let ok = TransactionAuthService.canUseBiometry
        return Result(
            id: "face-id",
            title: "Face ID / 生物辨識",
            repo: "LocalAuthentication",
            status: ok ? .pass : .info,
            detail: ok
                ? "可用於 App 鎖定與交易確認"
                : TransactionAuthService.biometryUnavailableMessage
        )
    }

    private static func checkWalletKeystore(hasWallet: Bool) -> Result {
        let hasKeystore = WalletKeychainStore.loadKeystoreJSON() != nil
        let ok = hasWallet ? hasKeystore : true
        return Result(
            id: "wallet",
            title: "本機錢包 Keystore",
            repo: "Token Core createKeystore",
            status: ok ? .pass : .fail,
            detail: hasWallet
                ? (hasKeystore ? "Keychain 已儲存加密 keystore" : "顯示有錢包但 Keychain 無 keystore")
                : "尚未建立錢包（可略過）"
        )
    }

    private static func checkContactRecovery() -> Result {
        let store = ContactRecoveryStore.shared
        return Result(
            id: "contact-recovery",
            title: "聯絡人解鎖",
            repo: "Vibe Wallet 自訂",
            status: store.isConfigured ? .pass : .info,
            detail: store.isConfigured
                ? "已設定 \(store.hintCount) 組提示詞（支援中文）"
                : "尚未設定（設定 → 聯絡人解鎖）"
        )
    }

    private static func checkDuressMode() -> Result {
        let on = SecuritySettingsStore.shared.duressProtectionEnabled
        return Result(
            id: "duress",
            title: "脅迫防護（假錢包）",
            repo: "Vibe Wallet 自訂",
            status: on ? .pass : .info,
            detail: on
                ? "已啟用 · 解鎖後可進入假錢包"
                : "未啟用"
        )
    }
}
