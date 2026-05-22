import Foundation

/// Swift 封裝，對齊 Web 端 `src/lib/tokenCore.ts` + `ChainConfig.active`
enum TokenCoreService {
    struct SigningContext: Sendable {
        let address: String
        /// tcx `sign_tx` / `derive_accounts` 使用的 network（MAINNET 或 TESTNET）
        let tcxNetwork: String
    }

    private static var chainId: String { String(ChainConfig.active.id) }
    private static var tokenCoreNetwork: String { ChainConfig.tokenCoreNetwork }
    /// 推導／簽名候選（舊 Keystore 可能 MAINNET / TESTNET 推導出不同地址）
    private static let tcxNetworkCandidates = ["MAINNET", "TESTNET"]

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
        if ExternalPrivateKeyService.isExternalPrivateKeyKeystore(keystoreJSON) {
            return try verifyExternalPrivateKeyPassword(keystoreJSON: keystoreJSON, password: password)
        }
        return try await deriveEthereumAddress(keystoreJSON: keystoreJSON, password: password)
    }

    /// 與錢包畫面／匯入一致的單一地址（Keystore MAINNET 推導）
    static func resolveSigningContext(
        keystoreJSON: String,
        password: String,
        preferredAddress: String? = nil
    ) async throws -> SigningContext {
        if ExternalPrivateKeyService.isExternalPrivateKeyKeystore(keystoreJSON) {
            let address = try verifyExternalPrivateKeyPassword(
                keystoreJSON: keystoreJSON,
                password: password
            )
            return SigningContext(address: address, tcxNetwork: "MAINNET")
        }

        let address = try await deriveEthereumAddress(
            keystoreJSON: keystoreJSON,
            password: password,
            tcxNetwork: tokenCoreNetwork
        )
        if let preferred = preferredAddress?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           preferred.hasPrefix("0x"), preferred.count == 42,
           preferred != address.lowercased() {
            throw WalletError.signingFailedWithDetail(
                """
                畫面地址 \(preferred) 與本機 Keystore 地址 \(address) 不一致。
                請「設定 → 移除錢包」後，僅用助記詞重新匯入。
                """
            )
        }
        return SigningContext(address: address, tcxNetwork: tokenCoreNetwork)
    }

    /// 列出 Keystore 可推導的 EVM 地址（MAINNET + TESTNET）
    static func allSigningCandidates(
        keystoreJSON: String,
        password: String
    ) async throws -> [SigningContext] {
        if ExternalPrivateKeyService.isExternalPrivateKeyKeystore(keystoreJSON) {
            let address = try verifyExternalPrivateKeyPassword(
                keystoreJSON: keystoreJSON,
                password: password
            )
            return [SigningContext(address: address, tcxNetwork: "MAINNET")]
        }

        var unique: [SigningContext] = []
        for network in tcxNetworkCandidates {
            guard let address = try? await deriveEthereumAddress(
                keystoreJSON: keystoreJSON,
                password: password,
                tcxNetwork: network
            ) else { continue }
            if !unique.contains(where: { $0.address.lowercased() == address.lowercased() }) {
                unique.append(SigningContext(address: address, tcxNetwork: network))
            }
        }
        guard !unique.isEmpty else { throw WalletError.invalidPassword }
        return unique
    }

    /// 優先以助記詞本機推導私鑰簽名（與水龍頭／Etherscan 地址一致），失敗再嘗試 tcx
    static func signEthereumLegacyTransactionWithSepoliaFunds(
        keystoreJSON: String,
        password: String,
        to: String,
        valueWei: UInt64,
        data: String = "0x",
        gasLimit: UInt64,
        gasPrice: UInt64,
        chainId: Int = ChainConfig.active.id,
        preferredAddress: String?
    ) async throws -> (signed: SignedEthereumTransaction, context: SigningContext) {
        let feeWei = EVMWeiFormatter.transactionCostWei(
            valueWei: valueWei,
            gasLimit: gasLimit,
            gasPrice: gasPrice
        )

        if ExternalPrivateKeyService.isExternalPrivateKeyKeystore(keystoreJSON),
           let privateKeyHex = ExternalPrivateKeyService.privateKeyHex(from: keystoreJSON) {
            let address = try ExternalPrivateKeyService.ethereumAddress(fromPrivateKeyHex: privateKeyHex)
            let nonce = try await ChainRPCClient.fetchTransactionCount(address: address)
            let signed = try ExternalPrivateKeyService.signEthereumLegacyTransaction(
                privateKeyHex: privateKeyHex,
                to: to,
                valueWei: valueWei,
                data: data,
                nonce: nonce,
                gasLimit: gasLimit,
                gasPrice: gasPrice,
                chainId: chainId
            )
            return (signed, SigningContext(address: address, tcxNetwork: "MAINNET"))
        }

        let candidates = try await allSigningCandidates(keystoreJSON: keystoreJSON, password: password)
        var scored: [(SigningContext, Decimal)] = []
        for candidate in candidates {
            let balance = (try? await ChainRPCClient.fetchNativeBalance(address: candidate.address)) ?? 0
            scored.append((candidate, balance))
        }

        if let preferred = preferredAddress?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           preferred.hasPrefix("0x"), preferred.count == 42,
           !candidates.contains(where: { $0.address.lowercased() == preferred }),
           (try? await ChainRPCClient.fetchNativeBalance(address: preferred)) ?? 0 > 0 {
            throw WalletError.signingFailedWithDetail(
                """
                畫面地址 \(preferred) 與本機 Keystore 可簽名地址不一致。
                請到「設定 → 移除錢包」後，僅用助記詞重新匯入，並確認領水地址與 App 顯示相同。
                """
            )
        }

        let ranked = scored.sorted { $0.1 > $1.1 }
        var failures: [String] = []

        // 助記詞錢包：僅 tcx（與 Keystore 一致；本機 BIP44 易與 tcx 推導不一致）
        if !ExternalPrivateKeyService.isExternalPrivateKeyKeystore(keystoreJSON) {
            for (context, balance) in ranked where balance > 0 {
                let nonce = try await ChainRPCClient.fetchTransactionCount(address: context.address)
                do {
                    return try await attemptTcxSign(
                        context: context,
                        keystoreJSON: keystoreJSON,
                        password: password,
                        to: to,
                        valueWei: valueWei,
                        data: data,
                        nonce: nonce,
                        gasLimit: gasLimit,
                        gasPrice: gasPrice,
                        chainId: chainId
                    )
                } catch let error as WalletError {
                    if case .signingFailedWithDetail(let detail) = error {
                        failures.append("tcx \(context.address): \(detail)")
                    } else {
                        failures.append("tcx \(context.address): \(error.localizedDescription ?? "簽名失敗")")
                    }
                } catch {
                    failures.append("tcx \(context.address): \(error.localizedDescription)")
                }
            }

            let detail = failures.isEmpty ? "無可用地址" : failures.joined(separator: "；")
            throw WalletError.signingFailedWithDetail(detail)
        }

        for (context, balance) in ranked {
            guard balance > 0 else {
                failures.append("\(context.address) 餘額 0")
                continue
            }
            let nonce = try await ChainRPCClient.fetchTransactionCount(address: context.address)
            do {
                return try await attemptTcxSign(
                    context: context,
                    keystoreJSON: keystoreJSON,
                    password: password,
                    to: to,
                    valueWei: valueWei,
                    data: data,
                    nonce: nonce,
                    gasLimit: gasLimit,
                    gasPrice: gasPrice,
                    chainId: chainId
                )
            } catch let error as WalletError {
                if case .signingFailedWithDetail(let detail) = error {
                    failures.append("\(context.address) [\(context.tcxNetwork)] \(detail)")
                } else {
                    failures.append("\(context.address) [\(context.tcxNetwork)] \(error.localizedDescription ?? "簽名失敗")")
                }
            } catch {
                failures.append("\(context.address) [\(context.tcxNetwork)] \(error.localizedDescription)")
            }
        }

        let detail = failures.isEmpty ? "無可用地址" : failures.joined(separator: "；")
        throw WalletError.signingFailedWithDetail(detail)
    }

    /// 由助記詞 + BIP44 本機簽名（避開 tcx sign_tx 與 derive 地址不一致）
    private static func attemptMnemonicLocalSign(
        keystoreJSON: String,
        password: String,
        to: String,
        valueWei: UInt64,
        data: String,
        gasLimit: UInt64,
        gasPrice: UInt64,
        chainId: Int,
        minCostWei: Decimal,
        preferredAddress: String?
    ) async throws -> (signed: SignedEthereumTransaction, context: SigningContext) {
        let phrase = try await exportMnemonic(keystoreJSON: keystoreJSON, password: password)
        let tcxAddress = try await deriveEthereumAddress(
            keystoreJSON: keystoreJSON,
            password: password,
            tcxNetwork: tokenCoreNetwork
        )
        let privateKeyHex = try EthereumMnemonicDerivation.privateKeyHex(mnemonic: phrase)
        let derivedAddress = try ExternalPrivateKeyService.ethereumAddress(fromPrivateKeyHex: privateKeyHex)
        guard derivedAddress.lowercased() == tcxAddress.lowercased() else {
            throw WalletError.signingFailedWithDetail(
                "本機推導 \(derivedAddress) 與 Keystore \(tcxAddress) 不一致"
            )
        }
        let address = tcxAddress
        if let preferred = preferredAddress?.trimmingCharacters(in: .whitespacesAndNewlines),
           preferred.hasPrefix("0x"),
           preferred.lowercased() != tcxAddress.lowercased() {
            throw WalletError.signingFailedWithDetail(
                "畫面地址 \(preferred) 與 Keystore 簽名地址 \(tcxAddress) 不一致，請重新匯入助記詞"
            )
        }
        let balanceWei = try await ChainRPCClient.fetchNativeBalanceWeiDecimal(address: address)
        guard balanceWei >= minCostWei else {
            let need = EVMWeiFormatter.weiToEther(minCostWei)
            let have = EVMWeiFormatter.weiToEther(balanceWei)
            throw WalletError.signingFailedWithDetail(
                "地址 \(address) Sepolia 餘額 \(have) ETH，不足以支付約 \(need) ETH（含質押金額與 Gas）"
            )
        }
        let nonce = try await ChainRPCClient.fetchTransactionCount(address: address)
        let signed = try ExternalPrivateKeyService.signEthereumLegacyTransaction(
            privateKeyHex: privateKeyHex,
            to: to,
            valueWei: valueWei,
            data: data,
            nonce: nonce,
            gasLimit: gasLimit,
            gasPrice: gasPrice,
            chainId: chainId
        )
        let recovered = try EthereumLegacyTransactionRecovery.recoverSender(
            fromRawTransaction: signed.rawTransaction,
            expectedChainId: chainId
        )
        guard recovered.lowercased() == address.lowercased() else {
            throw WalletError.signingFailedWithDetail(
                "本機簽名地址 \(recovered) 與預期 \(address) 不一致"
            )
        }
        return (signed, SigningContext(address: address, tcxNetwork: tokenCoreNetwork))
    }

    private static func attemptTcxSign(
        context: SigningContext,
        keystoreJSON: String,
        password: String,
        to: String,
        valueWei: UInt64,
        data: String,
        nonce: UInt64,
        gasLimit: UInt64,
        gasPrice: UInt64,
        chainId: Int
    ) async throws -> (signed: SignedEthereumTransaction, context: SigningContext) {
        let signed = try await signEthereumLegacyTransaction(
            keystoreJSON: keystoreJSON,
            password: password,
            to: to,
            valueWei: valueWei,
            data: data,
            nonce: nonce,
            gasLimit: gasLimit,
            gasPrice: gasPrice,
            chainId: chainId,
            tcxNetwork: context.tcxNetwork
        )
        return (signed, context)
    }

    /// 私鑰 keystore 無法走 tcx `derive_accounts`；以 Keychain 密碼摘要驗證
    private static func verifyExternalPrivateKeyPassword(
        keystoreJSON: String,
        password: String
    ) throws -> String {
        guard password.count >= 8 else { throw WalletError.invalidPassword }
        if WalletKeychainStore.verifyWalletPassword(password) {
            // ok
        } else if !WalletKeychainStore.hasWalletPasswordVerifier() {
            // 舊版私鑰匯入尚未寫入 verifier：接受首次正確輸入並寫入
            try WalletKeychainStore.saveWalletPasswordVerifier(password)
        } else {
            throw WalletError.invalidPassword
        }
        guard let hex = ExternalPrivateKeyService.privateKeyHex(from: keystoreJSON) else {
            throw WalletError.invalidPrivateKey
        }
        return try ExternalPrivateKeyService.ethereumAddress(fromPrivateKeyHex: hex)
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

    static func deriveEthereumAddress(
        keystoreJSON: String,
        password: String,
        tcxNetwork: String = tokenCoreNetwork
    ) async throws -> String {
        let derivationRequest: [String: Any] = [
            "keystoreJson": keystoreJSON,
            "key": password,
            "derivations": [
                [
                    "chain": "ETHEREUM",
                    "derivationPath": ChainConfig.active.derivationPath,
                    "chainId": chainId,
                    "network": tcxNetwork,
                ],
            ],
        ]
        let raw = try await TokenCoreBridge.shared.call(
            "deriveAccounts",
            payload: ["derivationRequest": derivationRequest]
        )
        return try parseDerivedAddress(from: raw)
    }

    struct SignedEthereumTransaction: Sendable {
        let rawTransaction: String
        let txHash: String?
    }

    /// 簽署 Sepolia / EVM Legacy 交易（tcx-wasm `sign_tx`）
    static func signEthereumLegacyTransaction(
        keystoreJSON: String,
        password: String,
        to: String,
        valueWei: UInt64,
        data: String = "0x",
        nonce: UInt64,
        gasLimit: UInt64,
        gasPrice: UInt64,
        chainId: Int = ChainConfig.active.id,
        tcxNetwork: String = tokenCoreNetwork
    ) async throws -> SignedEthereumTransaction {
        if ExternalPrivateKeyService.isExternalPrivateKeyKeystore(keystoreJSON),
           let privateKeyHex = ExternalPrivateKeyService.privateKeyHex(from: keystoreJSON) {
            return try ExternalPrivateKeyService.signEthereumLegacyTransaction(
                privateKeyHex: privateKeyHex,
                to: to,
                valueWei: valueWei,
                data: data,
                nonce: nonce,
                gasLimit: gasLimit,
                gasPrice: gasPrice,
                chainId: chainId
            )
        }
        var payload: [String: Any] = [
            "keystoreJson": keystoreJSON,
            "key": password,
            "derivationPath": ChainConfig.active.derivationPath,
            "network": tcxNetwork,
            "input": [
                "nonce": String(nonce),
                "gasPrice": String(gasPrice),
                "gasLimit": String(gasLimit),
                "to": to,
                // tcx sign_tx：value 為 wei 十進位字串（實測 "0.01" 會簽名失敗）
                "value": EVMWeiFormatter.decimalString(valueWei),
                "chainId": String(chainId),
                "data": data,
            ],
        ]
        let raw = try await TokenCoreBridge.shared.call("signTx", payload: payload)
        return try parseSignedTransaction(from: raw)
    }

    private static func parseSignedTransaction(from raw: String) throws -> SignedEthereumTransaction {
        guard let data = raw.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            if raw.hasPrefix("0x"), raw.count > 66 {
                return SignedEthereumTransaction(rawTransaction: raw, txHash: nil)
            }
            throw TokenCoreError.invalidResponse
        }
        let signature = (json["signature"] as? String) ?? (json["rawTransaction"] as? String)
        let txHash = json["txHash"] as? String
        guard var raw = signature?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            throw TokenCoreError.invalidResponse
        }
        if !raw.hasPrefix("0x") {
            raw = "0x" + raw
        }
        let canonical = try EthereumLegacyTransactionRecovery.canonicalizeRawTransaction(raw)
        return SignedEthereumTransaction(rawTransaction: canonical, txHash: txHash)
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
