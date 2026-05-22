import Foundation

/// Puffer 黑客松賽道 · Sepolia **Vibe 演示 Vault**（非官方 `PufferVault`；SDK v1.31 僅 Holesky 有 Vault/pufETH）
enum PufferDemoConfig {
    static let hackathonAPIBase = "https://api-v2.puffer.fi/imtoken-hackathon"

    /// 優先讀 `Secrets.plist` → `PUFFER_SEPOLIA_VAULT`；無 plist 時用此預設（Sepolia 已部署的演示 Vault）
    private static let bundledSepoliaVaultAddress = "0x8Bf55d61921D22AD5bacCE4fF759AE24Ee456604"

    static var sepoliaVaultAddress: String {
        let fromSecrets = SecretsReader.string(for: "PUFFER_SEPOLIA_VAULT") ?? ""
        let chosen = fromSecrets.isEmpty ? bundledSepoliaVaultAddress : fromSecrets
        return chosen.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static let depositSelector = "0xd0e30db0" // deposit()
    /// withdraw(uint256) — 需部署含 withdraw 的 VibePufferDemoVault
    static let withdrawSelector = "0x2e1a7d4d"

    static func encodeWithdrawCalldata(pufAmountWei: UInt64) -> String {
        encodeWithdrawCalldata(weiHex64: EVMWeiFormatter.uint256HexData(Decimal(pufAmountWei)))
    }

    static func encodeWithdrawCalldata(pufAmountWei: Decimal) -> String {
        encodeWithdrawCalldata(weiHex64: EVMWeiFormatter.uint256HexData(pufAmountWei))
    }

    /// 直接使用 RPC `balanceOf` 回傳之 uint256 hex，避免 Decimal / UInt64 精度損失
    static func encodeWithdrawCalldata(weiHex64: String) -> String {
        "0x\(withdrawSelector.dropFirst(2))\(EVMWeiFormatter.normalizedUInt256Hex(weiHex64))"
    }

    static let pufETHSymbol = "pufETH"
    static let pufETHDecimals = 18

    /// 預留 Gas（ETH）
    /// 預留 Gas（配合提高後的 broadcast gasPrice，避免餘額檢查過鬆）
    static let gasReserveEther: Decimal = 0.012

    static var hasOnChainVault: Bool {
        let addr = sepoliaVaultAddress
        return addr.hasPrefix("0x") && addr.count == 42
    }

    /// Puffer UniFi Vault 官方說明（靜態引導）
    static let unifiVaultInfoURL = "https://www.puffer.fi/"

    static var vaultSetupHint: String {
        """
        1. 用 Remix 部署 contracts/VibePufferDemoVault.sol 到 Sepolia
        2. 複製合約地址到 ios/VibeWallet/Config/Secrets.plist → PUFFER_SEPOLIA_VAULT
        3. 在 Sepolia 領取測試 ETH 後再質押
        詳見 ios/docs/PUFFER_SEPOLIA.md
        """
    }
}
