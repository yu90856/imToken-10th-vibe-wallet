import Foundation

enum EthereumRLP {
    static func encode(_ bytes: [UInt8]) -> [UInt8] {
        if bytes.count == 1, bytes[0] < 0x80 { return bytes }
        return prefixLength(0x80, payload: bytes)
    }

    static func encodeList(_ items: [[UInt8]]) -> [UInt8] {
        let payload = items.reduce(into: [UInt8]()) { $0.append(contentsOf: $1) }
        return prefixLength(0xc0, payload: payload)
    }

    static func encodeInteger(_ value: UInt64) -> [UInt8] {
        if value == 0 { return [0x80] }
        var bytes = withUnsafeBytes(of: value.bigEndian) { Array($0) }
        while bytes.first == 0 { bytes.removeFirst() }
        return encode(bytes)
    }

    static func encodeAddress(_ hex: String) -> [UInt8] {
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        let raw = trimmed.hasPrefix("0x") ? String(trimmed.dropFirst(2)) : trimmed
        guard raw.count == 40, let data = Data(hexString: raw) else {
            return encode([])
        }
        return encode(Array(data))
    }

    static func encodeDataHex(_ hex: String) -> [UInt8] {
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "0x" || trimmed.isEmpty { return encode([]) }
        let raw = trimmed.hasPrefix("0x") ? String(trimmed.dropFirst(2)) : trimmed
        guard let data = Data(hexString: raw), !data.isEmpty else { return encode([]) }
        return encode(Array(data))
    }

    /// ECDSA `r` / `s` 須去掉前導 0x00，否則 go-ethereum 會拒絕（non-canonical integer）
    static func encodeSignatureScalar(_ bytes: [UInt8]) -> [UInt8] {
        var trimmed = bytes
        while trimmed.count > 1, trimmed.first == 0 {
            trimmed.removeFirst()
        }
        if trimmed.isEmpty { return [0x80] }
        return encode(trimmed)
    }

    private static func prefixLength(_ offset: UInt8, payload: [UInt8]) -> [UInt8] {
        if payload.count < 56 {
            return [offset + UInt8(payload.count)] + payload
        }
        var lenBytes = withUnsafeBytes(of: UInt64(payload.count).bigEndian) { Array($0) }
        while lenBytes.first == 0 { lenBytes.removeFirst() }
        return [offset + 55 + UInt8(lenBytes.count)] + lenBytes + payload
    }
}

private extension Data {
    init?(hexString: String) {
        let chars = Array(hexString.lowercased())
        guard chars.count % 2 == 0 else { return nil }
        var bytes = [UInt8]()
        bytes.reserveCapacity(chars.count / 2)
        var index = 0
        while index < chars.count {
            guard let hi = Self.hexValue(chars[index]),
                  let lo = Self.hexValue(chars[index + 1]) else { return nil }
            bytes.append((hi << 4) | lo)
            index += 2
        }
        self = Data(bytes)
    }

    private static func hexValue(_ char: Character) -> UInt8? {
        switch char {
        case "0"..."9": return UInt8(char.asciiValue! - Character("0").asciiValue!)
        case "a"..."f": return UInt8(char.asciiValue! - Character("a").asciiValue! + 10)
        default: return nil
        }
    }
}
