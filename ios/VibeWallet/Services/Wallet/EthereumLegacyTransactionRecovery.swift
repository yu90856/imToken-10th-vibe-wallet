import Foundation
import secp256k1

/// 從已簽 Legacy EIP-155 交易還原 `from` 地址，用於核對 tcx 簽名是否與預期地址一致
enum EthereumLegacyTransactionRecovery {
    static func recoverSender(
        fromRawTransaction raw: String,
        expectedChainId: Int = ChainConfig.active.id,
        expectedAddress: String? = nil
    ) throws -> String {
        let candidates = try recoverSenderCandidates(
            fromRawTransaction: raw,
            expectedChainId: expectedChainId
        )
        guard !candidates.isEmpty else { throw WalletError.signingFailed }

        if let expected = expectedAddress?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           expected.hasPrefix("0x"), expected.count == 42 {
            if let hit = candidates.first(where: { $0.lowercased() == expected }) {
                return hit
            }
            throw WalletError.signingFailedWithDetail(
                "無法還原為預期地址 \(expected)，候選：\(candidates.joined(separator: ", "))"
            )
        }
        return candidates[0]
    }

    /// 嘗試 Frontier / EIP-155 等多種還原方式（tcx `sign_tx` 常為 v=27/28）
    static func recoverSenderCandidates(
        fromRawTransaction raw: String,
        expectedChainId: Int = ChainConfig.active.id
    ) throws -> [String] {
        let hex = raw.hasPrefix("0x") ? String(raw.dropFirst(2)) : raw
        guard let data = Data(hexString: hex), !data.isEmpty else {
            throw WalletError.signingFailed
        }
        let items = try RLP.decode(data)
        guard case .list(let fields) = items, fields.count == 9 else {
            throw WalletError.signingFailed
        }

        let nonce = try fields[0].asUInt64()
        let gasPrice = try fields[1].asUInt64()
        let gasLimit = try fields[2].asUInt64()
        let to = fields[3]
        let value = try fields[4].asUInt64()
        let dataField = fields[5]
        let v = try fields[6].asUInt64()
        let rBytes = try fields[7].asBytes()
        let sBytes = try fields[8].asBytes()

        var unique: [String] = []
        var seen = Set<String>()

        func append(_ address: String?) {
            guard let address else { return }
            let key = address.lowercased()
            guard seen.insert(key).inserted else { return }
            unique.append(address)
        }

        if v < 35 {
            for recoveryId in [0, 1] {
                append(try? recoverFromDigest(
                    nonce: nonce,
                    gasPrice: gasPrice,
                    gasLimit: gasLimit,
                    to: to,
                    value: value,
                    dataField: dataField,
                    unsigned: EthereumRLP.encodeList([
                        EthereumRLP.encodeInteger(nonce),
                        EthereumRLP.encodeInteger(gasPrice),
                        EthereumRLP.encodeInteger(gasLimit),
                        encodeRLPItem(to),
                        EthereumRLP.encodeInteger(value),
                        encodeRLPItem(dataField),
                    ]),
                    rBytes: rBytes,
                    sBytes: sBytes,
                    recoveryId: recoveryId
                ))
            }
        }

        for recoveryId in [0, 1] {
            let adjusted = Int(v) - 35 - recoveryId
            guard adjusted > 0, adjusted % 2 == 0 else { continue }
            let chainId = adjusted / 2
            append(try? recoverFromDigest(
                nonce: nonce,
                gasPrice: gasPrice,
                gasLimit: gasLimit,
                to: to,
                value: value,
                dataField: dataField,
                unsigned: EthereumRLP.encodeList([
                    EthereumRLP.encodeInteger(nonce),
                    EthereumRLP.encodeInteger(gasPrice),
                    EthereumRLP.encodeInteger(gasLimit),
                    encodeRLPItem(to),
                    EthereumRLP.encodeInteger(value),
                    encodeRLPItem(dataField),
                    EthereumRLP.encodeInteger(UInt64(chainId)),
                    EthereumRLP.encodeInteger(0),
                    EthereumRLP.encodeInteger(0),
                ]),
                rBytes: rBytes,
                sBytes: sBytes,
                recoveryId: recoveryId
            ))
        }

        for recoveryId in [0, 1] {
            append(try? recoverFromDigest(
                nonce: nonce,
                gasPrice: gasPrice,
                gasLimit: gasLimit,
                to: to,
                value: value,
                dataField: dataField,
                unsigned: EthereumRLP.encodeList([
                    EthereumRLP.encodeInteger(nonce),
                    EthereumRLP.encodeInteger(gasPrice),
                    EthereumRLP.encodeInteger(gasLimit),
                    encodeRLPItem(to),
                    EthereumRLP.encodeInteger(value),
                    encodeRLPItem(dataField),
                    EthereumRLP.encodeInteger(UInt64(expectedChainId)),
                    EthereumRLP.encodeInteger(0),
                    EthereumRLP.encodeInteger(0),
                ]),
                rBytes: rBytes,
                sBytes: sBytes,
                recoveryId: recoveryId
            ))
        }

        return unique
    }

