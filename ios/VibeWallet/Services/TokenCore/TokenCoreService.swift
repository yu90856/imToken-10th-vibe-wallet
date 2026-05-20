import Foundation

/// Swift 封裝，對齊 Web 端 `src/lib/tokenCore.ts` + `ChainConfig.active`
enum TokenCoreService {
    private static var chainId: String { String(ChainConfig.active.id) }
    private static var tokenCoreNetwork: String { ChainConfig.tokenCoreNetwork }

    static func normalizeMnemonic(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    static func mnemonicToWords(_ phrase: String) -> [String] {
        normalizeMnemonic(phrase).split(separator: " ").map(String.init)
    }

    /// 建立新錢包：分三步呼叫 WASM（較省記憶體，避免單次 createWallet 在真機上壓垮 WebKit）
    static func createWallet(password: String) async throws -> (mnemonic: String, keystoreJSON: String, address: String) {
        let keystoreJSON = try await createKeystore(password: password, mnemonic: nil)
        let mnemonic = try await exportMnemonic(keystoreJSON: keystoreJSON, password: password)
        let address = try await deriveEthereumAddress(keystoreJSON: keystoreJSON, password: password)
        return (mnemonic, keystoreJSON, address)
    }

    /// 匯入助記詞
    static func importWallet(mnemonic: String, password: String) async throws -> (keystoreJSON: String, address: String) {
        let phrase = normalizeMnemonic(mnemonic)
        let keystoreJSON = try await createKeystore(password: password, mnemonic: phrase)
        let address = try await deriveEthereumAddress(keystoreJSON: keystoreJSON, password: password)
        return (keystoreJSON, address)
    }

    private static func walletCreationPayload(password: String, mnemonic: String?) -> [String: Any] {
        var payload: [String: Any] = [
            "password": password,
            "network": tokenCoreNetwork,
            "derivations": [
                [
                    "chain": "ETHEREUM",
                    "derivationPath": ChainConfig.active.derivationPath,
                    "chainId": chainId,
                    "network": tokenCoreNetwork,
                ],
            ],
        ]
        if let mnemonic { payload["mnemonic"] = mnemonic }
        return payload
    }

    static func isValidMnemonic(_ raw: String, password: String = "validate-only") async -> Bool {
        let phrase = normalizeMnemonic(raw)
        let words = phrase.split(separator: " ")
        guard [12, 15, 18, 21, 24].contains(words.count) else { return false }
        do {
            _ = try await createKeystore(password: password, mnemonic: phrase)
            return true
        } catch {
            return false
        }
    }

    static func verifyPassword(keystoreJSON: String, password: String) async throws -> String {
        try await deriveEthereumAddress(keystoreJSON: keystoreJSON, password: password)
    }

    // MARK: - Token Core WASM（與 Web 相同 JSON 參數）

    private static func createKeystore(password: String, mnemonic: String?) async throws -> String {
        var payload: [String: Any] = [
            "password": password,
            "network": tokenCoreNetwork,
        ]
        if let mnemonic { payload["mnemonic"] = mnemonic }
        return try await TokenCoreBridge.shared.call("createKeystore", payload: payload)
    }

    private static func exportMnemonic(keystoreJSON: String, password: String) async throws -> String {
        let raw = try await TokenCoreBridge.shared.call(
            "exportMnemonic",
            payload: [
                "keystoreJson": keystoreJSON,
                "password": password,
            ]
        )
        guard let data = raw.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let mnemonic = json["mnemonic"] as? String else {
            throw TokenCoreError.invalidResponse
        }
        return normalizeMnemonic(mnemonic)
    }

    private static func deriveEthereumAddress(keystoreJSON: String, password: String) async throws -> String {
        let derivationRequest: [String: Any] = [
            "keystoreJson": keystoreJSON,
            "key": password,
            "derivations": [
                [
                    "chain": "ETHEREUM",
                    "derivationPath": ChainConfig.active.derivationPath,
                    "chainId": chainId,
                    "network": tokenCoreNetwork,
                ],
            ],
        ]
        let raw = try await TokenCoreBridge.shared.call(
            "deriveAccounts",
            payload: ["derivationRequest": derivationRequest]
        )
        return try parseDerivedAddress(from: raw)
    }

    private static func parseDerivedAddress(from raw: String) throws -> String {
        guard let data = raw.data(using: .utf8) else {
            throw TokenCoreError.invalidResponse
        }
        let parsed = try JSONSerialization.jsonObject(with: data)
        let accounts: [[String: Any]]
        if let array = parsed as? [[String: Any]] {
            accounts = array
        } else if let dict = parsed as? [String: Any],
                  let nested = dict["accounts"] as? [[String: Any]] {
            accounts = nested
        } else {
            throw TokenCoreError.invalidResponse
        }
        let eth = accounts.first { ($0["chain"] as? String) == "ETHEREUM" } ?? accounts.first
        guard let address = eth?["address"] as? String, !address.isEmpty else {
            throw TokenCoreError.invalidResponse
        }
        return address
    }
}
