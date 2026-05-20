export interface DappItem {
  id: string;
  name: string;
  description: string;
  url: string;
  tag?: string;
}

export interface ExploreCategory {
  id: string;
  title: string;
  items: DappItem[];
}

export const EXPLORE_CATEGORIES: ExploreCategory[] = [
  {
    id: "hot",
    title: "熱門 Dapp",
    items: [
      { id: "uniswap", name: "Uniswap", description: "DEX 交易", url: "https://app.uniswap.org" },
      { id: "opensea", name: "OpenSea", description: "NFT 市場", url: "https://opensea.io" },
      { id: "pancake", name: "PancakeSwap", description: "BNB 鏈 DEX", url: "https://pancakeswap.finance" },
    ],
  },
  {
    id: "prediction",
    title: "預測市場",
    items: [
      { id: "poly", name: "Polymarket", description: "事件預測", url: "https://polymarket.com" },
      { id: "azuro", name: "Azuro", description: "去中心化博彩", url: "https://azuro.org" },
    ],
  },
  {
    id: "bnb",
    title: "BNB 生態系 · DeFi",
    items: [
      { id: "venus", name: "Venus", description: "借貸協議", url: "https://app.venus.io" },
      { id: "biswap", name: "BiSwap", description: "DEX", url: "https://biswap.org" },
    ],
  },
  {
    id: "defi",
    title: "DeFi 協議",
    items: [
      { id: "aave", name: "Aave", description: "以太坊借貸", url: "https://app.aave.com" },
      { id: "lido", name: "Lido", description: "流動性質押", url: "https://lido.fi" },
      { id: "curve", name: "Curve", description: "穩定幣交易", url: "https://curve.fi" },
    ],
  },
  {
    id: "sol",
    title: "Sol 生態系",
    items: [
      { id: "jup", name: "Jupiter", description: "Solana 聚合交易", url: "https://jup.ag" },
      { id: "marinade", name: "Marinade", description: "流動性質押", url: "https://marinade.finance" },
    ],
  },
  {
    id: "tools",
    title: "工具",
    items: [
      { id: "debank", name: "DeBank", description: "資產看板", url: "https://debank.com" },
      { id: "etherscan", name: "Etherscan", description: "區塊瀏覽器", url: "https://etherscan.io" },
    ],
  },
];
