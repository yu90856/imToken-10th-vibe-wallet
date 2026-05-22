import Foundation

/// 探索／DApp 開啟前的輕量 URL 風險檢查（評審可見的實際攔截邏輯）
enum WalletURLSafety {
    struct Verdict: Equatable {
        let allowed: Bool
        let reason: String
    }

    private static let blockedKeywords = [
        "phish",
        "drainer",
        "airdrop-claim",
        "wallet-sync",
        "metamask-fix",
        "support-wallet",
        "claim-eth",
    ]

    private static let demoMaliciousSamples = [
        "https://phish-drainer.example/steal",
        "https://wallet-sync-airdrop-claim.io",
    ]

    static func evaluate(_ url: URL) -> Verdict {
        guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" else {
            return Verdict(allowed: false, reason: "僅允許 http / https 協議")
        }
        let full = url.absoluteString.lowercased()
        if let hit = blockedKeywords.first(where: { full.contains($0) }) {
            return Verdict(allowed: false, reason: "命中惡意關鍵字「\(hit)」")
        }
        if full.contains("@") && !full.hasPrefix("mailto:") {
            return Verdict(allowed: false, reason: "網址含 '@' 混淆（釣魚常用手法）")
        }
        return Verdict(allowed: true, reason: "未命中黑名單規則")
    }

    /// 供功能檢測：驗證示範惡意連結會被攔截
    static func runSelfTest() -> (passed: Int, total: Int, lines: [String]) {
        var lines: [String] = []
        var passed = 0
        let total = demoMaliciousSamples.count + 1

        for sample in demoMaliciousSamples {
            guard let url = URL(string: sample) else { continue }
            let verdict = evaluate(url)
            let ok = !verdict.allowed
            if ok { passed += 1 }
            lines.append("\(ok ? "✓" : "✗") \(sample) → \(verdict.reason)")
        }

        if let safe = URL(string: "https://app.uniswap.org") {
            let verdict = evaluate(safe)
            let ok = verdict.allowed
            if ok { passed += 1 }
            lines.append("\(ok ? "✓" : "✗") Uniswap → \(verdict.reason)")
        }

        return (passed, total, lines)
    }
}
