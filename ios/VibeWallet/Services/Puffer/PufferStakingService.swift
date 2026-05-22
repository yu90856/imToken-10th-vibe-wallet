import Foundation

struct PufferStakeResult: Sendable {
    enum Mode: String, Sendable {
        case sepoliaOnChain = "Sepolia 鏈上"
    }

    let mode: Mode
    let ethDeposited: Decimal
    let pufETHMinted: Decimal
    let transactionHash: String
}

struct PufferUnstakeResult: Sendable {
    let pufETHBurned: Decimal
    /// Vault 合約轉出的 ETH（鏈上贖回）
    let ethReceived: Decimal
    /// 錢包 Sepolia ETH 淨增（已扣 Gas）
    let ethNetToWallet: Decimal
    let transactionHash: String
}

enum PufferStakingService {
    static func loadExchangeRate() async -> PufferExchangeRate {
        do {
            return try await PufferAPIService.fetchExchangeRate()
        } catch {
            return PufferAPIService.fallbackExchangeRate
        }
    }

    static func pufETHBalance(address: String) async -> Decimal {
        guard PufferDemoConfig.hasOnChainVault else { return 0 }
        return (try? await ChainRPCClient.fetchDemoVaultPufETHBalance(
            userAddress: address,
            vaultAddress: PufferDemoConfig.sepoliaVaultAddress
        )) ?? 0
    }

    private static func estimatedGasCostETH(gasLimit: UInt64, gasPrice: UInt64) -> Decimal {
        let wei = Decimal(gasLimit) * Decimal(gasPrice)
        return EVMWeiFormatter.weiToEther(wei)
    }

    static func validateStake(
        ethAmount: Decimal,
        signingAddress: String,
        gasLimit: UInt64,
        gasPrice: UInt64
    ) async throws {
        guard ethAmount > 0 else { throw PufferStakeError.invalidAmount }
        guard PufferDemoConfig.hasOnChainVault else {
            throw PufferStakeError.vaultNotConfigured
        }

        let vault = PufferDemoConfig.sepoliaVaultAddress
        guard try await ChainRPCClient.contractHasCode(address: vault) else {
            throw PufferStakeError.vaultNotDeployed(vault)
        }

        let balance = try await ChainRPCClient.fetchNativeBalance(address: signingAddress)
        let gasETH = estimatedGasCostETH(gasLimit: gasLimit, gasPrice: gasPrice)
        let required = ethAmount + gasETH
        guard balance >= required else {
            throw PufferStakeError.insufficientBalance(
                have: balance,
                need: required,
                signingAddress: signingAddress,
                gasETH: gasETH
            )
        }
    }

    static func validateUnstake(
        pufAmount: Decimal,
        walletAddress: String
    ) async throws {
        guard pufAmount > 0 else { throw PufferStakeError.invalidAmount }
        guard PufferDemoConfig.hasOnChainVault else {
            throw PufferStakeError.vaultNotConfigured
        }

        let vault = PufferDemoConfig.sepoliaVaultAddress
        guard try await ChainRPCClient.contractHasCode(address: vault) else {
            throw PufferStakeError.vaultNotDeployed(vault)
        }

        let pufBalance = await pufETHBalance(address: walletAddress)
        guard pufBalance > 0 else {
            throw PufferStakeError.insufficientPufETH(have: 0, need: pufAmount)
        }

        let ethBalance = try await ChainRPCClient.fetchNativeBalance(address: walletAddress)
        guard ethBalance >= PufferDemoConfig.gasReserveEther else {
            throw PufferStakeError.insufficientBalance(
                have: ethBalance,
                need: PufferDemoConfig.gasReserveEther,
                signingAddress: walletAddress,
                gasETH: PufferDemoConfig.gasReserveEther
            )
        }
    }

    @MainActor
    private static func resolveSigningContext(
        keystoreJSON: String,
        walletPassword: String,
        displayAddress: String?
    ) async throws -> TokenCoreService.SigningContext {
        let context = try await TokenCoreService.resolveSigningContext(
            keystoreJSON: keystoreJSON,
            password: walletPassword,
            preferredAddress: displayAddress ?? WalletKeychainStore.loadAddress()
        )
        WalletSession.shared.applyVerifiedSigningAddress(context.address)
        return context
    }

