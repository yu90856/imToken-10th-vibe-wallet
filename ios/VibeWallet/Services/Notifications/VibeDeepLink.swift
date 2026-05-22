import Foundation

extension Notification.Name {
    static let vibeOpenDeepLink = Notification.Name("vibeOpenDeepLink")
}

enum VibeDeepLink: Equatable {
    case bitrefillShop(query: String)
    case wallet

    static func from(userInfo: [AnyHashable: Any]) -> VibeDeepLink? {
        let tab = userInfo[VibeNotificationDeepLink.tab] as? String
        switch tab {
        case "shop":
            let query = (userInfo[VibeNotificationDeepLink.shopQuery] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return query.isEmpty ? .bitrefillShop(query: "gift") : .bitrefillShop(query: query)
        case "wallet":
            return .wallet
        default:
            return nil
        }
    }
}
