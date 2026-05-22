import Foundation

enum ChainRPCError: LocalizedError {
    case invalidURL
    case httpStatus(Int)
    case rpcError(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "RPC 網址無效"
        case .httpStatus(let code): return "RPC 請求失敗（HTTP \(code)）"
        case .rpcError(let message): return message
        case .invalidResponse: return "RPC 回傳格式無法解析"
        }
    }
}

/// 讀取 EVM 鏈原生幣餘額（eth_getBalance）
enum ChainRPCClient {
    private static let weiPerEther: Decimal = 1_000_000_000_000_000_000

    static func fetchNativeBalance(
        address: String,
        chain: EVMChain = ChainConfig.active
    ) async throws -> Decimal {
        let hex = try await call(method: "eth_getBalance", params: [address, "latest"], rpcURL: chain.rpcURL)
        guard let hexString = hex as? String else { throw ChainRPCError.invalidResponse }
        return weiHexToEther(hexString)
    }

    static func contractHasCode(address: String, rpcURL: String = ChainConfig.active.rpcURL) async throws -> Bool {
        let hex = try await call(method: "eth_getCode", params: [address, "latest"], rpcURL: rpcURL)
        guard let code = hex as? String else { throw ChainRPCError.invalidResponse }
        let stripped = code.trimmingCharacters(in: .whitespacesAndNewlines)
        return stripped != "0x" && stripped != "0x0" && !stripped.isEmpty
    }

    /// ERC-20 / 演示代幣 `balanceOf(address)` — selector 0x70a08231
    static func fetchERC20BalanceOf(
        userAddress: String,
        tokenContract: String,
        rpcURL: String = ChainConfig.active.rpcURL
    ) async throws -> Decimal {
        let addr = userAddress.lowercased().replacingOccurrences(of: "0x", with: "")
        guard addr.count == 40 else { throw ChainRPCError.invalidResponse }
        let data = "0x70a08231000000000000000000000000\(addr)"
        let hex = try await call(
            method: "eth_call",
            params: [[
                "to": tokenContract,
                "data": data,
            ], "latest"],
            rpcURL: rpcURL
        )
        guard let hexString = hex as? String else { throw ChainRPCError.invalidResponse }
        return weiHexToEther(hexString)
    }

    static func fetchDemoVaultPufETHBalance(
        userAddress: String,
        vaultAddress: String,
        rpcURL: String = ChainConfig.active.rpcURL
    ) async throws -> Decimal {
        let wei = try await fetchERC20BalanceWeiDecimal(
            userAddress: userAddress,
            tokenContract: vaultAddress,
            rpcURL: rpcURL
        )
        return EVMWeiFormatter.weiToEther(wei)
    }

    static func fetchERC20BalanceWeiHex(
        userAddress: String,
        tokenContract: String,
        rpcURL: String = ChainConfig.active.rpcURL
    ) async throws -> String {
        let addr = userAddress.lowercased().replacingOccurrences(of: "0x", with: "")
        guard addr.count == 40 else { throw ChainRPCError.invalidResponse }
        let data = "0x70a08231000000000000000000000000\(addr)"
        let hex = try await call(
            method: "eth_call",
            params: [[
                "to": tokenContract,
                "data": data,
            ], "latest"],
            rpcURL: rpcURL
        )
        guard let hexString = hex as? String else { throw ChainRPCError.invalidResponse }
        return EVMWeiFormatter.normalizedUInt256Hex(hexString)
    }

    static func fetchERC20BalanceWeiDecimal(
        userAddress: String,
        tokenContract: String,
        rpcURL: String = ChainConfig.active.rpcURL
    ) async throws -> Decimal {
        let hex64 = try await fetchERC20BalanceWeiHex(
            userAddress: userAddress,
            tokenContract: tokenContract,
            rpcURL: rpcURL
        )
        return EVMWeiFormatter.weiHexToDecimal("0x" + hex64)
    }

    /// 演示 Vault `exchangeRateWei()` — 決定贖回 ETH 數量
    static func fetchDemoVaultExchangeRateWei(
        vaultAddress: String,
        rpcURL: String = ChainConfig.active.rpcURL
    ) async throws -> Decimal {
        let hex = try await call(
            method: "eth_call",
            params: [[
                "to": vaultAddress,
                "data": "0x77cf3559",
            ], "latest"],
            rpcURL: rpcURL
        )
        guard let hexString = hex as? String else { throw ChainRPCError.invalidResponse }
        return EVMWeiFormatter.weiHexToDecimal(hexString)
    }

    static func fetchTransactionCount(
        address: String,
        block: String = "pending",
        rpcURL: String = ChainConfig.active.rpcURL
    ) async throws -> UInt64 {
        let hex = try await call(method: "eth_getTransactionCount", params: [address, block], rpcURL: rpcURL)
        guard let hexString = hex as? String else { throw ChainRPCError.invalidResponse }
        return UInt64(hexString.dropFirst(2), radix: 16) ?? 0
    }