    private static func assertNoStuckNonce(signingAddress: String) async throws {
        let latest = try await ChainRPCClient.fetchTransactionCount(address: signingAddress, block: "latest")
        let pending = try await ChainRPCClient.fetchTransactionCount(address: signingAddress, block: "pending")
        guard pending <= latest else {
            throw PufferStakeError.stuckPendingNonce(
                signingAddress: signingAddress,
                count: pending - latest
            )
        }
    }

    private static func assertSignedTransactionAffordable(
        rawTransaction: String,
        signingAddress: String
    ) async throws {
        let fee = try EthereumLegacyTransactionRecovery.legacyFeeSummary(fromRawTransaction: rawTransaction)
        let balanceWei = try await ChainRPCClient.fetchNativeBalanceWeiDecimal(address: signingAddress)
        let maxCost = Decimal(fee.maxCostWei)
        guard balanceWei >= maxCost else {
            let need = EVMWeiFormatter.weiToEther(maxCost)
            let have = EVMWeiFormatter.weiToEther(balanceWei)
            throw PufferStakeError.rpcFailure(
                """
                錢包地址 \(Self.shortAddress(signingAddress)) Sepolia 餘額 \(Self.formatDecimal(have)) ETH，不足以支付本次交易（約 \(Self.formatDecimal(need)) ETH）。
                請對此地址領 Sepolia 測試 ETH 後再質押。
                """
            )
        }
    }

    private static func shortAddress(_ address: String) -> String {
        guard address.count > 12 else { return address }
        return "\(address.prefix(6))…\(address.suffix(4))"
    }

    private static func formatDecimal(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 6
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "\(value)"
    }

    private static func assertSignedStakeTransaction(
        rawTransaction: String,
        expectedAddress: String,
        expectedValueWei: UInt64
    ) async throws {
        let signedValue = try EthereumLegacyTransactionRecovery.valueWei(fromRawTransaction: rawTransaction)
        guard signedValue == expectedValueWei else {
            let signedETH = EVMWeiFormatter.weiToEther(Decimal(signedValue))
            let expectedETH = EVMWeiFormatter.weiToEther(Decimal(expectedValueWei))
            throw PufferStakeError.rpcFailure(
                "簽名交易金額異常（簽出 \(signedETH) ETH，預期 \(expectedETH) ETH）。請更新 App 後重試。"
            )
        }

    }

