import Foundation

enum WalletTransferError: LocalizedError {
    case walletNotReady
    case tokenNotSupported
    case invalidAddress
    case invalidAmount
    case insufficientBalance
    case insufficientGas

    var errorDescription: String? {
        switch self {
        case .walletNotReady: return "請先建立或匯入錢包"
        case .tokenNotSupported: return "此代幣暫不支援 App 內轉出"
        case .invalidAddress: return "收款地址格式不正確（需為 0x 開頭的 42 字元）"
        case .invalidAmount: return "請輸入大於 0 的數量"
        case .insufficientBalance: return "持倉餘額不足"
        case .insufficientGas: return "原生幣（ETH）不足，無法支付 Gas"
        }
    }
}

/// 持倉代幣轉出（Sepolia 原生 ETH + 演示 ERC-20）
enum WalletTransferService {
    enum AssetKind: Sendable {
        case nativeETH
        case erc20(contract: String, symbol: String)
    }

    static func assetKind(for holdingId: String) -> AssetKind? {
        switch holdingId {
        case "eth-native":
            return .nativeETH
        case "puffer-pufeth":
            guard PufferDemoConfig.hasOnChainVault else { return nil }
            return .erc20(contract: PufferDemoConfig.sepoliaVaultAddress, symbol: PufferDemoConfig.pufETHSymbol)
        case SepoliaSwapDemoConfig.vUSDCMarketId:
            guard SepoliaSwapDemoConfig.hasOnChainSwap else { return nil }
            return .erc20(contract: SepoliaSwapDemoConfig.contractAddress, symbol: SepoliaSwapDemoConfig.vUSDCSymbol)
        default:
            return nil
        }
    }

    static func isValidRecipient(_ address: String) -> Bool {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("0x"), trimmed.count == 42 else { return false }
        let hex = String(trimmed.dropFirst(2))
        return hex.count == 40 && hex.allSatisfy(\.isHexDigit)
    }

    @MainActor
    static func balance(for holdingId: String, walletAddress: String) async -> Decimal {
        switch assetKind(for: holdingId) {
        case .nativeETH:
            return (try? await ChainRPCClient.fetchNativeBalance(address: walletAddress)) ?? 0
        case .erc20(let contract, _):
            return (try? await ChainRPCClient.fetchERC20BalanceOf(
                userAddress: walletAddress,
                tokenContract: contract
            )) ?? 0
        case nil:
            return 0
        }
    }

    @MainActor
    static func send(
        holdingId: String,
        toAddress: String,
        amount: Decimal,
        walletAddress: String,
        walletPassword: String
    ) async throws -> String {
        guard let keystoreJSON = WalletKeychainStore.loadKeystoreJSON() else {
            throw WalletTransferError.walletNotReady
        }
        let recipient = toAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidRecipient(recipient) else { throw WalletTransferError.invalidAddress }
        guard amount > 0 else { throw WalletTransferError.invalidAmount }
        guard let kind = assetKind(for: holdingId) else { throw WalletTransferError.tokenNotSupported }

        try await TokenCoreBridge.shared.ensureReady()

        let available = await balance(for: holdingId, walletAddress: walletAddress)
        guard available >= amount else { throw WalletTransferError.insufficientBalance }

        switch kind {
        case .nativeETH:
            let reserve = SepoliaSwapDemoConfig.gasReserveEther
            guard available >= amount + reserve else { throw WalletTransferError.insufficientBalance }
            let valueWei = EVMWeiFormatter.etherToWei(amount)
            guard valueWei > 0 else { throw WalletTransferError.invalidAmount }
            return try await signAndSend(
                keystoreJSON: keystoreJSON,
                password: walletPassword,
                walletAddress: walletAddress,
                to: recipient,
                valueWei: valueWei,
                data: "0x"
            )

        case .erc20(let contract, _):
            let ethBal = try await ChainRPCClient.fetchNativeBalance(address: walletAddress)
            guard ethBal >= SepoliaSwapDemoConfig.gasReserveEther else {
                throw WalletTransferError.insufficientGas
            }
            let amountWei = EVMWeiFormatter.etherToWei(amount)
            guard amountWei > 0 else { throw WalletTransferError.invalidAmount }
            let data = encodeERC20Transfer(to: recipient, amountWei: amountWei)
            return try await signAndSend(
                keystoreJSON: keystoreJSON,
                password: walletPassword,
                walletAddress: walletAddress,
                to: contract,
                valueWei: 0,
                data: data
            )
        }
    }

    private static func encodeERC20Transfer(to address: String, amountWei: UInt64) -> String {
        let selector = "a9059cbb"
        let addr = address.lowercased().replacingOccurrences(of: "0x", with: "")
        return "0x\(selector)\(String(repeating: "0", count: 24))\(addr)\(EVMWeiFormatter.uint256HexData(amountWei))"
    }

    private static func signAndSend(
        keystoreJSON: String,
        password: String,
        walletAddress: String,
        to: String,
        valueWei: UInt64,
        data: String
    ) async throws -> String {
        let nonce = try await ChainRPCClient.fetchTransactionCount(address: walletAddress)
        let gasPrice = try await ChainRPCClient.fetchGasPrice()
        let gasLimit = try await ChainRPCClient.estimateGas(
            from: walletAddress,
            to: to,
            valueWei: valueWei,
            data: data
        )
        let signed = try await TokenCoreService.signEthereumLegacyTransaction(
            keystoreJSON: keystoreJSON,
            password: password,
            to: to,
            valueWei: valueWei,
            data: data,
            nonce: nonce,
            gasLimit: gasLimit,
            gasPrice: gasPrice
        )
        let hash = try await ChainRPCClient.sendRawTransactionReliable(signedRaw: signed.rawTransaction)
        try await ChainRPCClient.waitForTransactionSuccess(txHash: hash)
        NotificationCenter.default.post(name: .walletBalancesDidChange, object: nil)
        return hash
    }
}
