import Foundation
import UserNotifications

enum VibeNotificationCategory: String {
    case shopping = "vibe.shopping"
    case wallet = "vibe.wallet"
}

enum VibeNotificationDeepLink {
    static let shopQuery = "shopQuery"
    static let productId = "productId"
    static let tab = "tab"
}

@MainActor
enum VibeNotificationService {
    private static let center = UNUserNotificationCenter.current()

    static func configure() {
        registerCategories()
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    @discardableResult
    static func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            return false
        }
    }

    static func notifyBitrefillMatch(
        reminderTitle: String,
        query: String,
        products: [BitrefillProductMatch]
    ) async {
        guard await requestAuthorizationIfNeeded() else { return }
        let inStock = products.filter(\.inStock)
        guard let top = inStock.first else { return }

        let title = "Bitrefill 有「\(reminderTitle)」相關商品"
        let body: String
        if inStock.count > 1 {
            body = "\(top.name) 等 \(inStock.count) 項可購買 · 點一下前往選購"
        } else {
            body = "\(top.name) · \(top.countryName) · 點一下前往選購"
        }

        var userInfo: [AnyHashable: Any] = [
            VibeNotificationDeepLink.tab: "shop",
            VibeNotificationDeepLink.shopQuery: query,
        ]
        if let first = inStock.first {
            userInfo[VibeNotificationDeepLink.productId] = first.id
        }

        await post(
            identifier: "shopping.\(query.hashValue)",
            title: title,
            body: body,
            category: .shopping,
            userInfo: userInfo
        )
    }

    static func notifyWalletActivity(
        kind: TokenTransaction.Kind,
        amount: String,
        symbol: String,
        detail: String?
    ) async {
        guard await requestAuthorizationIfNeeded() else { return }

        let title: String
        let body: String
        switch kind {
        case .receive:
            title = "收到 \(symbol)"
            body = [amount, detail].compactMap { $0 }.joined(separator: " · ")
        case .send:
            title = "已發送 \(symbol)"
            body = [amount, detail].compactMap { $0 }.joined(separator: " · ")
        case .swap:
            title = "鏈上交換完成"
            body = [amount, detail].compactMap { $0 }.joined(separator: " · ")
        case .contract:
            title = "鏈上交易"
            body = [amount, detail].compactMap { $0 }.joined(separator: " · ")
        }

        await post(
            identifier: "wallet.\(UUID().uuidString)",
            title: title,
            body: body,
            category: .wallet,
            userInfo: [VibeNotificationDeepLink.tab: "wallet"]
        )
    }

    private static func registerCategories() {
        let shop = UNNotificationCategory(
            identifier: VibeNotificationCategory.shopping.rawValue,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        let wallet = UNNotificationCategory(
            identifier: VibeNotificationCategory.wallet.rawValue,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([shop, wallet])
    }

    private static func post(
        identifier: String,
        title: String,
        body: String,
        category: VibeNotificationCategory,
        userInfo: [AnyHashable: Any]
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = category.rawValue
        content.userInfo = userInfo

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }
}
