import Foundation

/// Bitrefill 官方 CDN 商品圖（搜尋 API 常不帶 `image` 欄位）
/// 文件：https://docs.bitrefill.com/reference/get_products
enum BitrefillProductImageURLs {
    private static let cdnBase = "https://cdn.bitrefill.com/primg"
    private static let defaultOpts = "w250h250i1"

    /// 優先 API 回傳的圖，否則用 product id 組 CDN 位址
    static func resolved(productId: String, apiImage: String?) -> String? {
        let slug = productId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !slug.isEmpty else { return nil }
        if let api = normalizedURLString(apiImage) {
            return api
        }
        return "\(cdnBase)/\(defaultOpts)/\(slug).webp"
    }

    static func candidateURLs(productId: String, apiImage: String?) -> [URL] {
        var strings: [String] = []
        if let api = normalizedURLString(apiImage) {
            strings.append(api)
        }
        let slug = productId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !slug.isEmpty else {
            return strings.compactMap { URL(string: $0) }
        }
        strings.append("\(cdnBase)/\(defaultOpts)/\(slug).webp")
        strings.append("\(cdnBase)/\(defaultOpts)/\(slug).png")
        var seen = Set<String>()
        return strings.filter { seen.insert($0).inserted }.compactMap { URL(string: $0) }
    }

    private static func normalizedURLString(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("//") {
            return "https:\(trimmed)"
        }
        if trimmed.hasPrefix("/") {
            return "https://cdn.bitrefill.com\(trimmed)"
        }
        guard URL(string: trimmed) != nil else { return nil }
        return trimmed
    }
}
