import Foundation

struct BitrefillPackageOption: Sendable, Identifiable, Hashable {
    let id: String
    let value: String
    let priceQuote: Int
    let amount: Decimal?

    var displayLabel: String {
        if let amount {
            return "\(amount) · 報價 \(priceQuote)"
        }
        return "面額 \(value) · 報價 \(priceQuote)"
    }
}

struct BitrefillProductDetail: Sendable, Identifiable {
    let id: String
    let name: String
    let countryName: String
    let currency: String
    let inStock: Bool
    let imageURL: String?
    let packages: [BitrefillPackageOption]
    let terms: String?
}

struct BitrefillInvoiceSummary: Sendable, Identifiable, Hashable {
    let id: String
    let status: String
    let paymentMethod: String
    let paymentAddress: String?
    let paymentPrice: Int?
    let paymentCurrency: String?
    let paymentStatus: String?
    let productName: String
    let packageLabel: String
    let orderId: String?

    var paymentAmountWei: UInt64? {
        guard let paymentPrice, paymentPrice > 0 else { return nil }
        return UInt64(paymentPrice)
    }
}

struct BitrefillRedemptionInfo: Sendable {
    let code: String?
    let link: String?
    let pin: String?
    let instructions: String?
}

enum BitrefillCommerceError: LocalizedError {
    case missingAPIKey
    case httpStatus(Int, String?)
    case decodeFailed
    case productNotFound
    case checkoutFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "請在 Secrets.plist 設定 BITREFILL_API_KEY"
        case .httpStatus(let code, let msg):
            if let msg, !msg.isEmpty { return "Bitrefill HTTP \(code)：\(msg)" }
            return "Bitrefill HTTP \(code)"
        case .decodeFailed:
            return "無法解析 Bitrefill 回應"
        case .productNotFound:
            return "找不到此商品"
        case .checkoutFailed(let msg):
            return msg
        }
    }
}

/// 商品詳情、建立訂單、查詢發票與兌換碼
enum BitrefillCommerceService {
    private static let baseURL = URL(string: "https://api.bitrefill.com/v2")!
    private static let requestTimeout: TimeInterval = 90

    static func fetchProduct(id: String) async -> Result<BitrefillProductDetail, BitrefillCommerceError> {
        await request(path: "products/\(id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id)", method: "GET")
            .flatMapData { data in
                guard let envelope = try? JSONDecoder().decode(BitrefillSingleEnvelope<BitrefillProductDTO>.self, from: data),
                      let dto = envelope.data else {
                    return .failure(.decodeFailed)
                }
                return .success(mapProduct(dto))
            }
    }

    static func createInvoice(
        productId: String,
        packageId: String,
        refundAddress: String,
        paymentMethod: String = "ethereum"
    ) async -> Result<BitrefillInvoiceSummary, BitrefillCommerceError> {
        let body: [String: Any] = [
            "products": [[
                "product_id": productId,
                "package_id": packageId,
                "quantity": 1,
            ]],
            "payment_method": paymentMethod,
            "refund_address": refundAddress,
            "auto_pay": false,
        ]
        guard let payload = try? JSONSerialization.data(withJSONObject: body) else {
            return .failure(.decodeFailed)
        }

        return await request(path: "invoices", method: "POST", body: payload)
            .flatMapData { data in
                parseInvoice(data, productName: productId, packageLabel: packageId)
            }
    }

    static func fetchInvoice(id: String) async -> Result<BitrefillInvoiceSummary, BitrefillCommerceError> {
        await request(path: "invoices/\(id)", method: "GET")
            .flatMapData { data in
                parseInvoice(data, productName: "", packageLabel: "")
            }
    }

    static func payInvoiceFromBalance(id: String) async -> Result<BitrefillInvoiceSummary, BitrefillCommerceError> {
        await request(path: "invoices/\(id)/pay", method: "POST", body: Data("{}".utf8))
            .flatMapData { data in
                parseInvoice(data, productName: "", packageLabel: "")
            }
    }

