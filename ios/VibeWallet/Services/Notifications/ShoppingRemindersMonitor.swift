import EventKit
import Foundation

/// 監聽「Vibe 購物」提醒事項新增，並在 Bitrefill 有貨時推播
@MainActor
final class ShoppingRemindersMonitor {
    static let shared = ShoppingRemindersMonitor()

    private let defaults = UserDefaults.standard
    private let baselineKey = "notifications.shopping.baselineDone"
    private let knownIDsKey = "notifications.shopping.knownIDs"

    private var observer: NSObjectProtocol?
    private var isChecking = false

    private init() {}

    func start() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.checkForNewReminders()
            }
        }
        Task { await checkForNewReminders() }
    }

    func stop() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
    }

    func checkForNewReminders() async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        let granted = await ShoppingRemindersService.requestAccessIfNeeded()
        guard granted else { return }

        let items: [ShoppingReminderItem]
        do {
            items = try await ShoppingRemindersService.fetchAllIncompleteItems()
        } catch {
            return
        }

        var known = Set(defaults.stringArray(forKey: knownIDsKey) ?? [])
        let currentIDs = Set(items.map(\.id))

        if !defaults.bool(forKey: baselineKey) {
            known = currentIDs
            defaults.set(true, forKey: baselineKey)
            defaults.set(Array(known), forKey: knownIDsKey)
            return
        }

        let newItems = items.filter { !known.contains($0.id) }
        guard !newItems.isEmpty else {
            known = currentIDs
            defaults.set(Array(known), forKey: knownIDsKey)
            return
        }

        _ = await VibeNotificationService.requestAuthorizationIfNeeded()

        for item in newItems {
            let query = item.searchQuery
            guard !query.isEmpty else { continue }
            switch await BitrefillCatalogService.search(query: query, limit: 3) {
            case .success(let products):
                let matches = products.filter(\.inStock)
                if !matches.isEmpty {
                    await VibeNotificationService.notifyBitrefillMatch(
                        reminderTitle: item.title,
                        query: query,
                        products: matches
                    )
                }
            case .failure:
                break
            }
        }

        known.formUnion(currentIDs)
        defaults.set(Array(known), forKey: knownIDsKey)
    }
}
