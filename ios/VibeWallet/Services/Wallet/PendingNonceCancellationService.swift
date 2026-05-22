import Foundation

struct PendingNonceCancelResult: Sendable {
    let clearedCount: Int
    let transactionHashes: [String]
}

enum PendingNonceCancelError: LocalizedError {
    case walletNotReady
    case nothingToCancel
    case insufficientGas(have: Decimal, need: Decimal, address: String)
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .walletNotReady:
            return "找不到錢包 Keystore，請重新建立或匯入錢包。"
        case .nothingToCancel:
            return "目前沒有待確認交易，無需清除。"
        case .insufficientGas(let have, let need, let address):
            return """
            \(shortAddress(address)) Sepolia ETH 不足，無法支付清除 Pending 的 Gas。
            目前 \(format(have)) ETH，預估至少 \(format(need)) ETH。
            """
        case .failed(let message):
            return message
        }
    }

    private func shortAddress(_ address: String) -> String {
        guard address.count > 12 else { return address }
        return "\(address.prefix(6))…\(address.suffix(4))"
    }

    private func format(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 6
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "\(value)"
    }
}

/// 以 0 ETH 自轉 + 較高 Gas 取代 mempool 中的待確認交易（標準 cancel 做法）。
enum PendingNonceCancellationService {
    private static let maxCancelsPerRun = 5
    private static let emptyTransferGasLimit: UInt64 = 21_000

    @MainActor
    static func cancelAllPending(
        walletPassword: String,
        displayAddress: String?
    ) async throws -> PendingNonceCancelResult {
        guard let keystoreJSON = WalletKeychainStore.loadKeystoreJSON() else {
            throw PendingNonceCancelError.walletNotReady
        }

        let context = try await TokenCoreService.resolveSigningContext(
            keystoreJSON: keystoreJSON,
            password: walletPassword,
            preferredAddress: displayAddress ?? WalletKeychainStore.loadAddress()
        )
        let signingAddress = context.address
        WalletSession.shared.applyVerifiedSigningAddress(signingAddress)

        try await TokenCoreBridge.shared.ensureReady()

        let initialGap = try await pendingGap(address: signingAddress)
        guard initialGap > 0 else {
            throw PendingNonceCancelError.nothingToCancel
        }

        var txHashes: [String] = []
        for _ in 0..<maxCancelsPerRun {
            let gap = try await pendingGap(address: signingAddress)
            if gap == 0 { break }

            let nonce = try await ChainRPCClient.fetchTransactionCount(
                address: signingAddress,
                block: "latest"
            )
            let gasPrice = try await boostedGasPrice()
            try await assertAffordableCancel(
                address: signingAddress,
                gasLimit: emptyTransferGasLimit,
                gasPrice: gasPrice
            )

            let signed = try await TokenCoreService.signEthereumLegacyTransaction(
                keystoreJSON: keystoreJSON,
                password: walletPassword,
                to: signingAddress,
                valueWei: 0,
                data: "0x",
                nonce: nonce,
                gasLimit: emptyTransferGasLimit,
                gasPrice: gasPrice,
                chainId: ChainConfig.active.id,
                tcxNetwork: context.tcxNetwork
            )

            let txHash: String
            do {
                txHash = try await ChainRPCClient.sendRawTransactionReliable(signedRaw: signed.rawTransaction)
                try await ChainRPCClient.waitForTransactionSuccess(txHash: txHash, timeoutSeconds: 120)
            } catch let error as ChainRPCError {
                throw PendingNonceCancelError.failed(
                    error.localizedDescription ?? "廣播或確認失敗"
                )
            }
            txHashes.append(txHash)
        }

        let remaining = try await pendingGap(address: signingAddress)
        if remaining > 0 {
            throw PendingNonceCancelError.failed(
                "已送出 \(txHashes.count) 筆取代交易，仍有 \(remaining) 筆待確認。請稍後再按「清除 Pending」，或到 Etherscan 手動處理。"
            )
        }

        return PendingNonceCancelResult(
            clearedCount: txHashes.count,
            transactionHashes: txHashes
        )
    }

    private static func pendingGap(address: String) async throws -> UInt64 {
        let latest = try await ChainRPCClient.fetchTransactionCount(address: address, block: "latest")
        let pending = try await ChainRPCClient.fetchTransactionCount(address: address, block: "pending")
        return pending > latest ? pending - latest : 0
    }

    /// 取消 Pending 再額外加成，確保能取代舊交易。
    private static func boostedGasPrice() async throws -> UInt64 {
        let base = try await ChainRPCClient.fetchGasPrice()
        return base + base / 2 + 3_000_000_000
    }

    private static func assertAffordableCancel(
        address: String,
        gasLimit: UInt64,
        gasPrice: UInt64
    ) async throws {
        let cost = Decimal(gasLimit) * Decimal(gasPrice)
        let balance = try await ChainRPCClient.fetchNativeBalanceWeiDecimal(address: address)
        guard balance >= cost else {
            throw PendingNonceCancelError.insufficientGas(
                have: EVMWeiFormatter.weiToEther(balance),
                need: EVMWeiFormatter.weiToEther(cost),
                address: address
            )
        }
    }
}
