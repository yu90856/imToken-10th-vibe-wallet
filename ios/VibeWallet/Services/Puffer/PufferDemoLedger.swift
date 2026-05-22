import Foundation

/// Sepolia 演示帳本：在未部署合約時記錄質押與 pufETH 餘額（僅本機，不上傳）
enum PufferDemoLedger {
    private static func ethKey(for address: String) -> String {
        "puffer.demo.ethStaked.\(address.lowercased())"
    }

    private static func pufKey(for address: String) -> String {
        "puffer.demo.pufBalance.\(address.lowercased())"
    }

    static func ethStaked(address: String) -> Decimal {
        let key = ethKey(for: address)
        guard let value = UserDefaults.standard.object(forKey: key) as? Double else { return 0 }
        return Decimal(value)
    }

    static func pufETHBalance(address: String) -> Decimal {
        let key = pufKey(for: address)
        guard let value = UserDefaults.standard.object(forKey: key) as? Double else { return 0 }
        return Decimal(value)
    }

    static func recordStake(address: String, ethAmount: Decimal, pufMinted: Decimal) {
        let prevEth = ethStaked(address: address)
        let prevPuf = pufETHBalance(address: address)
        UserDefaults.standard.set(NSDecimalNumber(decimal: prevEth + ethAmount).doubleValue, forKey: ethKey(for: address))
        UserDefaults.standard.set(NSDecimalNumber(decimal: prevPuf + pufMinted).doubleValue, forKey: pufKey(for: address))
    }

    static func reset(address: String) {
        UserDefaults.standard.removeObject(forKey: ethKey(for: address))
        UserDefaults.standard.removeObject(forKey: pufKey(for: address))
    }
}