    private static func recoverFromDigest(
        nonce: UInt64,
        gasPrice: UInt64,
        gasLimit: UInt64,
        to: RLPItem,
        value: UInt64,
        dataField: RLPItem,
        unsigned: [UInt8],
        rBytes: [UInt8],
        sBytes: [UInt8],
        recoveryId: Int
    ) throws -> String {
        let digest = Keccak256.hash(unsigned)

        var ctx = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_VERIFY))!
        defer { secp256k1_context_destroy(ctx) }

        var compact = [UInt8](repeating: 0, count: 64)
        compact[0..<32] = ArraySlice(padSignatureComponent(rBytes))
        compact[32..<64] = ArraySlice(padSignatureComponent(sBytes))
        var recoverable = secp256k1_ecdsa_recoverable_signature()
        guard secp256k1_ecdsa_recoverable_signature_parse_compact(ctx, &recoverable, &compact, Int32(recoveryId)) == 1 else {
            throw WalletError.signingFailed
        }
        var pubkey = secp256k1_pubkey()
        guard secp256k1_ecdsa_recover(ctx, &pubkey, &recoverable, digest) == 1 else {
            throw WalletError.signingFailed
        }
        var serialized = [UInt8](repeating: 0, count: 65)
        var length = 65
        guard secp256k1_ec_pubkey_serialize(
            ctx,
            &serialized,
            &length,
            &pubkey,
            UInt32(SECP256K1_EC_UNCOMPRESSED)
        ) == 1 else {
            throw WalletError.signingFailed
        }
        let hash = Keccak256.hash(Array(serialized.dropFirst()))
        let addr = hash.suffix(20)
        return "0x" + addr.map { String(format: "%02x", $0) }.joined()
    }

    /// 修正 tcx / 部分簽名器產生的非 canonical RLP（`r`/`s` 前導零）
    static func canonicalizeRawTransaction(_ raw: String) throws -> String {
        let hex = raw.hasPrefix("0x") ? String(raw.dropFirst(2)) : raw
        guard let data = Data(hexString: hex), !data.isEmpty else {
            throw WalletError.signingFailed
        }
        let items = try RLP.decode(data)
        guard case .list(let fields) = items, fields.count == 9 else {
            throw WalletError.signingFailed
        }

        let parts: [[UInt8]] = try fields.enumerated().map { index, field in
            switch index {
            case 0, 1, 2, 4, 6:
                return EthereumRLP.encodeInteger(try field.asUInt64())
            case 3:
                let bytes = try field.asBytes()
                if bytes.count == 20 {
                    let addr = "0x" + bytes.map { String(format: "%02x", $0) }.joined()
                    return EthereumRLP.encodeAddress(addr)
                }
                return EthereumRLP.encode(bytes)
            case 5:
                let bytes = try field.asBytes()
                if bytes.isEmpty { return EthereumRLP.encode([]) }
                return EthereumRLP.encode(bytes)
            case 7, 8:
                return EthereumRLP.encodeSignatureScalar(try field.asBytes())
            default:
                throw WalletError.signingFailed
            }
        }

        let encoded = EthereumRLP.encodeList(parts)
        return "0x" + encoded.map { String(format: "%02x", $0) }.joined()
    }

    struct LegacyFeeSummary: Sendable {
        let nonce: UInt64
        let gasPrice: UInt64
        let gasLimit: UInt64
        let valueWei: UInt64
        let maxCostWei: UInt64
    }

    /// 已簽名 legacy 交易的 tx hash（Keccak256(RLP)）
    static func transactionHash(fromRawTransaction raw: String) throws -> String {
        let hex = raw.hasPrefix("0x") ? String(raw.dropFirst(2)) : raw
        guard let data = Data(hexString: hex), !data.isEmpty else {
            throw WalletError.signingFailed
        }
        let hash = Keccak256.hash(Array(data))
        return "0x" + hash.map { String(format: "%02x", $0) }.joined()
    }

    static func legacyFeeSummary(fromRawTransaction raw: String) throws -> LegacyFeeSummary {
        let hex = raw.hasPrefix("0x") ? String(raw.dropFirst(2)) : raw
        guard let data = Data(hexString: hex), !data.isEmpty else {
            throw WalletError.signingFailed
        }
        let items = try RLP.decode(data)
        guard case .list(let fields) = items, fields.count == 9 else {
            throw WalletError.signingFailed
        }
        let nonce = try fields[0].asUInt64()
        let gasPrice = try fields[1].asUInt64()
        let gasLimit = try fields[2].asUInt64()
        let valueWei = try fields[4].asUInt64()
        let gasCost = gasLimit.multipliedReportingOverflow(by: gasPrice)
        let maxCost = gasCost.partialValue.addingReportingOverflow(valueWei)
        guard !gasCost.overflow && !maxCost.overflow else {
            throw WalletError.signingFailed
        }
        return LegacyFeeSummary(
            nonce: nonce,
            gasPrice: gasPrice,
            gasLimit: gasLimit,
            valueWei: valueWei,
            maxCostWei: maxCost.partialValue
        )
    }

    static func valueWei(fromRawTransaction raw: String) throws -> UInt64 {
        let hex = raw.hasPrefix("0x") ? String(raw.dropFirst(2)) : raw
        guard let data = Data(hexString: hex), !data.isEmpty else {
            throw WalletError.signingFailed
        }
        let items = try RLP.decode(data)
        guard case .list(let fields) = items, fields.count == 9 else {
            throw WalletError.signingFailed
        }
        return try fields[4].asUInt64()
    }

    /// RLP 可能去掉 `r`/`s` 前導零；secp256k1 compact 仍需 32-byte 欄位
    private static func padSignatureComponent(_ bytes: [UInt8]) -> [UInt8] {
        if bytes.count >= 32 { return Array(bytes.suffix(32)) }
        return [UInt8](repeating: 0, count: 32 - bytes.count) + bytes
    }

    private static func encodeRLPItem(_ item: RLPItem) -> [UInt8] {
        switch item {
        case .bytes(let data):
            return EthereumRLP.encode(Array(data))
        case .list(let nested):
            return EthereumRLP.encodeList(nested.map { encodeRLPItem($0) })
        }
    }
}