    @MainActor
    static func stakeOnSepolia(
        ethAmount: Decimal,
        walletAddress: String,
        walletPassword: String,
        exchangeRate: PufferExchangeRate
    ) async throws -> PufferStakeResult {
        guard let keystoreJSON = WalletKeychainStore.loadKeystoreJSON() else {
            throw PufferStakeError.walletNotReady
        }

        let signing = try await resolveSigningContext(
            keystoreJSON: keystoreJSON,
            walletPassword: walletPassword,
            displayAddress: walletAddress
        )
        let signingAddress = signing.address
        WalletSession.shared.applyVerifiedSigningAddress(signingAddress)

        let vault = PufferDemoConfig.sepoliaVaultAddress
        let valueWei = EVMWeiFormatter.etherToWei(ethAmount)
        guard valueWei > 0 else { throw PufferStakeError.invalidAmount }

        try await TokenCoreBridge.shared.ensureReady()

        let nonce = try await ChainRPCClient.fetchTransactionCount(address: signingAddress)
        let gasPrice = try await ChainRPCClient.fetchGasPrice()
        let gasLimit: UInt64
        do {
            gasLimit = try await ChainRPCClient.estimateGas(
                from: signingAddress,
                to: vault,
                valueWei: valueWei,
                data: PufferDemoConfig.depositSelector
            )
        } catch let error as ChainRPCError {
            throw await PufferStakeError.fromRPC(
                error,
                context: .stake,
                signingAddress: signingAddress,
                displayAddress: walletAddress
            )
        }

        try await validateStake(
            ethAmount: ethAmount,
            signingAddress: signingAddress,
            gasLimit: gasLimit,
            gasPrice: gasPrice
        )

        let signed: TokenCoreService.SignedEthereumTransaction
        do {
            (signed, _) = try await TokenCoreService.signEthereumLegacyTransactionWithSepoliaFunds(
                keystoreJSON: keystoreJSON,
                password: walletPassword,
                to: vault,
                valueWei: valueWei,
                data: PufferDemoConfig.depositSelector,
                gasLimit: gasLimit,
                gasPrice: gasPrice,
                preferredAddress: signingAddress
            )
        } catch let error as WalletError {
            if case .signingFailedWithDetail(let detail) = error {
                throw PufferStakeError.rpcFailure(detail)
            }
            throw PufferStakeError.rpcFailure(
                "簽名失敗：\(error.localizedDescription ?? "請確認錢包密碼")"
            )
        } catch {
            throw PufferStakeError.rpcFailure(
                "簽名失敗：\(error.localizedDescription ?? "未知錯誤")"
            )
        }
        guard signed.rawTransaction.hasPrefix("0x"), signed.rawTransaction.count > 10 else {
            throw PufferStakeError.signingFailed
        }

        try await assertSignedStakeTransaction(
            rawTransaction: signed.rawTransaction,
            expectedAddress: signingAddress,
            expectedValueWei: valueWei
        )
        try await assertSignedTransactionAffordable(
            rawTransaction: signed.rawTransaction,
            signingAddress: signingAddress
        )
        try await assertNoStuckNonce(signingAddress: signingAddress)

        let txHash: String
        do {
            txHash = try await ChainRPCClient.sendRawTransactionReliable(signedRaw: signed.rawTransaction)
            try await ChainRPCClient.waitForTransactionSuccess(txHash: txHash)
        } catch let error as ChainRPCError {
            throw await PufferStakeError.fromRPC(
                error,
                context: .stake,
                signingAddress: signingAddress,
                displayAddress: walletAddress
            )
        }

        let pufMinted = ethAmount * exchangeRate.pufEthPerEth
        return PufferStakeResult(
            mode: .sepoliaOnChain,
            ethDeposited: ethAmount,
            pufETHMinted: pufMinted,
            transactionHash: txHash
        )
    }

