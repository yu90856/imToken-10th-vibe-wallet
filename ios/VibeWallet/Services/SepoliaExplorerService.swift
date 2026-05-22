import Foundation

enum SepoliaExplorerError: LocalizedError {
    case invalidURL
    case httpStatus(Int)
    case apiError(String)
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "區塊瀏覽器 API 網址無效"
        case .httpStatus(let code): return "區塊瀏覽器請求失敗（HTTP \(code)）"
        case .apiError(let message): return message
        case .decodeFailed: return "無法解析交易紀錄"
        }
    }
}

/// Sepolia Etherscan 帳戶交易（原生 + ERC-20 風格 token 轉移）
enum SepoliaExplorerService {
    /// Etherscan API V2（Sepolia chainId = 11155111）
    private static let apiBase = "https://api.etherscan.io/v2/api"
    private static let sepoliaChainId = "11155111"

    static func fetchTransactions(
        walletAddress: String,
        limit: Int = 40
    ) async throws -> [TokenTransaction] {
        Array(try await fetchNativeTxList(address: walletAddress).prefix(limit))
    }

    static func transactions(
        for holdingId: String,
        walletAddress: String,
        limit: Int = 30
    ) async throws -> [TokenTransaction] {
        switch holdingId {
        case "eth-native":
            return Array(try await fetchNativeTxList(address: walletAddress).prefix(limit))
        case "puffer-pufeth":
            let vault = PufferDemoConfig.sepoliaVaultAddress.lowercased()
            return try await fetchNativeTxList(address: walletAddress)
                .filter { tx in
                    (tx.counterparty?.lowercased().contains(String(vault.dropFirst(2))) ?? false)
                        || (tx.kind == .swap && tx.amount.contains("合約"))
                }
                .prefix(limit)
                .map { $0 }
        case "vibe-vusdc":
            guard SepoliaSwapDemoConfig.hasOnChainSwap else { return [] }
            let swap = SepoliaSwapDemoConfig.contractAddress.lowercased()
            return try await fetchNativeTxList(address: walletAddress)
                .filter { tx in
                    (tx.counterparty?.lowercased().contains(String(swap.dropFirst(2))) ?? false)
                        || (tx.kind == .swap && tx.amount.contains("合約"))
                }
                .prefix(limit)
                .map { $0 }
        default:
            return try await fetchTransactions(walletAddress: walletAddress, limit: limit)
        }
    }

    private static func fetchNativeTxList(address: String) async throws -> [TokenTransaction] {
        if let key = SecretsReader.string(for: "ETHERSCAN_API_KEY"), !key.isEmpty,
           let list = try? await fetchNativeFromEtherscan(address: address),
           !list.isEmpty {
            return list
        }
        return try await fetchNativeFromBlockscout(address: address)
    }

    private static func fetchNativeFromEtherscan(address: String) async throws -> [TokenTransaction] {
        let rows = try await apiRequest(
            module: "account",
            action: "txlist",
            address: address,
            extra: ["startblock": "0", "endblock": "99999999", "sort": "desc"]
        )
        let wallet = address.lowercased()
        return rows.compactMap { row -> TokenTransaction? in
            guard let hash = row["hash"] as? String,
                  let from = (row["from"] as? String)?.lowercased(),
                  let to = (row["to"] as? String)?.lowercased(),
                  let ts = UInt64(row["timeStamp"] as? String ?? ""),
                  let valueWei = row["value"] as? String else { return nil }

            let value = weiStringToDecimal(valueWei)
            let input = (row["input"] as? String) ?? "0x"
            let status = (row["txreceipt_status"] as? String) == "1" ? "成功" : "失敗"

            let kind: TokenTransaction.Kind
            let amount: String
            let counterparty: String?

            if input.count > 10 {
                if input.hasPrefix(SepoliaSwapDemoConfig.swapETHForVUSDCPrefix)
                    || input.hasPrefix(PufferDemoConfig.depositSelector) {
                    kind = .swap
                    amount = "-\(formatEth(value)) ETH（合約）"
                    counterparty = to
                } else if input.hasPrefix(PufferDemoConfig.withdrawSelector) {
                    kind = .swap
                    amount = "解質押 pufETH → ETH"
                    counterparty = to
                } else {
                    kind = .contract
                    amount = "合約呼叫"
                    counterparty = to
                }
            } else if from == wallet, value > 0 {
                kind = .send
                amount = "-\(formatEth(value)) ETH"
                counterparty = "→ \(shortAddress(to))"
            } else if to == wallet, value > 0 {
                kind = .receive
                amount = "+\(formatEth(value)) ETH"
                counterparty = "← \(shortAddress(from))"
            } else if from == wallet {
                kind = .send
                amount = "0 ETH"
                counterparty = shortAddress(to)
            } else {
                kind = .receive
                amount = value > 0 ? "+\(formatEth(value)) ETH" : "0 ETH"
                counterparty = shortAddress(from)
            }

            return TokenTransaction(
                id: hash,
                hash: hash,
                kind: kind,
                amount: amount,
                counterparty: counterparty,
                timestamp: Date(timeIntervalSince1970: TimeInterval(ts)),
                status: status
            )
        }
    }

    private static func fetchNativeFromBlockscout(address: String) async throws -> [TokenTransaction] {
        guard let url = URL(string: "https://eth-sepolia.blockscout.com/api/v2/addresses/\(address)/transactions") else {
            throw SepoliaExplorerError.invalidURL
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 25
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw SepoliaExplorerError.httpStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]] else {
            throw SepoliaExplorerError.decodeFailed
        }

