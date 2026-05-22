import Foundation
import UserNotifications

/// 評審／開發：排程 5 秒後的本地推播，方便回桌面驗證點擊跳轉
@MainActor
enum NotificationTestBench {
    enum Kind: String, CaseIterable, Identifiable {
        case walletReceive
        case walletSend
        case shopping

        var id: String { rawValue }

        var title: String {
            switch self {
            case .walletReceive: return "模擬鏈上收款"
            case .walletSend: return "模擬鏈上轉出"
            case .shopping: return "模擬購物待辦 Bitrefill"
            }
        }

        var instruction: String {
            switch self {
            case .walletReceive: return "5 秒後推播「收到 ETH」· 點擊進入錢包 Tab"
            case .walletSend: return "5 秒後推播「已發送」· 點擊進入錢包 Tab"
            case .shopping: return "5 秒後推播 Bitrefill 商品 · 點擊進入商店搜尋"
            }
        }
    }

    private static let delay: TimeInterval = 5

    static func schedule(_ kind: Kind) async -> String {
        guard await VibeNotificationService.requestAuthorizationIfNeeded() else {
            return "請先在系統設定允許 Vibe Wallet 通知。"
        }

        let content = UNMutableNotificationContent()
        content.sound = .default

        switch kind {
        case .walletReceive:
            content.title = "收到 \(ChainConfig.active.symbol)"
            content.body = "+0.012500 ETH · ← 0xabcd…1234"
            content.categoryIdentifier = VibeNotificationCategory.wallet.rawValue
            content.userInfo = [VibeNotificationDeepLink.tab: "wallet"]
        case .walletSend:
            content.title = "已發送 \(ChainConfig.active.symbol)"
            content.body = "-0.005000 ETH · Tx 0x12ab…9f00"
            content.categoryIdentifier = VibeNotificationCategory.wallet.rawValue
            content.userInfo = [VibeNotificationDeepLink.tab: "wallet"]
        case .shopping:
            content.title = "Bitrefill 有「eSIM 出國」相關商品"
            content.body = "Airalo eSIM · Global · 點一下前往選購"
            content.categoryIdentifier = VibeNotificationCategory.shopping.rawValue
            content.userInfo = [
                VibeNotificationDeepLink.tab: "shop",
                VibeNotificationDeepLink.shopQuery: "esim",
            ]
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(
            identifier: "test.\(kind.rawValue).\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            return "已排程：約 \(Int(delay)) 秒後送出。請按 Home 鍵回到桌面等待通知，再點通知驗證跳轉。"
        } catch {
            return "排程失敗：\(error.localizedDescription)"
        }
    }
}
