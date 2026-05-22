import Foundation
import Observation

/// 全 App 共用鏈上餘額快取，避免切換 Deck 時先閃示 Mock 再變成真實數字
@MainActor
@Observable
final class WalletBalanceStore {
    static let shared = WalletBalanceStore()

    private(set) var snapshot: WalletOnChainSnapshot?
    private(set) var isLoading = false
    private(set) var lastError: String?

    private var loadGeneration = 0
    private var lastFetchedAt: Date?
    private let minRefreshInterval: TimeInterval = 25

    nonisolated private init() {}

    var hasDisplayableSnapshot: Bool { snapshot != nil }

    func refresh(force: Bool = false) async {
        guard ChainConfig.usesTestnet,
              let address = WalletSession.shared.account?.address else {
            return
        }

        if !force,
           let lastFetchedAt,
           Date().timeIntervalSince(lastFetchedAt) < minRefreshInterval,
           snapshot != nil {
            return
        }

        let generation = loadGeneration + 1
        loadGeneration = generation
        isLoading = true
        lastError = nil

        defer {
            if generation == loadGeneration {
                isLoading = false
            }
        }

        do {
            let loaded = try await WalletOnChainHoldingsService.load(address: address)
            guard generation == loadGeneration else { return }
            snapshot = loaded
            lastFetchedAt = Date()
        } catch {
            guard generation == loadGeneration else { return }
            lastError = error.localizedDescription
        }
    }

    func clear() {
        snapshot = nil
        lastFetchedAt = nil
        lastError = nil
        loadGeneration += 1
    }
}