    static func fetchRedemption(orderId: String) async -> Result<BitrefillRedemptionInfo, BitrefillCommerceError> {
        var components = URLComponents(url: baseURL.appendingPathComponent("orders/\(orderId)"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "include_redemption_info", value: "true")]
        guard let url = components.url else { return .failure(.decodeFailed) }

        return await request(url: url, method: "GET")
            .flatMapData { data in
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let dataObj = json["data"] as? [String: Any],
                      let info = dataObj["redemption_info"] as? [String: Any] else {
                    return .failure(.decodeFailed)
                }
                return .success(
                    BitrefillRedemptionInfo(
                        code: info["code"] as? String ?? info["pin"] as? String,
                        link: info["link"] as? String,
                        pin: info["pin"] as? String,
                        instructions: info["instructions"] as? String
                    )
                )
            }
    }

    // MARK: - Private

    private static func request(
        path: String,
        method: String,
        body: Data? = nil
    ) async -> Result<Data, BitrefillCommerceError> {
        let url = baseURL.appending(path: path)
        return await request(url: url, method: method, body: body)
    }

    private static func request(
        url: URL,
        method: String,
        body: Data? = nil
    ) async -> Result<Data, BitrefillCommerceError> {
        guard let apiKey = SecretsReader.string(for: "BITREFILL_API_KEY") else {
            return .failure(.missingAPIKey)
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.timeoutInterval = requestTimeout
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .failure(.decodeFailed) }
            guard (200 ... 299).contains(http.statusCode) else {
                let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
                    ?? (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String
                return .failure(.httpStatus(http.statusCode, msg))
            }
            return .success(data)
        } catch {
            return .failure(.checkoutFailed(error.localizedDescription))
        }
    }

    private static func mapProduct(_ dto: BitrefillProductDTO) -> BitrefillProductDetail {
        let packages = (dto.packages ?? []).map { pkg in
            BitrefillPackageOption(
                id: pkg.id,
                value: pkg.value,
                priceQuote: pkg.price,
                amount: pkg.amount
            )
        }
        return BitrefillProductDetail(
            id: dto.id,
            name: dto.name,
            countryName: dto.country_name ?? "",
            currency: dto.currency ?? "USD",
            inStock: dto.in_stock ?? true,
            imageURL: BitrefillProductImageURLs.resolved(productId: dto.id, apiImage: dto.image),
            packages: packages,
            terms: dto.termsAndConditions
        )
    }

    private static func parseInvoice(
        _ data: Data,
        productName: String,
        packageLabel: String
    ) -> Result<BitrefillInvoiceSummary, BitrefillCommerceError> {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataObj = json["data"] as? [String: Any],
              let invoiceId = dataObj["id"] as? String else {
            return .failure(.decodeFailed)
        }
        let payment = dataObj["payment"] as? [String: Any]
        let orders = dataObj["orders"] as? [[String: Any]]
        let firstOrder = orders?.first
        let orderProduct = firstOrder?["product"] as? [String: Any]

        let summary = BitrefillInvoiceSummary(
            id: invoiceId,
            status: dataObj["status"] as? String ?? "unknown",
            paymentMethod: payment?["method"] as? String ?? "",
            paymentAddress: payment?["address"] as? String,
            paymentPrice: payment?["price"] as? Int,
            paymentCurrency: payment?["currency"] as? String,
            paymentStatus: payment?["status"] as? String,
            productName: orderProduct?["name"] as? String ?? productName,
            packageLabel: (orderProduct?["value"] as? String).map { "USD \($0)" } ?? packageLabel,
            orderId: firstOrder?["id"] as? String
        )
        return .success(summary)
    }
}

private struct BitrefillSingleEnvelope<T: Decodable>: Decodable {
    let data: T?
}

private struct BitrefillProductDTO: Decodable {
    let id: String
    let name: String
    let country_name: String?
    let currency: String?
    let in_stock: Bool?
    let image: String?
    let termsAndConditions: String?
    let packages: [BitrefillPackageDTO]?
}

private struct BitrefillPackageDTO: Decodable {
    let id: String
    let value: String
    let price: Int
    let amount: Decimal?
}

private extension Result where Success == Data, Failure == BitrefillCommerceError {
    func flatMapData<T>(_ transform: (Data) -> Result<T, BitrefillCommerceError>) -> Result<T, BitrefillCommerceError> {
        switch self {
        case .success(let data): return transform(data)
        case .failure(let error): return .failure(error)
        }
    }
}
