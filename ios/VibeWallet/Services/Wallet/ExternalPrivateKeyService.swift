import Foundation
import secp256k1

/// 私鑰導入（與 Web `externalPrivateKey` keystore 對齊）。tcx-wasm 不支援此格式，地址與簽名在本機完成。
enum ExternalPrivateKeyService {
    static let keystoreType = "externalPrivateKey"

    static func normalizePrivateKey(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let hex = trimmed.hasPrefix("0x") || trimmed.hasPrefix("0X")
            ? String(trimmed.dropFirst(2))
            : trimmed
        guard hex.count == 64, hex.allSatisfy(\.isHexDigit) else { return nil }
        return hex.lowercased()
    }

    static func externalPrivateKeyKeystore(privateKeyHex: String) -> String {
        JSONSerialization.safeString([
            "type": keystoreType,
            "key": privateKeyHex,
        ]) ?? "{\"type\":\"externalPrivateKey\",\"key\":\"\(privateKeyHex)\"}"
    }

    static func isExternalPrivateKeyKeystore(_ keystoreJSON: String) -> Bool {
        guard let data = keystoreJSON.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return false }
        return type == keystoreType
    }

    static func privateKeyHex(from keystoreJSON: String) -> String? {
        guard let data = keystoreJSON.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let key = json["key"] as? String else { return nil }
        return normalizePrivateKey(key)
    }

    static func compressedPublicKey(fromPrivateKeyHex hex: String) throws -> [UInt8] {
        let key = try privateKeyBytes(hex: hex)
        let pubkey = try uncompressedPublicKey(privateKey: key)
        let x = Array(pubkey[1..<33])
        let y = pubkey[33]
        var out = [UInt8]()
        out.append((y & 1) == 0 ? 0x02 : 0x03)
        out.append(contentsOf: x)
        return out
    }

    static func ethereumAddress(fromPrivateKeyHex hex: String) throws -> String {
        let key = try privateKeyBytes(hex: hex)
        let pubkey = try uncompressedPublicKey(privateKey: key)
        let hash = Keccak256.hash(Array(pubkey.dropFirst()))
        let addr = hash.suffix(20)
        return "0x" + addr.map { String(format: "%02x", $0) }.joined()
    }

    static func signEthereumLegacyTransaction(
        privateKeyHex: String,
        to: String,
        valueWei: UInt64,
        data: String,
        nonce: UInt64,
        gasLimit: UInt64,
        gasPrice: UInt64,
        chainId: Int = ChainConfig.active.id
    ) throws -> TokenCoreService.SignedEthereumTransaction {
        let key = try privateKeyBytes(hex: privateKeyHex)
        let unsigned = EthereumRLP.encodeList([
            EthereumRLP.encodeInteger(nonce),
            EthereumRLP.encodeInteger(gasPrice),
            EthereumRLP.encodeInteger(gasLimit),
            EthereumRLP.encodeAddress(to),
            EthereumRLP.encodeInteger(valueWei),
            EthereumRLP.encodeDataHex(data),
            EthereumRLP.encodeInteger(UInt64(chainId)),
            EthereumRLP.encodeInteger(0),
            EthereumRLP.encodeInteger(0),
        ])
        let digest = Keccak256.hash(unsigned)
        let (v, r, s) = try signDigest(digest, privateKey: key, chainId: chainId)
        let signed = EthereumRLP.encodeList([
            EthereumRLP.encodeInteger(nonce),
            EthereumRLP.encodeInteger(gasPrice),
            EthereumRLP.encodeInteger(gasLimit),
            EthereumRLP.encodeAddress(to),
            EthereumRLP.encodeInteger(valueWei),
            EthereumRLP.encodeDataHex(data),
            EthereumRLP.encodeInteger(v),
            EthereumRLP.encodeSignatureScalar(r),
            EthereumRLP.encodeSignatureScalar(s),
        ])
        let raw = "0x" + signed.map { String(format: "%02x", $0) }.joined()
        return TokenCoreService.SignedEthereumTransaction(rawTransaction: raw, txHash: nil)
    }

    // MARK: - secp256k1

    private static func privateKeyBytes(hex: String) throws -> [UInt8] {
        guard let normalized = normalizePrivateKey(hex),
              let data = Data(hexString: normalized) else {
            throw WalletError.invalidPrivateKey
        }
        return Array(data)
    }

    private static func uncompressedPublicKey(privateKey: [UInt8]) throws -> [UInt8] {
        var ctx = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN))!
        defer { secp256k1_context_destroy(ctx) }
        var seckey = privateKey
        var pubkey = secp256k1_pubkey()
        guard secp256k1_ec_pubkey_create(ctx, &pubkey, &seckey) == 1 else {
            throw WalletError.invalidPrivateKey
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
            throw WalletError.invalidPrivateKey
        }
        return Array(serialized.prefix(length))
    }

    private static func signDigest(
        _ digest: [UInt8],
        privateKey: [UInt8],
        chainId: Int
    ) throws -> (v: UInt64, r: [UInt8], s: [UInt8]) {
        guard digest.count == 32 else { throw WalletError.signingFailed }
        var ctx = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN))!
        defer { secp256k1_context_destroy(ctx) }
        var seckey = privateKey
        var signature = secp256k1_ecdsa_recoverable_signature()
        guard secp256k1_ecdsa_sign_recoverable(ctx, &signature, digest, &seckey, nil, nil) == 1 else {
            throw WalletError.signingFailed
        }
        var compact = [UInt8](repeating: 0, count: 64)
        var recid: Int32 = 0
        guard secp256k1_ecdsa_recoverable_signature_serialize_compact(ctx, &compact, &recid, &signature) == 1 else {
            throw WalletError.signingFailed
        }
        let r = Array(compact[0..<32])
        let s = Array(compact[32..<64])
        let v = UInt64(recid) + UInt64(chainId) * 2 + 35
        return (v, r, s)
    }
}

private extension JSONSerialization {
    static func safeString(_ object: [String: Any]) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              let string = String(data: data, encoding: .utf8) else { return nil }
        return string
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