    @MainActor
    static func unstakeOnSepolia(
        pufAmount: Decimal,
        walletAddress: String,
        walletPassword: String,
        exchangeRate: PufferExchangeRate,
        withdrawAll: Bool = false
    ) async throws -> PufferUnstakeResult {
        guard let keystoreJSON = WalletKeychainStore.loadKeystoreJSON() else {
            throw PufferStakeError.walletNotReady
        }

        let signing = try await resolveSigningContext(
            keystoreJSON: keystoreJSON,
            walletPassword: walletPassword,
            displayAddress: walletAddress
        )
        let signingAddress = signing.address
        WalletSession.shared.applyVerifiedSigningAddress(signingAddress)
        try await validateUnstake(pufAmount: pufAmount, walletAddress: signingAddress)

        let vault = PufferDemoConfig.sepoliaVaultAddress
        let chainPufWeiHex = try await ChainRPCClient.fetchERC20BalanceWeiHex(
            userAddress: signingAddress,
            tokenContract: vault
        )
        let chainPufWei = EVMWeiFormatter.weiHexToDecimal("0x" + chainPufWeiHex)
        guard chainPufWei > 0 else {
            throw PufferStakeError.insufficientPufETH(have: 0, need: pufAmount)
        }

        let withdrawWeiHex: String
        if withdrawAll {
            withdrawWeiHex = chainPufWeiHex
        } else {
            let requestedWei = Decimal(EVMWeiFormatter.tokenAmountToWei(pufAmount))
            let withdrawWei = min(requestedWei, chainPufWei)
            withdrawWeiHex = EVMWeiFormatter.uint256HexData(withdrawWei)
        }
        let withdrawWei = EVMWeiFormatter.weiHexToDecimal("0x" + withdrawWeiHex)
        guard withdrawWei > 0 else { throw PufferStakeError.invalidAmount }

        let minMeaningfulWei: Decimal = 1_000_000_000_000_000 // 0.001 pufETH
        let pufBurned = EVMWeiFormatter.weiToEther(withdrawWei)
        if withdrawWei < minMeaningfulWei, chainPufWei >= minMeaningfulWei {
            let chainHuman = EVMWeiFormatter.weiToEther(chainPufWei)
            throw PufferStakeError.rpcFailure(
                """
                解質押數量過小（\(formatDecimal(pufBurned)) \(PufferDemoConfig.pufETHSymbol)），鏈上實際持倉還有 \(formatDecimal(chainHuman)) \(PufferDemoConfig.pufETHSymbol)。
                請點「解質押全部」一次取完。
                """
            )
        }
        let rateWei = (try? await ChainRPCClient.fetchDemoVaultExchangeRateWei(vaultAddress: vault))
            ?? Decimal(1_000_000_000_000_000_000)
        let expectedEthOut = PufferVaultMath.ethOutForPufAmount(pufBurned, exchangeRateWei: rateWei)

        let vaultEthWei = try await ChainRPCClient.fetchNativeBalanceWeiDecimal(
            address: vault,
            rpcURL: ChainConfig.active.rpcURL
        )
        let expectedOutWei = withdrawWei * Decimal(1_000_000_000_000_000_000) / rateWei
        if vaultEthWei < expectedOutWei {
            throw PufferStakeError.rpcFailure(
                "演示 Vault Sepolia ETH 不足（需 \(formatDecimal(expectedEthOut)) ETH）。請聯繫部署者補充或稍後再試。"
            )
        }

        let calldata = PufferDemoConfig.encodeWithdrawCalldata(weiHex64: withdrawWeiHex)
        let ethBeforeWei = try await ChainRPCClient.fetchNativeBalanceWeiDecimal(address: signingAddress)

        try await TokenCoreBridge.shared.ensureReady()

        let nonce = try await ChainRPCClient.fetchTransactionCount(address: signingAddress)
        let gasPrice = try await ChainRPCClient.fetchGasPrice()

        let gasLimit: UInt64
        do {
            gasLimit = try await ChainRPCClient.estimateGas(
                from: signingAddress,
                to: vault,
                valueWei: 0,
                data: calldata
            )
        } catch let error as ChainRPCError {
            throw await PufferStakeError.fromUnstakeEstimateGas(
                error,
                signingAddress: signingAddress,
                displayAddress: walletAddress,
                requestedPuf: pufAmount,
                chainPuf: EVMWeiFormatter.weiToEther(chainPufWei)
            )
        }

        let (signed, _) = try await TokenCoreService.signEthereumLegacyTransactionWithSepoliaFunds(
            keystoreJSON: keystoreJSON,
            password: walletPassword,
            to: vault,
            valueWei: 0,
            data: calldata,
            gasLimit: gasLimit,
            gasPrice: gasPrice,
            preferredAddress: signingAddress
        )

        try await assertSignedStakeTransaction(
            rawTransaction: signed.rawTransaction,
            expectedAddress: signingAddress,
            expectedValueWei: 0
        )
        try await assertSignedTransactionAffordable(
            rawTransaction: signed.rawTransaction,
            signingAddress: signingAddress
        )
        try await assertNoStuckNonce(signingAddress: signingAddress)

        let txHash = try await ChainRPCClient.sendRawTransactionReliable(signedRaw: signed.rawTransaction)
        do {
            try await ChainRPCClient.waitForTransactionSuccess(txHash: txHash)
        } catch let error as ChainRPCError {
            throw await PufferStakeError.fromRPC(
                error,
                context: .unstake,
                signingAddress: signingAddress,
                displayAddress: walletAddress
            )
        }

        let (ethReceived, ethNet) = try await measureEthReceivedAfterWithdraw(
            signingAddress: signingAddress,
            ethBeforeWei: ethBeforeWei,
            expectedEthOut: expectedEthOut,
            exchangeRate: exchangeRate,
            pufBurned: pufBurned
        )
        return PufferUnstakeResult(
            pufETHBurned: pufBurned,
            ethReceived: ethReceived,
            ethNetToWallet: ethNet,
            transactionHash: txHash
        )
    }

