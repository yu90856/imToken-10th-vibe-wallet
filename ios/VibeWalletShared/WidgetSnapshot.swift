import Foundation

/// App 與 Widget 共用的快照（App Group UserDefaults）
struct WidgetSnapshot: Codable, Sendable {
    var updatedAt: Date
    var marketRows: [WidgetMarketRow]
    var bitrefillRows: [WidgetBitrefillRow]

    static let empty = WidgetSnapshot(updatedAt: .distantPast, marketRows: [], bitrefillRows: [])
}

struct WidgetMarketRow: Codable, Sendable, Identifiable {
    var id: String
    var symbol: String
    var priceText: String
    var changeText: String
    var changeIsPositive: Bool
}

struct WidgetBitrefillRow: Codable, Sendable, Identifiable {
    var id: String
    var name: String
    var countryName: String
    var searchQuery: String
}

enum WidgetDataStore {
    static let appGroupID = "group.com.vibe.wallet"
    private static let snapshotKey = "widget.snapshot.v1"

    static func load() -> WidgetSnapshot {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: snapshotKey),
              let decoded = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return .empty
        }
        return decoded
    }

    static func save(_ snapshot: WidgetSnapshot) {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
    }
}
