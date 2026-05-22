import CommonCrypto
import CryptoKit
import Foundation
import secp256k1

/// 由 BIP39 助記詞推導 Ethereum 私鑰（與 `m/44'/60'/0'/0/0`、空 passphrase 對齊 ethers / Token Core）
enum EthereumMnemonicDerivation {
    static func privateKeyHex(
        mnemonic: String,
        derivationPath: String = ChainConfig.active.derivationPath
    ) throws -> String {
        let phrase = TokenCoreService.normalizeMnemonic(mnemonic)
        guard !phrase.isEmpty else { throw WalletError.invalidMnemonic }
        let seed = try mnemonicSeed(from: phrase)
        let key = try deriveHDPrivateKey(seed: seed, path: derivationPath)
        return key.map { String(format: "%02x", $0) }.joined()
    }

    /// 推導結果應與 `ExternalPrivateKeyService.ethereumAddress` / tcx 地址一致
    static func verifyMatchesAddress(mnemonic: String, expectedAddress: String) -> Bool {
        guard let hex = try? privateKeyHex(mnemonic: mnemonic),
              let derived = try? ExternalPrivateKeyService.ethereumAddress(fromPrivateKeyHex: hex) else {
            return false
        }
        return derived.lowercased() == expectedAddress.lowercased()
    }

    // MARK: - BIP39

    private static func mnemonicSeed(from mnemonic: String) throws -> [UInt8] {
        let normalized = mnemonic.decomposedStringWithCompatibilityMapping
        let password = Array(normalized.utf8)
        let salt = Array("mnemonic".utf8)
        return try pbkdf2SHA512(password: password, salt: salt, iterations: 2048, keyLength: 64)
    }

    private static func pbkdf2SHA512(
        password: [UInt8],
        salt: [UInt8],
        iterations: UInt32,
        keyLength: Int
    ) throws -> [UInt8] {
        var derived = [UInt8](repeating: 0, count: keyLength)
        let status = derived.withUnsafeMutableBytes { derivedBytes in
            password.withUnsafeBytes { passwordBytes in
                salt.withUnsafeBytes { saltBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        password.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA512),
                        iterations,
                        derivedBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        keyLength
                    )
                }
            }
        }
        guard status == kCCSuccess else { throw WalletError.derivationFailed }
        return derived
    }

    // MARK: - BIP32

    private static func deriveHDPrivateKey(seed: [UInt8], path: String) throws -> [UInt8] {
        let master = try masterKey(from: seed)
        let components = try parsePath(path)
        var key = master.privateKey
        var chain = master.chainCode
        for component in components {
            (key, chain) = try deriveChild(privateKey: key, chainCode: chain, index: component)
        }
        return key
    }

    private struct MasterKey {
        let privateKey: [UInt8]
        let chainCode: [UInt8]
    }

    private static func masterKey(from seed: [UInt8]) throws -> MasterKey {
        let digest = hmacSHA512(key: Array("Bitcoin seed".utf8), data: seed)
        var privateKey = normalizedPrivateKey32(Array(digest[0..<32]))
        var ctx = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN))!
        defer { secp256k1_context_destroy(ctx) }
        guard secp256k1_ec_seckey_verify(ctx, &privateKey) == 1 else {
            throw WalletError.derivationFailed
        }
        return MasterKey(privateKey: privateKey, chainCode: Array(digest[32..<64]))
    }

    private static func deriveChild(
        privateKey: [UInt8],
        chainCode: [UInt8],
        index: UInt32
    ) throws -> ([UInt8], [UInt8]) {
        let hardened = (index & 0x8000_0000) != 0
        var data = [UInt8]()
        let parentKey = normalizedPrivateKey32(privateKey)
        if hardened {
            data.append(0x00)
            data.append(contentsOf: parentKey)
        } else {
            let hex = parentKey.map { String(format: "%02x", $0) }.joined()
            data.append(contentsOf: try ExternalPrivateKeyService.compressedPublicKey(fromPrivateKeyHex: hex))
        }
        data.append(UInt8((index >> 24) & 0xff))
        data.append(UInt8((index >> 16) & 0xff))
        data.append(UInt8((index >> 8) & 0xff))
        data.append(UInt8(index & 0xff))
        let digest = hmacSHA512(key: chainCode, data: data)
        var childKey = parentKey
        try tweakPrivateKey(&childKey, with: Array(digest[0..<32]))
        return (childKey, Array(digest[32..<64]))
    }

    private static func normalizedPrivateKey32(_ key: [UInt8]) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: 32)
        let start = max(0, 32 - key.count)
        out.replaceSubrange(start..<32, with: key.suffix(32))
        return out
    }

    private static func tweakPrivateKey(_ privateKey: inout [UInt8], with tweak: [UInt8]) throws {
        guard privateKey.count == 32, tweak.count == 32 else {
            throw WalletError.derivationFailed
        }
        var ctx = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN))!
        defer { secp256k1_context_destroy(ctx) }
        guard secp256k1_ec_privkey_tweak_add(ctx, &privateKey, tweak) == 1 else {
            throw WalletError.derivationFailed
        }
    }

    private static func parsePath(_ path: String) throws -> [UInt32] {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("m/") else { throw WalletError.derivationFailed }
        let body = trimmed.dropFirst(2)
        if body.isEmpty { return [] }
        return try body.split(separator: "/").map { segment in
            let hardened = segment.hasSuffix("'")
            let numberPart = hardened ? segment.dropLast() : segment[...]
            guard let value = UInt32(numberPart) else { throw WalletError.derivationFailed }
            return hardened ? value + 0x8000_0000 : value
        }
    }

    private static func addPrivateKeys(lhs: [UInt8], rhs: [UInt8]) throws -> [UInt8] {
        let sum = (Secp256k256Scalar(lhs) + Secp256k256Scalar(rhs)).reduced()
        guard sum != Secp256k256Scalar.zero else { throw WalletError.derivationFailed }
        return sum.bytes32
    }

    private static func hmacSHA512(key: [UInt8], data: [UInt8]) -> [UInt8] {
        let symmetricKey = SymmetricKey(data: key)
        let mac = HMAC<SHA512>.authenticationCode(for: data, using: symmetricKey)
        return Array(mac)
    }
}

