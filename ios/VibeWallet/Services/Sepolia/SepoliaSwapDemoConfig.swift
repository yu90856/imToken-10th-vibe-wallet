import Foundation

/// Sepolia 演示交換合約（ETH ↔ vUSDC）
enum SepoliaSwapDemoConfig {
    private static let bundledContractAddress = ""

    static var contractAddress: String {
        let fromSecrets = SecretsReader.string(for: "SEPOLIA_SWAP_DEMO") ?? ""
        let chosen = fromSecrets.isEmpty ? bundledContractAddress : fromSecrets
        return chosen.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static var hasOnChainSwap: Bool {
        let addr = contractAddress
        return addr.hasPrefix("0x") && addr.count == 42
    }

    static let swapETHForVUSDCPrefix = "0xc6b68a6c"
    static let swapVUSDCForETHPrefix = "0x5a54f769"

    static let vUSDCSymbol = "vUSDC"
    static let vUSDCMarketId = "vibe-vusdc"
    static let gasReserveEther: Decimal = 0.008
}