    static func fetchNativeBalanceWei(
        address: String,
        rpcURL: String = ChainConfig.active.rpcURL
    ) async throws -> UInt64 {
        let decimal = try await fetchNativeBalanceWeiDecimal(address: address, rpcURL: rpcURL)
        guard decimal <= Decimal(UInt64.max) else {
            throw ChainRPCError.invalidResponse
        }
        return NSDecimalNumber(decimal: decimal).uint64Value
    }

    static func fetchNativeBalanceWeiDecimal(
        address: String,
        rpcURL: String = ChainConfig.active.rpcURL
    ) async throws -> Decimal {
        let hex = try await call(method: "eth_getBalance", params: [address, "latest"], rpcURL: rpcURL)
        guard let hexString = hex as? String else { throw ChainRPCError.invalidResponse }
        return EVMWeiFormatter.weiHexToDecimal(hexString)
    }

    /// 廣播用 gasPrice：在 RPC 建議值上加成，避免 Sepolia 測試網因 gas 過低長期 Pending。
    static func fetchGasPrice(
        rpcURL: String = ChainConfig.active.rpcURL,
        chain: EVMChain = ChainConfig.active
    ) async throws -> UInt64 {
        let hex = try await call(method: "eth_gasPrice", params: [], rpcURL: rpcURL)
        guard let hexString = hex as? String else { throw ChainRPCError.invalidResponse }
        let rpcWei = UInt64(hexString.dropFirst(2), radix: 16) ?? 0
        return broadcastGasPrice(rpcWei: rpcWei, chain: chain)
    }

    /// Sepolia：至少 15 gwei，且為 RPC 的 3 倍；主網：至少 2 gwei，RPC × 1.5。
    static func broadcastGasPrice(rpcWei: UInt64, chain: EVMChain = ChainConfig.active) -> UInt64 {
        if chain.isTestnet {
            let tripled = rpcWei &+ rpcWei &+ rpcWei
            let floor: UInt64 = 15_000_000_000
            return max(tripled, floor)
        }
        let bumped = rpcWei + rpcWei / 2
        let floor: UInt64 = 2_000_000_000
        return max(bumped, floor)
    }

    static func minimumBroadcastGasPrice(chain: EVMChain = ChainConfig.active) -> UInt64 {
        chain.isTestnet ? 15_000_000_000 : 2_000_000_000
    }

    static func assertSignedTransactionGasPrice(
        signedRaw: String,
        chain: EVMChain = ChainConfig.active
    ) throws {
        let normalized = try EthereumLegacyTransactionRecovery.canonicalizeRawTransaction(signedRaw)
        let fee = try EthereumLegacyTransactionRecovery.legacyFeeSummary(fromRawTransaction: normalized)
        let minRequired = minimumBroadcastGasPrice(chain: chain)
        guard fee.gasPrice >= minRequired else {
            let gwei = Double(fee.gasPrice) / 1e9
            let minGwei = Double(minRequired) / 1e9
            throw ChainRPCError.rpcError(
                String(
                    format: "簽名交易 Gas 過低（%.2f gwei，需要 ≥ %.0f gwei）。請更新 App 後重試。",
                    gwei,
                    minGwei
                )
            )
        }
    }

    static func estimateGas(
        from: String,
        to: String,
        valueWei: UInt64,
        data: String = "0x",
        rpcURL: String = ChainConfig.active.rpcURL
    ) async throws -> UInt64 {
        let tx: [String: Any] = [
            "from": from,
            "to": to,
            "value": EVMWeiFormatter.hexQuantity(valueWei),
            "data": data,
        ]
        let hex = try await call(method: "eth_estimateGas", params: [tx], rpcURL: rpcURL)
        guard let hexString = hex as? String else { throw ChainRPCError.invalidResponse }
        let estimated = UInt64(hexString.dropFirst(2), radix: 16) ?? 21_000
        return estimated + 20_000
    }

    static func sendRawTransaction(
        signedRaw: String,
        rpcURL: String = ChainConfig.active.rpcURL
    ) async throws -> String {
        let normalized = try EthereumLegacyTransactionRecovery.canonicalizeRawTransaction(signedRaw)
        let hex = try await call(method: "eth_sendRawTransaction", params: [normalized], rpcURL: rpcURL)
        guard let hash = hex as? String, hash.hasPrefix("0x") else {
            throw ChainRPCError.invalidResponse
        }
        return hash
    }