// MARK: - secp256k1 256-bit scalar (mod n)

private struct Secp256k256Scalar: Equatable {
    static let zero = Secp256k256Scalar(bytes32: [UInt8](repeating: 0, count: 32))
    static let curveOrder = Secp256k256Scalar(bytes32: [
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFE,
        0xBA, 0xAE, 0xDC, 0xE6, 0xAF, 0x48, 0xA0, 0x3B,
        0xBF, 0xD2, 0x5E, 0x8C, 0xD0, 0x36, 0x41, 0x41,
    ])

    let bytes32: [UInt8]

    init(_ bytes: [UInt8]) {
        var padded = [UInt8](repeating: 0, count: 32)
        let start = max(0, 32 - bytes.count)
        padded.replaceSubrange(start..<32, with: bytes.suffix(32))
        bytes32 = padded
    }

    init(bytes32: [UInt8]) {
        self.bytes32 = bytes32
    }

    static func + (lhs: Secp256k256Scalar, rhs: Secp256k256Scalar) -> Secp256k256Scalar {
        var out = [UInt8](repeating: 0, count: 32)
        var carry = 0
        for index in stride(from: 31, through: 0, by: -1) {
            let sum = Int(lhs.bytes32[index]) + Int(rhs.bytes32[index]) + carry
            out[index] = UInt8(sum & 0xff)
            carry = sum >> 8
        }
        return Secp256k256Scalar(bytes32: out)
    }

    func reduced() -> Secp256k256Scalar {
        var value = self
        while value >= Self.curveOrder {
            value = value - Self.curveOrder
        }
        return value
    }

    static func - (lhs: Secp256k256Scalar, rhs: Secp256k256Scalar) -> Secp256k256Scalar {
        var out = [UInt8](repeating: 0, count: 32)
        var borrow = 0
        for index in stride(from: 31, through: 0, by: -1) {
            var minuend = Int(lhs.bytes32[index]) - borrow
            let subtrahend = Int(rhs.bytes32[index])
            if minuend < subtrahend {
                minuend += 256
                borrow = 1
            } else {
                borrow = 0
            }
            out[index] = UInt8((minuend - subtrahend) & 0xff)
        }
        return Secp256k256Scalar(bytes32: out)
    }

    static func < (lhs: Secp256k256Scalar, rhs: Secp256k256Scalar) -> Bool {
        for index in 0..<32 where lhs.bytes32[index] != rhs.bytes32[index] {
            return lhs.bytes32[index] < rhs.bytes32[index]
        }
        return false
    }

    static func >= (lhs: Secp256k256Scalar, rhs: Secp256k256Scalar) -> Bool {
        lhs == rhs || !(lhs < rhs)
    }
}
