import Foundation
import Observation

/// 質押資產種類（Sepolia 演示僅開放 ETH）
enum PufferStakeAsset: String, CaseIterable, Identifiable {
    case eth = "ETH"
    case stETH = "stETH"
    case wstETH = "wstETH"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var shortDescription: String {
        switch self {
        case .eth:
            return "Sepolia 演示 Vault 可直接存入"
        case .stETH:
            return "Lido 質押 ETH · 主網路徑籌備中"
        case .wstETH:
            return "封裝 stETH · 主網路徑籌備中"
        }
    }

    var isAvailableOnSepoliaDemo: Bool {
        self == .eth
    }
}

@MainActor
@Observable
final class PufferStakingViewModel {
    private(set) var exchangeRate: PufferExchangeRate = PufferAPIService.fallbackExchangeRate
    /// 鏈上 Vault `exchangeRateWei` 換算（解質押／贖回以鏈上為準）
    private(set) var vaultEthPerPufEth: Decimal = 1
    private(set) var rateSource = "載入中…"
    private(set) var ethBalance: Decimal = 0
    private(set) var pufETHBalance: Decimal = 0
    private(set) var pufETHBalanceWei: Decimal = 0
    private(set) var vaultReady = false
    private(set) var vaultAddress = ""
    private(set) var isLoading = false
    private(set) var isStaking = false
    private(set) var isUnstaking = false
    private(set) var isCancellingPending = false
    private(set) var lastStakeMessage: String?
    private(set) var lastUnstakeMessage: String?
    private(set) var lastUnstakeWasDust = false
    private(set) var lastTxHash: String?
    /// 待確認交易數（pending nonce − latest nonce）；Demo 前應為 0
    private(set) var pendingNonceCount: UInt64 = 0
    private(set) var signingAddressForMonitor = ""

    /// 鏈上贖回 ETH 低於此值時視為塵埃（Gas 常遠大於取回金額）
    private static let dustEthThreshold: Decimal = Decimal(string: "0.0001") ?? 0.0001
    private static let minUnstakePufETH: Decimal = Decimal(string: "0.001") ?? 0.001

    var stakeAmountText = "0.01"
    var unstakeAmountText = ""
    var selectedStakeAsset: PufferStakeAsset = .eth

    /// 演示用質押年化（Sepolia 展示）
    let estimatedAPYPercent: Double = 4.25

    var estimatedAnnualYieldETH: Decimal {
        ethBalance * Decimal(estimatedAPYPercent / 100)
    }

    var estimatedStakeYieldPufETH: Decimal {
        guard let amount = parsedStakeAmount, amount > 0 else { return 0 }
        return amount * exchangeRate.pufEthPerEth * Decimal(estimatedAPYPercent / 100)
    }

    var hasStuckPendingNonce: Bool { pendingNonceCount > 0 }

