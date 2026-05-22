import Foundation

struct SepoliaSwapResult: Sendable {
    let transactionHash: String
    let fromSymbol: String
    let toSymbol: String
    let amountIn: Decimal
    let amountOut: Decimal
}

enum SepoliaSwapError: LocalizedError {
    case notConfigured
    case pairNotSupported
    case invalidAmount
    case insufficientBalance
    case walletNotReady
    case contractNotDeployed

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "尚未部署 Sepolia 交換演示合約。請執行 node scripts/setup-swap-sepolia.mjs"
        case .pairNotSupported:
            return "此代幣對暫不支援鏈上交換。可試 ETH ↔ vUSDC 或 ETH → pufETH。"
        case .invalidAmount:
            return "請輸入大於 0 的數量"
        case .insufficientBalance:
            return "餘額不足"
        case .walletNotReady:
            return "找不到錢包 Keystore"
        case .contractNotDeployed:
            return "交換合約尚未部署到 Sepolia"
        }
    }
}

enum SepoliaSwapService {
    /// 行情裡的 USDC 對應鏈上演示 vUSDC
    static func normalizeTokenId(_ id: String) -> String {
        if id == "usd-coin", SepoliaSwapDemoConfig.hasOnChainSwap {
            return SepoliaSwapDemoConfig.vUSDCMarketId
        }
        return id
    }

    @MainActor
    static func executeSwap(
        fromTokenId: String,
        toTokenId: String,
        amountIn: Decimal,
        walletAddress: String,
        walletPassword: String,
        slippagePercent: Double
    ) async throws -> SepoliaSwapResult {
        guard amountIn > 0 else { throw SepoliaSwapError.invalidAmount }
        guard let keystoreJSON = WalletKeychainStore.loadKeystoreJSON() else {
            throw SepoliaSwapError.walletNotReady
        }

        try await TokenCoreBridge.shared.ensureReady()

        let fromId = normalizeTokenId(fromTokenId)
        let toId = normalizeTokenId(toTokenId)

        switch (fromId, toId) {
        case ("ethereum", SepoliaSwapDemoConfig.vUSDCMarketId):
            return try await swapETHForVUSDC(
                amount: amountIn,
                walletAddress: walletAddress,
                walletPassword: walletPassword,
                keystoreJSON: keystoreJSON
            )
        case (SepoliaSwapDemoConfig.vUSDCMarketId, "ethereum"):
            return try await swapVUSDCForETH(
                amount: amountIn,
                walletAddress: walletAddress,
                walletPassword: walletPassword,
                keystoreJSON: keystoreJSON
            )
        case ("ethereum", "puffer-pufeth"):
            let rate = await PufferStakingService.loadExchangeRate()
            let result = try await PufferStakingService.stakeOnSepolia(
                ethAmount: amountIn,
                walletAddress: walletAddress,
                walletPassword: walletPassword,
                exchangeRate: rate
            )
            return SepoliaSwapResult(
                transactionHash: result.transactionHash,
                fromSymbol: "ETH",
                toSymbol: PufferDemoConfig.pufETHSymbol,
                amountIn: amountIn,
                amountOut: result.pufETHMinted
            )
        default:
            throw SepoliaSwapError.pairNotSupported
        }
    }

    static func vUSDCBalance(address: String) async -> Decimal {
        guard SepoliaSwapDemoConfig.hasOnChainSwap else { return 0 }
        return (try? await ChainRPCClient.fetchERC20BalanceOf(
            userAddress: address,
            tokenContract: SepoliaSwapDemoConfig.contractAddress
        )) ?? 0
    }

    private static func swapETHForVUSDC(
        amount: Decimal,
        walletAddress: String,
        walletPassword: String,
        keystoreJSON: String
    ) async throws -> SepoliaSwapResult {
        guard SepoliaSwapDemoConfig.hasOnChainSwap else { throw SepoliaSwapError.notConfigured }
        let contract = SepoliaSwapDemoConfig.contractAddress
        guard try await ChainRPCClient.contractHasCode(address: contract) else {
            throw SepoliaSwapError.contractNotDeployed
        }

        let valueWei = EVMWeiFormatter.etherToWei(amount)
        guard valueWei > 0 else { throw SepoliaSwapError.invalidAmount }

        let ethBal = try await ChainRPCClient.fetchNativeBalance(address: walletAddress)
        let required = amount + SepoliaSwapDemoConfig.gasReserveEther
        guard ethBal >= required else { throw SepoliaSwapError.insufficientBalance }

        let signed = try await signAndSend(
            keystoreJSON: keystoreJSON,
            password: walletPassword,
            walletAddress: walletAddress,
            to: contract,
            valueWei: valueWei,
            data: SepoliaSwapDemoConfig.swapETHForVUSDCPrefix
        )

        return SepoliaSwapResult(
            transactionHash: signed,
            fromSymbol: "ETH",
            toSymbol: SepoliaSwapDemoConfig.vUSDCSymbol,
            amountIn: amount,
            amountOut: amount
        )
    }

    private static func swapVUSDCForETH(
        amount: Decimal,
        walletAddress: String,
        walletPassword: String,
        keystoreJSON: String
    ) async throws -> SepoliaSwapResult {
        guard SepoliaSwapDemoConfig.hasOnChainSwap else { throw SepoliaSwapError.notConfigured }
        let contract = SepoliaSwapDemoConfig.contractAddress
        guard try await ChainRPCClient.contractHasCode(address: contract) else {
            throw SepoliaSwapError.contractNotDeployed
        }

        let bal = await vUSDCBalance(address: walletAddress)
        guard bal >= amount else { throw SepoliaSwapError.insufficientBalance }

        let amountWei = EVMWeiFormatter.etherToWei(amount)
        let data = SepoliaSwapDemoConfig.swapVUSDCForETHPrefix
            + EVMWeiFormatter.uint256HexData(amountWei)

        let signed = try await signAndSend(
            keystoreJSON: keystoreJSON,
            password: walletPassword,
            walletAddress: walletAddress,
            to: contract,
            valueWei: 0,
            data: data
        )

        return SepoliaSwapResult(
            transactionHash: signed,
            fromSymbol: SepoliaSwapDemoConfig.vUSDCSymbol,
            toSymbol: "ETH",
            amountIn: amount,
            amountOut: amount
        )
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
        return hash
    }
}
