import Foundation

/// 黑客松預設：Ethereum Sepolia 測試網（`usesTestnet = true`）
enum ChainConfig {
    static let usesTestnet = true

    static var active: EVMChain {
        usesTestnet ? sepolia : ethereumMainnet
    }

    static let ethereumMainnet = EVMChain(
        id: 1,
        name: "Ethereum",
        shortName: "Ethereum",
        symbol: "ETH",
        tokenLogoId: "eth",
        rpcURL: "https://eth.llamarpc.com",
        explorerURL: "https://etherscan.io",
        derivationPath: "m/44'/60'/0'/0/0",
        isTestnet: false,
        coingeckoId: "ethereum"
    )

    static let sepolia = EVMChain(
        id: 11155111,
        name: "Ethereum Sepolia",
        shortName: "Sepolia",
        symbol: "ETH",
        tokenLogoId: "eth",
        rpcURL: "https://ethereum-sepolia-rpc.publicnode.com",
        explorerURL: "https://sepolia.etherscan.io",
        derivationPath: "m/44'/60'/0'/0/0",
        isTestnet: true,
        coingeckoId: "ethereum"
    )

    static var tokenCoreNetwork: String {
        active.isTestnet ? "TESTNET" : "MAINNET"
    }

    /// 不需主網 ETH 的 Sepolia 水龍頭（Google Cloud）
    static let testnetFaucetURL = URL(string: "https://cloud.google.com/application/web3/faucet/ethereum/sepolia")!

    static let testnetFaucetAlternates: [URL] = [
        URL(string: "https://faucets.chain.link/sepolia")!,
        URL(string: "https://www.alchemy.com/faucets/ethereum-sepolia")!,
    ]
}

extension EVMChain {
    var chainIdHex: String {
        String(format: "0x%x", id)
    }
}

struct EVMChain: Equatable {
    let id: Int
    let name: String
    let shortName: String
    let symbol: String
    let tokenLogoId: String
    let rpcURL: String
    let explorerURL: String
    let derivationPath: String
    let isTestnet: Bool
    let coingeckoId: String
}
