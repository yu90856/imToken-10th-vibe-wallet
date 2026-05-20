export interface DefiProtocol {
  id: string;
  name: string;
  description: string;
  url: string;
  types: string[];
}

export interface DefiChainGroup {
  chainId: string;
  chainName: string;
  protocols: DefiProtocol[];
}

export const DEFI_BY_CHAIN: DefiChainGroup[] = [
  {
    chainId: "ethereum",
    chainName: "Ethereum",
    protocols: [
      {
        id: "aave",
        name: "Aave",
        description: "主流借貸市場",
        url: "https://app.aave.com",
        types: ["借貸", "存款"],
      },
      {
        id: "lido",
        name: "Lido",
        description: "ETH 流動性質押",
        url: "https://lido.fi",
        types: ["質押"],
      },
      {
        id: "curve",
        name: "Curve",
        description: "穩定幣交易與流動性",
        url: "https://curve.fi",
        types: ["DEX", "收益"],
      },
    ],
  },
  {
    chainId: "bnb",
    chainName: "BNB Chain",
    protocols: [
      {
        id: "venus",
        name: "Venus",
        description: "借貸與鑄造穩定幣",
        url: "https://app.venus.io",
        types: ["借貸"],
      },
      {
        id: "alpaca",
        name: "Alpaca Finance",
        description: "槓桿收益農場",
        url: "https://alpaca.finance",
        types: ["收益"],
      },
    ],
  },
  {
    chainId: "solana",
    chainName: "Solana",
    protocols: [
      {
        id: "kamino",
        name: "Kamino",
        description: "借貸與自動化策略",
        url: "https://kamino.finance",
        types: ["借貸", "收益"],
      },
      {
        id: "drift",
        name: "Drift",
        description: "永續合約 DEX",
        url: "https://drift.trade",
        types: ["衍生品"],
      },
    ],
  },
  {
    chainId: "arbitrum",
    chainName: "Arbitrum",
    protocols: [
      {
        id: "gmx",
        name: "GMX",
        description: "永續合約與現貨",
        url: "https://app.gmx.io",
        types: ["衍生品"],
      },
      {
        id: "radiant",
        name: "Radiant",
        description: "跨鏈借貸",
        url: "https://app.radiant.capital",
        types: ["借貸"],
      },
    ],
  },
];
