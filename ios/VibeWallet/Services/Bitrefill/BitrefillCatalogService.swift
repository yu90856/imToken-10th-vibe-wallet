import Foundation

struct BitrefillProductMatch: Sendable, Identifiable, Hashable {
    let id: String
    let name: String
    let countryName: String
    let inStock: Bool
    let imageURL: String?
}

enum BitrefillCatalogError: LocalizedError {
    case missingAPIKey
    case invalidQuery
    case httpStatus(Int)
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "請在 Config/Secrets.plist 設定 BITREFILL_API_KEY（開發者後台取得）"
        case .invalidQuery:
            return "搜尋字串無效"
        case .httpStatus(let code):
            return "Bitrefill API 失敗（HTTP \(code)）"
        case .decodeFailed:
            return "無法解析 Bitrefill 商品資料"
        }
    }
}

/// Bitrefill 商品搜尋（REST v2）
enum BitrefillCatalogService {
    private static let baseURL = URL(string: "https://api.bitrefill.com/v2")!

    static func search(query: String, limit: Int = 3) async -> Result<[BitrefillProductMatch], BitrefillCatalogError> {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 100 else {
            return .failure(.invalidQuery)
        }
        guard let apiKey = SecretsReader.string(for: "BITREFILL_API_KEY") else {
            return .failure(.missingAPIKey)
        }

        var components = URLComponents(url: baseURL.appendingPathComponent("products/search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "q", value: trimmed),
            URLQueryItem(name: "limit", value: String(min(max(limit, 1), 10))),
            URLQueryItem(name: "include_test_products", value: "true"),
        ]
        guard let url = components.url else { return .failure(.invalidQuery) }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .failure(.decodeFailed) }
            guard (200 ... 299).contains(http.statusCode) else {
                return .failure(.httpStatus(http.statusCode))
            }
            let decoded = try JSONDecoder().decode(BitrefillSearchEnvelope.self, from: data)
            let matches = (decoded.data ?? []).map(mapProduct)
            return .success(matches)
        } catch let error as BitrefillCatalogError {
            return .failure(error)
        } catch {
            return .failure(.decodeFailed)
        }
    }

    fileprivate static func mapProduct(_ dto: BitrefillProductDTO) -> BitrefillProductMatch {
        BitrefillProductMatch(
            id: dto.id,
            name: dto.name,
            countryName: dto.country_name ?? "",
            inStock: dto.in_stock ?? true,
            imageURL: BitrefillProductImageURLs.resolved(productId: dto.id, apiImage: dto.resolvedImageURL)
        )
    }
}

private struct BitrefillSearchEnvelope: Decodable {
    let data: [BitrefillProductDTO]?
}

private struct BitrefillProductDTO: Decodable {
    let id: String
    let name: String
    let country_name: String?
    let in_stock: Bool?
    let image: String?
    let logo: String?

    var resolvedImageURL: String? {
        let candidate = image?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? logo?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let candidate, !candidate.isEmpty, URL(string: candidate) != nil else { return nil }
        return candidate
    }
}