    /// 驗證簽名 gas、多節點廣播，並確認交易至少被一個節點收錄（避免 Etherscan 查不到的幽靈 hash）。
    static func sendRawTransactionReliable(
        signedRaw: String,
        chain: EVMChain = ChainConfig.active
    ) async throws -> String {
        try assertSignedTransactionGasPrice(signedRaw: signedRaw, chain: chain)
        let normalized = try EthereumLegacyTransactionRecovery.canonicalizeRawTransaction(signedRaw)
        let localHash = try EthereumLegacyTransactionRecovery.transactionHash(fromRawTransaction: normalized)

        var broadcastErrors: [String] = []
        var nodeHash: String?
        for rpcURL in chain.broadcastRPCURLs {
            do {
                let hash = try await sendRawTransaction(signedRaw: normalized, rpcURL: rpcURL)
                nodeHash = hash
                if hash.lowercased() != localHash.lowercased() {
                    broadcastErrors.append("\(rpcURL): hash 不一致")
                }
                break
            } catch {
                broadcastErrors.append("\(rpcURL): \(error.localizedDescription ?? "send 失敗")")
            }
        }
        guard let txHash = nodeHash else {
            throw ChainRPCError.rpcError(
                "無法廣播交易：" + broadcastErrors.joined(separator: "；")
            )
        }

        try await assertTransactionVisible(txHash: txHash, chain: chain)
        return txHash
    }

    private static func assertTransactionVisible(
        txHash: String,
        chain: EVMChain,
        timeoutSeconds: TimeInterval = 25
    ) async throws {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            for rpcURL in chain.broadcastRPCURLs {
                if try await fetchTransactionExists(hash: txHash, rpcURL: rpcURL) {
                    return
                }
            }
            try await Task.sleep(nanoseconds: 2_000_000_000)
        }
        throw ChainRPCError.rpcError(
            """
            交易已送出但 Sepolia 節點未收錄（可能已被丟棄），請勿重複質押。
            請先「清除 Pending」後再試。Hash：\(txHash)
            """
        )
    }

    private static func fetchTransactionExists(hash: String, rpcURL: String) async throws -> Bool {
        let result = try await call(method: "eth_getTransactionByHash", params: [hash], rpcURL: rpcURL)
        guard let dict = result as? [String: Any], !dict.isEmpty else { return false }
        return dict["hash"] != nil
    }

    /// 等待交易上鏈並確認成功（status == 1）
    static func waitForTransactionSuccess(
        txHash: String,
        timeoutSeconds: TimeInterval? = nil,
        pollIntervalSeconds: TimeInterval = 2,
        chain: EVMChain = ChainConfig.active
    ) async throws {
        let timeout = timeoutSeconds ?? (chain.isTestnet ? 180 : 90)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            for rpcURL in chain.broadcastRPCURLs {
                if let receipt = try await fetchTransactionReceipt(hash: txHash, rpcURL: rpcURL) {
                    if receipt.success {
                        return
                    }
                    throw ChainRPCError.rpcError("交易已上鏈但執行失敗（revert）")
                }
            }
            try await Task.sleep(nanoseconds: UInt64(pollIntervalSeconds * 1_000_000_000))
        }
        throw ChainRPCError.rpcError(
            """
            等待確認逾時（Sepolia 可能壅塞）。請在 Etherscan 查看，勿重複送出相同操作。
            \(txHash)
            """
        )
    }

    private static func fetchTransactionReceipt(
        hash: String,
        rpcURL: String
    ) async throws -> (success: Bool, blockNumber: UInt64)? {
        let result = try await call(method: "eth_getTransactionReceipt", params: [hash], rpcURL: rpcURL)
        guard let dict = result as? [String: Any], !dict.isEmpty else { return nil }
        let statusHex = dict["status"] as? String ?? "0x0"
        let success = statusHex == "0x1"
        let blockHex = dict["blockNumber"] as? String ?? "0x0"
        let block = UInt64(blockHex.dropFirst(2), radix: 16) ?? 0
        return (success, block)
    }

    static func fetchChainId(rpcURL: String = ChainConfig.active.rpcURL) async throws -> Int {
        let hex = try await call(method: "eth_chainId", params: [], rpcURL: rpcURL)
        guard let hexString = hex as? String, let value = UInt64(hexString.dropFirst(2), radix: 16) else {
            throw ChainRPCError.invalidResponse
        }
        return Int(value)
    }

    static func fetchNativeUsdPrice(chain: EVMChain = ChainConfig.active) async throws -> Decimal {
        guard let url = URL(
            string: "https://api.coingecko.com/api/v3/simple/price?ids=\(chain.coingeckoId)&vs_currencies=usd"
        ) else {
            throw ChainRPCError.invalidURL
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ChainRPCError.httpStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let coin = json[chain.coingeckoId] as? [String: Any],
              let usd = coin["usd"] as? Double else {
            throw ChainRPCError.invalidResponse
        }
        return Decimal(usd)
    }

    private static func call(method: String, params: [Any], rpcURL: String) async throws -> Any {
        guard let url = URL(string: rpcURL) else { throw ChainRPCError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20
        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "method": method,
            "params": params,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ChainRPCError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw ChainRPCError.httpStatus(http.statusCode)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ChainRPCError.invalidResponse
        }
        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            throw ChainRPCError.rpcError(message)
        }
        guard let result = json["result"] else { throw ChainRPCError.invalidResponse }
        return result
    }

    private static func weiHexToEther(_ hex: String) -> Decimal {
        EVMWeiFormatter.weiToEther(EVMWeiFormatter.weiHexToDecimal(hex))
    }
}