    var signingAddressExplorerURL: URL? {
        guard !signingAddressForMonitor.isEmpty else { return nil }
        let base = ChainConfig.active.explorerURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: "\(base)/address/\(signingAddressForMonitor)")
    }

    var canStake: Bool {
        guard !hasStuckPendingNonce else { return false }
        guard selectedStakeAsset.isAvailableOnSepoliaDemo else { return false }
        guard vaultReady, !isStaking, !isLoading else { return false }
        guard let amount = parsedStakeAmount, amount > 0 else { return false }
        let required = amount + PufferDemoConfig.gasReserveEther
        return ethBalance >= required
    }

    var stakeAssetUnavailableHint: String? {
        guard !selectedStakeAsset.isAvailableOnSepoliaDemo else { return nil }
        return "Sepolia 演示僅支援 ETH 直接質押鑄造 pufETH。\(selectedStakeAsset.displayName) 將透過主網 Lido → Puffer 路徑接入（籌備中），請先切換 ETH 或關注下方 UniFi Vault。"
    }

    var needsSepoliaFaucet: Bool {
        ethBalance < PufferDemoConfig.gasReserveEther
    }

    var canUnstake: Bool {
        guard !hasStuckPendingNonce else { return false }
        guard vaultReady, !isUnstaking, !isStaking, !isLoading else { return false }
        guard let amount = parsedUnstakeAmount, amount > 0 else { return false }
        return pufETHBalanceWei > 0
    }

    var unstakeDisabledReason: String? {
        if hasStuckPendingNonce {
            return stuckPendingNonceHint
        }
        if !PufferDemoConfig.hasOnChainVault {
            return "請先配置 Sepolia 合約地址"
        }
        if !vaultReady {
            return "合約尚未部署或 RPC 無法讀取"
        }
        if pufETHBalance <= 0 {
            return "目前 \(PufferDemoConfig.pufETHSymbol) 餘額為 0，請先質押取得持倉後再解質押"
        }
        guard let amount = parsedUnstakeAmount, amount > 0 else {
            return "請輸入解質押數量"
        }
        let requestedWei = Decimal(EVMWeiFormatter.tokenAmountToWei(amount))
        if requestedWei > pufETHBalanceWei {
            return "輸入超過鏈上餘額，將自動以最多 \(format(pufETHBalance, maxFraction: 8)) \(PufferDemoConfig.pufETHSymbol) 解質押"
        }
        if ethBalance < PufferDemoConfig.gasReserveEther {
            return "Sepolia ETH 不足支付 Gas"
        }
        return nil
    }

    var unstakePreviewETH: Decimal {
        guard let amount = parsedUnstakeAmount, amount > 0 else { return 0 }
        return amount * vaultEthPerPufEth
    }

    var unstakeDustWarning: String? {
        guard pufETHBalance > 0 else { return nil }
        guard let amount = parsedUnstakeAmount, amount > 0 else { return nil }
        if amount < Self.minUnstakePufETH, pufETHBalance >= Self.minUnstakePufETH {
            return "輸入過小！鏈上尚有 \(format(pufETHBalance, maxFraction: 8)) \(PufferDemoConfig.pufETHSymbol)。請點「全部」一次解完（建議 ≥ 0.01）。"
        }
        let ethOut = unstakePreviewETH
        guard ethOut > 0, ethOut < Self.dustEthThreshold else { return nil }
        return "預估取回 ETH 極小，Gas 會大於收益。請點「全部」解質押 ≥ 0.01 \(PufferDemoConfig.pufETHSymbol)。"
    }

    var unstakeSubmitLabel: String {
        guard pufETHBalance > 0 else { return "確認解質押（Sepolia）" }
        return "解質押全部 \(format(pufETHBalance, maxFraction: 6)) \(PufferDemoConfig.pufETHSymbol)"
    }

    var stakeDisabledReason: String? {
        if hasStuckPendingNonce {
            return stuckPendingNonceHint
        }
        if let hint = stakeAssetUnavailableHint {
            return hint
        }
        if !PufferDemoConfig.hasOnChainVault {
            return "請先配置 Sepolia 合約地址"
        }
        if !vaultReady {
            return "合約尚未部署或 RPC 無法讀取"
        }
        guard let amount = parsedStakeAmount, amount > 0 else {
            return "請輸入質押數量"
        }
        let required = amount + PufferDemoConfig.gasReserveEther
        if ethBalance < required {
            return "Sepolia ETH 不足，請先領水"
        }
        return nil
    }

    private var stuckPendingNonceHint: String {
        """
        有 \(pendingNonceCount) 筆待確認交易佔用 nonce，暫時無法質押／解質押。
        請下拉刷新；若仍存在，到 Sepolia Etherscan 等待確認或取消 Pending 後再試。
        """
    }

    private func refreshPendingNonceCount(for address: String) async {
        let latest = (try? await ChainRPCClient.fetchTransactionCount(address: address, block: "latest")) ?? 0
        let pending = (try? await ChainRPCClient.fetchTransactionCount(address: address, block: "pending")) ?? latest
        pendingNonceCount = pending > latest ? pending - latest : 0
    }

    private var parsedStakeAmount: Decimal? {
        Decimal(string: stakeAmountText.replacingOccurrences(of: ",", with: "."))
    }

    private var parsedUnstakeAmount: Decimal? {
        Decimal(string: unstakeAmountText.replacingOccurrences(of: ",", with: "."))
    }

    func cancelPendingNonces(walletAddress: String, walletPassword: String) async throws -> PendingNonceCancelResult {
        isCancellingPending = true
        defer { isCancellingPending = false }
        let result = try await PendingNonceCancellationService.cancelAllPending(
            walletPassword: walletPassword,
            displayAddress: walletAddress
        )
        await refresh(walletAddress: walletAddress)
        NotificationCenter.default.post(name: .walletBalancesDidChange, object: nil)
        return result
    }

    func refresh(walletAddress: String?) async {
        isLoading = true
        defer { isLoading = false }

        vaultAddress = PufferDemoConfig.sepoliaVaultAddress

        do {
            exchangeRate = try await PufferAPIService.fetchExchangeRate()
            rateSource = "Puffer Hackathon API · 協議參考匯率"
        } catch {
            exchangeRate = PufferAPIService.fallbackExchangeRate
            rateSource = "API 暫不可用 · 演示匯率 \(exchangeRate.rawPufEthPerEth)"
        }

        var resolvedAddress = walletAddress
        if let keystore = WalletKeychainStore.loadKeystoreJSON(),
           let password = WalletSession.shared.signingPassword,
           let context = try? await TokenCoreService.resolveSigningContext(
               keystoreJSON: keystore,
               password: password,
               preferredAddress: walletAddress
           ) {
            resolvedAddress = context.address
            WalletSession.shared.applyVerifiedSigningAddress(context.address)
        } else if let keystoreAddress = WalletKeychainStore.addressFromKeystoreIfAvailable() {
            resolvedAddress = keystoreAddress
        }

        guard let walletAddress = resolvedAddress, !walletAddress.isEmpty else {
            ethBalance = 0
            pufETHBalance = 0
            vaultReady = false
            pendingNonceCount = 0
            signingAddressForMonitor = ""
            return
        }

        signingAddressForMonitor = walletAddress
        await refreshPendingNonceCount(for: walletAddress)

        ethBalance = (try? await ChainRPCClient.fetchNativeBalance(address: walletAddress)) ?? 0
        if PufferDemoConfig.hasOnChainVault {
            pufETHBalanceWei = (try? await ChainRPCClient.fetchERC20BalanceWeiDecimal(
                userAddress: walletAddress,
                tokenContract: vaultAddress
            )) ?? 0
            pufETHBalance = EVMWeiFormatter.weiToEther(pufETHBalanceWei)
        } else {
            pufETHBalanceWei = 0
            pufETHBalance = 0
        }
        if unstakeAmountText.isEmpty, pufETHBalance > 0 {
            unstakeAmountText = format(pufETHBalance, maxFraction: 8)
        }

        if PufferDemoConfig.hasOnChainVault {
            vaultReady = (try? await ChainRPCClient.contractHasCode(address: vaultAddress)) == true
            if vaultReady,
               let rateWei = try? await ChainRPCClient.fetchDemoVaultExchangeRateWei(vaultAddress: vaultAddress) {
                vaultEthPerPufEth = PufferVaultMath.ethPerPufEth(exchangeRateWei: rateWei)
            } else {
                vaultEthPerPufEth = 1
            }
        } else {
            vaultReady = false
            vaultEthPerPufEth = 1
        }
    }

    private func refreshAfterTransaction(walletAddress: String?) async {
        for attempt in 0..<5 {
            await refresh(walletAddress: walletAddress)
            if attempt < 4 {
                try? await Task.sleep(nanoseconds: 700_000_000)
            }
        }
    }

    func stake(walletAddress: String, walletPassword: String) async throws -> PufferStakeResult {
        guard let amount = parsedStakeAmount, amount > 0 else {
            throw PufferStakeError.invalidAmount
        }
        isStaking = true
        defer { isStaking = false }

        let result = try await PufferStakingService.stakeOnSepolia(
            ethAmount: amount,
            walletAddress: walletAddress,
            walletPassword: walletPassword,
            exchangeRate: exchangeRate
        )
        lastUnstakeMessage = nil
        lastUnstakeWasDust = false
        lastStakeMessage = "鏈上質押 \(format(amount)) ETH → 約 \(format(result.pufETHMinted)) \(PufferDemoConfig.pufETHSymbol)"
        lastTxHash = result.transactionHash
        await refreshAfterTransaction(walletAddress: WalletSession.shared.account?.address ?? walletAddress)
        NotificationCenter.default.post(name: .walletBalancesDidChange, object: nil)
        return result
    }

    func unstake(walletAddress: String, walletPassword: String) async throws -> PufferUnstakeResult {
        guard pufETHBalanceWei > 0 else {
            throw PufferStakeError.insufficientPufETH(have: 0, need: 1)
        }
        isUnstaking = true
        defer { isUnstaking = false }

        useFullPufETHBalanceForUnstake()
        let result = try await PufferStakingService.unstakeOnSepolia(
            pufAmount: pufETHBalance,
            walletAddress: walletAddress,
            walletPassword: walletPassword,
            exchangeRate: exchangeRate,
            withdrawAll: true
        )
        lastStakeMessage = nil
        lastTxHash = result.transactionHash
        await refreshAfterTransaction(walletAddress: walletAddress)
        lastUnstakeWasDust = result.ethReceived < Self.dustEthThreshold
        if lastUnstakeWasDust {
            lastUnstakeMessage = """
            交易已成功，但取回金額極小（\(format(result.ethReceived, maxFraction: 12)) ETH），低於 Gas，餘額幾乎不變。請用「解質押全部」按鈕。
            剩餘 pufETH：\(format(pufETHBalance, maxFraction: 8)) · Sepolia ETH：\(format(ethBalance, maxFraction: 6))
            """
        } else if pufETHBalance > Self.minUnstakePufETH / 10 {
            lastUnstakeMessage = """
            部分解質押成功，鏈上仍剩 \(format(pufETHBalance, maxFraction: 8)) \(PufferDemoConfig.pufETHSymbol)。請再按「解質押全部」一次取完。
            本次 Vault 轉出 \(format(result.ethReceived, maxFraction: 6)) ETH。
            """
        } else {
            lastUnstakeMessage = """
            解質押成功：銷毀 \(format(result.pufETHBurned, maxFraction: 8)) \(PufferDemoConfig.pufETHSymbol)，Vault 轉出 \(format(result.ethReceived, maxFraction: 6)) ETH。
            錢包淨增約 \(format(result.ethNetToWallet, maxFraction: 6)) ETH（已扣 Gas）；目前 Sepolia ETH \(format(ethBalance, maxFraction: 6))。
            """
        }
        if pufETHBalance > 0 {
            unstakeAmountText = format(pufETHBalance, maxFraction: 8)
        } else {
            unstakeAmountText = ""
        }
        NotificationCenter.default.post(name: .walletBalancesDidChange, object: nil)
        return result
    }

    func useFullPufETHBalanceForUnstake() {
        guard pufETHBalanceWei > 0 else { return }
        unstakeAmountText = format(pufETHBalance, maxFraction: 12)
    }

    func format(_ value: Decimal, maxFraction: Int = 6) -> String {
        let number = NSDecimalNumber(decimal: value)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maxFraction
        return formatter.string(from: number) ?? "\(value)"
    }
}
