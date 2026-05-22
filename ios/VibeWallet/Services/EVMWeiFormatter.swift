import Foundation

enum EVMWeiFormatter {
    private static let weiPerEther: Decimal = 1_000_000_000_000_000_000

    static func etherToWei(_ ether: Decimal) -> UInt64 {
        tokenAmountToWei(ether, decimals: 18)
    }

    static func tokenAmountToWei(_ amount: Decimal, decimals: Int = 18) -> UInt64 {
        var divisor = Decimal(1)
        for _ in 0..<decimals { divisor *= 10 }
        let wei = amount * divisor
        return NSDecimalNumber(decimal: wei).uint64Value
    }

    static func weiToEther(_ wei: UInt64) -> Decimal {
        Decimal(wei) / weiPerEther
    }

    static func weiToEther(_ wei: Decimal) -> Decimal {
        wei / weiPerEther
    }

    /// 大額 wei（避免 `UInt64` 解析 `eth_getBalance` 溢位）
    static func weiHexToDecimal(_ hex: String) -> Decimal {
        let cleaned = hex.hasPrefix("0x") || hex.hasPrefix("0X")
            ? String(hex.dropFirst(2))
            : hex
        guard !cleaned.isEmpty else { return 0 }
        var value = Decimal(0)
        for char in cleaned.lowercased() {
            guard let digit = Int(String(char), radix: 16) else { continue }
            value = value * 16 + Decimal(digit)
        }
        return value
    }

    static func transactionCostWei(
        valueWei: UInt64,
        gasLimit: UInt64,
        gasPrice: UInt64
    ) -> Decimal {
        Decimal(valueWei) + Decimal(gasLimit) * Decimal(gasPrice)
    }

    static func decimalString(_ wei: UInt64) -> String {
        String(wei)
    }

    static func hexQuantity(_ value: UInt64) -> String {
        if value == 0 { return "0x0" }
        return "0x" + String(value, radix: 16)
    }

    /// ABI 編碼 uint256（32 bytes）供合約 calldata 使用
    static func uint256HexData(_ value: UInt64) -> String {
        String(format: "%064x", value)
    }

    /// 將 wei（`Decimal`）編碼為 ABI uint256（不用 `UInt64`，避免大數截斷）
    static func uint256HexData(_ wei: Decimal) -> String {
        weiHex64(fromWei: wei)
    }

    /// `eth_call` / `balanceOf` 回傳之 32-byte hex（可含 `0x`）→ 64 字元小寫 hex
    static func normalizedUInt256Hex(_ rpcHex: String) -> String {
        let cleaned = rpcHex.hasPrefix("0x") || rpcHex.hasPrefix("0X")
            ? String(rpcHex.dropFirst(2))
            : rpcHex
        let lower = cleaned.lowercased()
        let hexChars = CharacterSet(charactersIn: "0123456789abcdef")
        guard lower.count <= 64,
              lower.unicodeScalars.allSatisfy({ hexChars.contains($0) }) else {
            return String(repeating: "0", count: 64)
        }
        return String(repeating: "0", count: max(0, 64 - lower.count)) + lower
    }

    private static func weiHex64(fromWei wei: Decimal) -> String {
        guard wei > 0 else { return String(repeating: "0", count: 64) }
        var value = NSDecimalNumber(decimal: wei)
        guard value.compare(NSDecimalNumber.zero) == .orderedDescending else {
            return String(repeating: "0", count: 64)
        }
        let sixteen = NSDecimalNumber(value: 16)
        let handler = NSDecimalNumberHandler(
            roundingMode: .down,
            scale: 0,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        )
        var digits: [String] = []
        while value.compare(NSDecimalNumber.zero) == .orderedDescending {
            let chunk = value.dividing(by: sixteen, withBehavior: handler)
            let multiplied = chunk.multiplying(by: sixteen)
            let remainder = value.subtracting(multiplied)
            let digit = remainder.uint16Value
            digits.append(String(digit, radix: 16))
            value = chunk
        }
        let hex = digits.reversed().joined()
        return String(repeating: "0", count: max(0, 64 - hex.count)) + hex
    }
}
