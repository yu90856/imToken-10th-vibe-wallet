import Foundation

/// 鏈上 VibePufferDemoVault 匯率換算（與 Solidity 一致）
enum PufferVaultMath {
    private static let oneEtherWei: Decimal = 1_000_000_000_000_000_000

    /// 每 1 pufETH（18 decimals）可贖回的 ETH 數量
    static func ethPerPufEth(exchangeRateWei: Decimal) -> Decimal {
        guard exchangeRateWei > 0 else { return 1 }
        return oneEtherWei / exchangeRateWei
    }

    /// `withdraw` 預估贖回 ETH（人類可讀單位）
    static func ethOutForPufAmount(_ pufAmount: Decimal, exchangeRateWei: Decimal) -> Decimal {
        guard exchangeRateWei > 0 else { return pufAmount }
        return (pufAmount * oneEtherWei) / exchangeRateWei
    }
}
