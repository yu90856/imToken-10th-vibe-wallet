import Foundation

/// 監聽 Sepolia 鏈上轉入／轉出並推播
@MainActor
final class WalletActivityMonitor {
    static let shared = WalletActivityMonitor()

    private let defaults = UserDefaults.standard
    private let baselineKey = "notifications.wallet.txBaselineDone"
    private let knownTxKey = "notifications.wallet.knownTxHashes"

    private var pollTask: Task<Void, Never>?
    private var lastPollAt: Date?
    private let pollInterval: TimeInterval = 45

    private init() {}

    func start() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.pollIfNeeded(force: false)
                try? await Task.sleep(nanoseconds: 30_000_000_000)
            }
        }
        Task { await pollIfNeeded(force: true) }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    func pollIfNeeded(force: Bool) async {
        guard ChainConfig.usesTestnet,
              let address = WalletSession.shared.account?.address,
              !DuressModeController.shared.isDecoyActive else { return }

        if !force,
           let lastPollAt,
           Date().timeIntervalSince(lastPollAt) < pollInterval {
            return
        }
        lastPollAt = Date()

        let txs: [TokenTransaction]
        do {
            txs = try await SepoliaExplorerService.fetchTransactions(walletAddress: address, limit: 12)
        } catch {
            return
        }

        var known = Set(defaults.stringArray(forKey: knownTxKey) ?? [])

        if !defaults.bool(forKey: baselineKey) {
            known = Set(txs.map(\.hash))
            defaults.set(true, forKey: baselineKey)
            defaults.set(Array(known), forKey: knownTxKey)
            return
        }

        let fresh = txs.filter { !known.contains($0.hash) && $0.status == "成功" }
        guard !fresh.isEmpty else { return }

        _ = await VibeNotificationService.requestAuthorizationIfNeeded()

        for tx in fresh.sorted(by: { $0.timestamp > $1.timestamp }).prefix(3) {
            guard tx.kind == .send || tx.kind == .receive else { continue }
            await VibeNotificationService.notifyWalletActivity(
                kind: tx.kind,
                amount: tx.amount,
                symbol: ChainConfig.active.symbol,
                detail: tx.counterparty
            )
        }

        known.formUnion(txs.map(\.hash))
        defaults.set(Array(known.prefix(80)), forKey: knownTxKey)
    }

    /// App 內剛廣播的交易（避免等待輪詢）
    func notifyOutgoingTransfer(holdingId: String, amount: Decimal, txHash: String) async {
        let symbol: String
        switch WalletTransferService.assetKind(for: holdingId) {
        case .nativeETH:
            symbol = ChainConfig.active.symbol
        case .erc20(_, let sym):
            symbol = sym
        case nil:
            symbol = ChainConfig.active.symbol
        }
        let formatted = WalletOnChainHoldingsService.formatAmount(amount)
        await VibeNotificationService.notifyWalletActivity(
            kind: .send,
            amount: "-\(formatted) \(symbol)",
            symbol: symbol,
            detail: "Tx \(shortHash(txHash))"
        )
        var known = Set(defaults.stringArray(forKey: knownTxKey) ?? [])
        known.insert(txHash)
        defaults.set(Array(known.prefix(80)), forKey: knownTxKey)
    }

    private func shortHash(_ hash: String) -> String {
        guard hash.count > 12 else { return hash }
        return "\(hash.prefix(8))…\(hash.suffix(4))"
    }
}
