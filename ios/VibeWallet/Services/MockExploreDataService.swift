import Foundation

struct MockExploreDataService {
    func categories() -> [ExploreCategory] {
        if ChainConfig.usesTestnet {
            return sepoliaCategories()
        }
        return mainnetCategories()
    }

    private func sepoliaCategories() -> [ExploreCategory] {
        [
            ExploreCategory(
                id: "sepolia-swap",
                title: "DeFi · Sepolia",
                items: [
                    ExploreDapp(
                        id: "uniswap",
                        name: "Uniswap",
                        description: "切換錢包至 Sepolia 後可兌換測試代幣",
                        url: "https://app.uniswap.org"
                    ),
                    ExploreDapp(
                        id: "1inch",
                        name: "1inch",
                        description: "聚合兌換（需錢包在 Sepolia）",
                        url: "https://app.1inch.io"
                    ),
                ]
            ),
            ExploreCategory(
                id: "sepolia-nft",
                title: "NFT · thirdweb",
                items: [
                    ExploreDapp(
                        id: "thirdweb",
                        name: "thirdweb Dashboard",
                        description: "部署合約、鑄造測試 NFT",
                        url: "https://thirdweb.com/dashboard"
                    ),
                ]
            ),
            ExploreCategory(
                id: "eth-tools",
                title: "Sepolia 工具",
                items: [
                    ExploreDapp(
                        id: "etherscan",
                        name: "Etherscan Sepolia",
                        description: "區塊瀏覽器 · 查交易",
                        url: "https://sepolia.etherscan.io"
                    ),
                    ExploreDapp(
                        id: "faucet-google",
                        name: "Sepolia Faucet（Google）",
                        description: "領取測試 ETH",
                        url: ChainConfig.testnetFaucetURL.absoluteString
                    ),
                    ExploreDapp(
                        id: "faucet-chainlink",
                        name: "Chainlink Faucet",
                        description: "Sepolia ETH + 測試 LINK",
                        url: "https://faucets.chain.link/sepolia"
                    ),
                    ExploreDapp(
                        id: "faucet-alchemy",
                        name: "Alchemy Faucet",
                        description: "每日測試 ETH",
                        url: "https://www.alchemy.com/faucets/ethereum-sepolia"
                    ),
                    ExploreDapp(
                        id: "faucet-pow",
                        name: "PoW Faucet",
                        description: "挖礦領 Sepolia ETH",
                        url: "https://sepolia-faucet.pk910.de"
                    ),
                ]
            ),
        ]
    }

    private func mainnetCategories() -> [ExploreCategory] {
        [
            ExploreCategory(
                id: "eth-defi",
                title: "Ethereum DeFi",
                items: [
                    ExploreDapp(
                        id: "uniswap",
                        name: "Uniswap",
                        description: "去中心化交易所",
                        url: "https://app.uniswap.org"
                    ),
                    ExploreDapp(
                        id: "aave",
                        name: "Aave",
                        description: "借貸協議",
                        url: "https://app.aave.com"
                    ),
                    ExploreDapp(
                        id: "opensea",
                        name: "OpenSea",
                        description: "NFT 市場",
                        url: "https://opensea.io"
                    ),
                ]
            ),
            ExploreCategory(
                id: "eth-tools",
                title: "Ethereum 工具",
                items: [
                    ExploreDapp(
                        id: "etherscan",
                        name: "Etherscan",
                        description: "區塊瀏覽器",
                        url: "https://etherscan.io"
                    ),
                    ExploreDapp(
                        id: "debank",
                        name: "DeBank",
                        description: "資產總覽",
                        url: "https://debank.com/?chain=eth"
                    ),
                ]
            ),
        ]
    }
}