private enum RLPItem {
    case bytes(Data)
    case list([RLPItem])

    func asUInt64() throws -> UInt64 {
        guard case .bytes(let data) = self else { throw WalletError.signingFailed }
        if data.isEmpty { return 0 }
        if data.count == 1, data[0] < 0x80 { return UInt64(data[0]) }
        var value: UInt64 = 0
        for byte in data {
            value = (value << 8) + UInt64(byte)
        }
        return value
    }

    func asBytes() throws -> [UInt8] {
        guard case .bytes(let data) = self else { throw WalletError.signingFailed }
        return Array(data)
    }
}

private enum RLP {
    static func decode(_ data: Data) throws -> RLPItem {
        let bytes = Array(data)
        let (item, _) = try decodeItem(bytes, index: 0)
        return item
    }

    private static func decodeItem(_ bytes: [UInt8], index: Int) throws -> (RLPItem, Int) {
        guard index < bytes.count else { throw WalletError.signingFailed }
        let prefix = bytes[index]
        if prefix < 0x80 {
            return (.bytes(Data([prefix])), index + 1)
        }
        if prefix <= 0xb7 {
            let length = Int(prefix - 0x80)
            let start = index + 1
            let end = start + length
            guard end <= bytes.count else { throw WalletError.signingFailed }
            return (.bytes(Data(bytes[start..<end])), end)
        }
        if prefix <= 0xbf {
            let lenOfLen = Int(prefix - 0xb7)
            let start = index + 1
            let end = start + lenOfLen
            guard end <= bytes.count else { throw WalletError.signingFailed }
            let length = try parseLength(bytes[start..<end])
            let payloadStart = end
            let payloadEnd = payloadStart + length
            guard payloadEnd <= bytes.count else { throw WalletError.signingFailed }
            return (.bytes(Data(bytes[payloadStart..<payloadEnd])), payloadEnd)
        }
        if prefix <= 0xf7 {
            let length = Int(prefix - 0xc0)
            let start = index + 1
            let end = start + length
            guard end <= bytes.count else { throw WalletError.signingFailed }
            return try decodeList(bytes, start: start, end: end)
        }
        let lenOfLen = Int(prefix - 0xf7)
        let start = index + 1
        let end = start + lenOfLen
        guard end <= bytes.count else { throw WalletError.signingFailed }
        let length = try parseLength(bytes[start..<end])
        let payloadStart = end
        let payloadEnd = payloadStart + length
        guard payloadEnd <= bytes.count else { throw WalletError.signingFailed }
        return try decodeList(bytes, start: payloadStart, end: payloadEnd)
    }

    private static func decodeList(_ bytes: [UInt8], start: Int, end: Int) throws -> (RLPItem, Int) {
        var items: [RLPItem] = []
        var cursor = start
        while cursor < end {
            let (item, next) = try decodeItem(bytes, index: cursor)
            items.append(item)
            cursor = next
        }
        return (.list(items), end)
    }

    private static func parseLength(_ bytes: ArraySlice<UInt8>) throws -> Int {
        guard !bytes.isEmpty else { throw WalletError.signingFailed }
        var length = 0
        for byte in bytes {
            length = (length << 8) + Int(byte)
        }
        return length
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