    private static func measureEthReceivedAfterWithdraw(
        signingAddress: String,
        ethBeforeWei: Decimal,
        expectedEthOut: Decimal,
        exchangeRate: PufferExchangeRate,
        pufBurned: Decimal
    ) async throws -> (gross: Decimal, net: Decimal) {
        var ethAfterWei = ethBeforeWei
        for _ in 0..<10 {
            try await Task.sleep(nanoseconds: 600_000_000)
            ethAfterWei = (try? await ChainRPCClient.fetchNativeBalanceWeiDecimal(address: signingAddress))
                ?? ethAfterWei
            if ethAfterWei != ethBeforeWei { break }
        }
        let netWei = max(0, ethAfterWei - ethBeforeWei)
        let net = EVMWeiFormatter.weiToEther(netWei)
        let gross = expectedEthOut > 0 ? expectedEthOut : pufBurned * exchangeRate.ethPerPufEth
        return (gross, net)
    }
}

enum PufferStakeError: LocalizedError {
    enum TxContext {
        case stake
        case unstake
    }

    case invalidAmount
    case vaultNotConfigured
    case vaultNotDeployed(String)
    case insufficientBalance(have: Decimal, need: Decimal, signingAddress: String, gasETH: Decimal)
    case insufficientPufETH(have: Decimal, need: Decimal)
    case walletNotReady
    case withdrawNotSupported
    case signingFailed
    case signerAddressMismatch(
        displayAddress: String,
        displayBalance: Decimal,
        signerAddress: String,
        signerBalance: Decimal
    )
    case rpcFailure(String)
    case stuckPendingNonce(signingAddress: String, count: UInt64)

    var explorerAddressURL: URL? {
        switch self {
        case .stuckPendingNonce(let signingAddress, _):
            let base = ChainConfig.active.explorerURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return URL(string: "\(base)/address/\(signingAddress)")
        default:
            return nil
        }
    }

    static func fromUnstakeEstimateGas(
        _ error: ChainRPCError,
        signingAddress: String,
        displayAddress: String,
        requestedPuf: Decimal,
        chainPuf: Decimal
    ) async -> PufferStakeError {
        guard case .rpcError(let message) = error else {
            return .rpcFailure(error.localizedDescription ?? "RPC 錯誤")
        }
        let lower = message.lowercased()
        if lower.contains("balance") {
            return .rpcFailure(
                """
                \(PufferDemoConfig.pufETHSymbol) 餘額不足：鏈上 \(formatDecimal(chainPuf))，你輸入 \(formatDecimal(requestedPuf))。
                請點「全部」或輸入不超過鏈上餘額的數量後再試。
                """
            )
        }
        if lower.contains("insolvent") {
            return .rpcFailure("演示 Vault 內 Sepolia ETH 不足，暫時無法贖回。請稍後再試或聯繫部署者。")
        }
        if lower.contains("revert") || lower.contains("execution") {
            return .rpcFailure("解質押模擬失敗：\(message)")
        }
        return await fromRPC(
            error,
            context: .unstake,
            signingAddress: signingAddress,
            displayAddress: displayAddress
        )
    }

