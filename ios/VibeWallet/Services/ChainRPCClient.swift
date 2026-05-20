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
        let cleaned = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex
        guard !cleaned.isEmpty else { return 0 }
        var wei = Decimal(0)
        for char in cleaned {
            guard let digit = Int(String(char), radix: 16) else { return 0 }
            wei = wei * 16 + Decimal(digit)
        }
        return wei / weiPerEther
    }
}