        let wallet = address.lowercased()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return items.compactMap { item -> TokenTransaction? in
            guard let hash = item["hash"] as? String else { return nil }
            let fromHash = ((item["from"] as? [String: Any])?["hash"] as? String)?.lowercased() ?? ""
            let toHash = ((item["to"] as? [String: Any])?["hash"] as? String)?.lowercased() ?? ""
            let valueWei = item["value"] as? String ?? "0"
            let value = weiStringToDecimal(valueWei)
            let method = (item["method"] as? String) ?? ""
            let input = method.hasPrefix("0x") ? method : "0x"
            let status = (item["status"] as? String) == "ok" ? "成功" : "失敗"

            let ts: Date
            if let tsStr = item["timestamp"] as? String,
               let parsed = formatter.date(from: tsStr) {
                ts = parsed
            } else {
                ts = Date()
            }

            let kind: TokenTransaction.Kind
            let amount: String
            let counterparty: String?

            if input.hasPrefix(SepoliaSwapDemoConfig.swapETHForVUSDCPrefix)
                || input.hasPrefix(PufferDemoConfig.depositSelector) {
                kind = .swap
                amount = "-\(formatEth(value)) ETH → 鑄造演示代幣"
                counterparty = shortAddress(toHash)
            } else if input.hasPrefix(PufferDemoConfig.withdrawSelector) {
                kind = .swap
                amount = "解質押 pufETH → ETH"
                counterparty = shortAddress(toHash)
            } else if input.count > 10 {
                kind = .contract
                amount = "合約呼叫"
                counterparty = shortAddress(toHash)
            } else if fromHash == wallet, value > 0 {
                kind = .send
                amount = "-\(formatEth(value)) ETH"
                counterparty = "→ \(shortAddress(toHash))"
            } else if toHash == wallet, value > 0 {
                kind = .receive
                amount = "+\(formatEth(value)) ETH"
                counterparty = "← \(shortAddress(fromHash))"
            } else if fromHash == wallet {
                kind = .send
                amount = "0 ETH"
                counterparty = shortAddress(toHash)
            } else {
                kind = .receive
                amount = value > 0 ? "+\(formatEth(value)) ETH" : "0 ETH"
                counterparty = shortAddress(fromHash)
            }

            return TokenTransaction(
                id: hash,
                hash: hash,
                kind: kind,
                amount: amount,
                counterparty: counterparty,
                timestamp: ts,
                status: status
            )
        }
    }

    private static func fetchTokenTxList(address: String) async throws -> [TokenTransaction] {
        let rows = try await apiRequest(
            module: "account",
            action: "tokentx",
            address: address,
            extra: ["startblock": "0", "endblock": "99999999", "sort": "desc"]
        )
        let wallet = address.lowercased()
        return rows.compactMap { row -> TokenTransaction? in
            guard let hash = row["hash"] as? String,
                  let from = (row["from"] as? String)?.lowercased(),
                  let to = (row["to"] as? String)?.lowercased(),
                  let symbol = row["tokenSymbol"] as? String,
                  let ts = UInt64(row["timeStamp"] as? String ?? ""),
                  let valueWei = row["value"] as? String else { return nil }

            let value = weiStringToDecimal(valueWei)
            let status = (row["txreceipt_status"] as? String) == "1" ? "成功" : "成功"

            let kind: TokenTransaction.Kind = .swap
            let signed = from == wallet ? "-" : "+"
            let amount = "\(signed)\(formatEth(value)) \(symbol)"
            let counterparty = from == wallet ? shortAddress(to) : shortAddress(from)

            return TokenTransaction(
                id: "\(hash)-token",
                hash: hash,
                kind: kind,
                amount: amount,
                counterparty: counterparty,
                timestamp: Date(timeIntervalSince1970: TimeInterval(ts)),
                status: status
            )
        }
    }

    private static func apiRequest(
        module: String,
        action: String,
        address: String,
        extra: [String: String] = [:]
    ) async throws -> [[String: Any]] {
        var items = [
            URLQueryItem(name: "chainid", value: sepoliaChainId),
            URLQueryItem(name: "module", value: module),
            URLQueryItem(name: "action", value: action),
            URLQueryItem(name: "address", value: address),
        ]
        for (k, v) in extra { items.append(URLQueryItem(name: k, value: v)) }
        if let key = SecretsReader.string(for: "ETHERSCAN_API_KEY"), !key.isEmpty {
            items.append(URLQueryItem(name: "apikey", value: key))
        }
        var components = URLComponents(string: apiBase)!
        components.queryItems = items
        guard let url = components.url else { throw SepoliaExplorerError.invalidURL }

        var request = URLRequest(url: url)
        request.timeoutInterval = 25
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SepoliaExplorerError.decodeFailed }
        guard (200..<300).contains(http.statusCode) else {
            throw SepoliaExplorerError.httpStatus(http.statusCode)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SepoliaExplorerError.decodeFailed
        }
        let status = json["status"] as? String
        let message = json["message"] as? String ?? "Unknown"
        if status != "1" {
            if message == "No transactions found" { return [] }
            throw SepoliaExplorerError.apiError(message)
        }
        guard let result = json["result"] as? [[String: Any]] else {
            if let arr = json["result"] as? [Any], arr.isEmpty { return [] }
            throw SepoliaExplorerError.decodeFailed
        }
        return result
    }

    private static func weiStringToDecimal(_ wei: String) -> Decimal {
        guard let big = Decimal(string: wei) else { return 0 }
        return big / Decimal(1_000_000_000_000_000_000)
    }

    private static func formatEth(_ eth: Decimal) -> String {
        WalletOnChainHoldingsService.formatAmount(eth, maxFraction: 6)
    }

    private static func shortAddress(_ address: String) -> String {
        guard address.count > 12 else { return address }
        return "\(address.prefix(6))…\(address.suffix(4))"
    }
}
