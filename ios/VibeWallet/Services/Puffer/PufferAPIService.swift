import Foundation

struct PufferExchangeRate: Sendable {
    let pufEthPerEth: Decimal
    let ethPerPufEth: Decimal
    let rawPufEthPerEth: String
}

enum PufferAPIError: LocalizedError {
    case invalidURL
    case httpStatus(Int)
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Puffer API 網址無效"
        case .httpStatus(let code): return "Puffer API 請求失敗（HTTP \(code)）"
        case .decodeFailed: return "無法解析 Puffer 匯率資料"
        }
    }
}

enum PufferAPIService {
    static func fetchExchangeRate() async throws -> PufferExchangeRate {
        guard let url = URL(string: "\(PufferDemoConfig.hackathonAPIBase)/pufeth/rate") else {
            throw PufferAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw PufferAPIError.decodeFailed }
        guard (200..<300).contains(http.statusCode) else {
            throw PufferAPIError.httpStatus(http.statusCode)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let pufPerEthRaw = json["pufEthPerEth"] as? String,
              let pufPerEth = Decimal(string: pufPerEthRaw),
              pufPerEth > 0 else {
            throw PufferAPIError.decodeFailed
        }
        let ethPerPuf: Decimal
        if let ethPerPufRaw = json["ethPerPufEth"] as? String,
           let parsed = Decimal(string: ethPerPufRaw) {
            ethPerPuf = parsed
        } else {
            ethPerPuf = 1 / pufPerEth
        }
        return PufferExchangeRate(
            pufEthPerEth: pufPerEth,
            ethPerPufEth: ethPerPuf,
            rawPufEthPerEth: pufPerEthRaw
        )
    }

    /// API 限流或離線時的演示匯率
    static var fallbackExchangeRate: PufferExchangeRate {
        PufferExchangeRate(
            pufEthPerEth: Decimal(string: "0.959") ?? 0.959,
            ethPerPufEth: Decimal(string: "1.042") ?? 1.042,
            rawPufEthPerEth: "0.959"
        )
    }
}