    static func fromRPC(
        _ error: ChainRPCError,
        context: TxContext,
        signingAddress: String,
        displayAddress: String
    ) async -> PufferStakeError {
        guard case .rpcError(let message) = error else {
            return .rpcFailure(error.localizedDescription ?? "RPC 錯誤")
        }
        let lower = message.lowercased()
        if lower.contains("insufficient funds") {
            let action = context == .stake ? "質押" : "解質押"
            let signerBal = (try? await ChainRPCClient.fetchNativeBalance(address: signingAddress)) ?? 0
            let shortSigner = shortAddress(signingAddress)
            if signerBal >= Decimal(string: "0.012") ?? 0 {
                return .rpcFailure(
                    """
                    鏈上拒絕\(action)（\(shortSigner) 餘額 \(formatDecimal(signerBal)) ETH）。
                    節點回報：\(message)
                    請到 Sepolia Etherscan 查看是否有待確認交易卡住 nonce，或更新 App 後重試。
                    """
                )
            }
            let displayBal = (try? await ChainRPCClient.fetchNativeBalance(address: displayAddress)) ?? 0
            let shortDisplay = shortAddress(displayAddress)
            if signingAddress.lowercased() != displayAddress.lowercased() {
                return .rpcFailure(
                    """
                    Sepolia ETH 不足以\(action)（含 Gas）。
                    簽名地址 \(shortSigner) 餘額 \(formatDecimal(signerBal)) ETH；
                    畫面地址 \(shortDisplay) 餘額 \(formatDecimal(displayBal)) ETH。
                    請對簽名地址領水，或重新匯入與領水相同的私鑰／助記詞。
                    """
                )
            }
            return .rpcFailure(
                "簽名地址 \(shortSigner) Sepolia ETH 不足（目前 \(formatDecimal(signerBal)) ETH）。請至 Sepolia 水龍頭補充測試 ETH 後再試。"
            )
        }
        return .rpcFailure(message)
    }

    private static func shortAddress(_ address: String) -> String {
        guard address.count > 12 else { return address }
        return "\(address.prefix(6))…\(address.suffix(4))"
    }

    var errorDescription: String? {
        switch self {
        case .invalidAmount:
            return "請輸入大於 0 的數量"
        case .vaultNotConfigured:
            return "尚未配置 Sepolia 演示合約。請依畫面說明部署 VibePufferDemoVault 並寫入 Secrets.plist。"
        case .vaultNotDeployed(let address):
            return "Sepolia 上找不到合約代碼（\(address)）。請確認已部署到 Sepolia。"
        case .insufficientBalance(let have, let need, let signingAddress, let gasETH):
            return """
            簽名地址 \(Self.shortAddress(signingAddress)) Sepolia ETH 不足。
            目前 \(Self.formatDecimal(have)) ETH，本次質押＋預估 Gas 至少需 \(Self.formatDecimal(need)) ETH（Gas 約 \(Self.formatDecimal(gasETH)) ETH）。
            """
        case .signerAddressMismatch(let displayAddress, let displayBalance, let signerAddress, let signerBalance):
            return """
            簽名地址與畫面不一致，無法使用畫面上的餘額質押。
            畫面 \(Self.shortAddress(displayAddress))：\(Self.formatDecimal(displayBalance)) ETH
            簽名 \(Self.shortAddress(signerAddress))：\(Self.formatDecimal(signerBalance)) ETH
            請對「簽名」地址領 Sepolia 測試 ETH，或重新匯入與領水相同的錢包。
            """
        case .insufficientPufETH(let have, let need):
            return String(
                format: "%@ 不足。目前 %@，需要 %@",
                PufferDemoConfig.pufETHSymbol,
                Self.formatDecimal(have),
                Self.formatDecimal(need)
            )
        case .walletNotReady:
            return "找不到錢包 Keystore，請重新建立或匯入錢包。"
        case .withdrawNotSupported:
            return "此 Vault 不支援解質押。請用最新版 contracts/VibePufferDemoVault.sol 重新部署到 Sepolia，並更新 Secrets.plist 的 PUFFER_SEPOLIA_VAULT。"
        case .signingFailed:
            return "交易簽名失敗，請確認錢包密碼與網路設定。"
        case .rpcFailure(let message):
            return message
        case .stuckPendingNonce(let signingAddress, let count):
            return """
            簽名地址 \(Self.shortAddress(signingAddress)) 有 \(count) 筆待確認交易佔用 nonce，暫時無法送出新的質押或解質押。
            請在 Sepolia Etherscan 等待確認，或對該筆交易加速／取消後再試。
            """
        }
    }

    private static func formatDecimal(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 6
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "\(value)"
    }
}
