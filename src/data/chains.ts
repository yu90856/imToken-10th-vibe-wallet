export type ChainCategory = "layer1" | "layer2" | "evm";

export interface Chain {
  id: string;
  name: string;
  symbol: string;
  color: string;
  logoUrl: string;
  categories: ChainCategory[];
  popular: boolean;
  evm: boolean;
}

import { chainLogoUrl } from "../lib/chainLogo";

type ChainDef = Omit<Chain, "logoUrl">;

const RAW_CHAINS: ChainDef[] = [
  {
    id: "ethereum",
    name: "Ethereum",
    symbol: "ETH",
    color: "#627EEA",
    categories: ["layer1", "evm"],
    popular: true,
    evm: true,
  },
  {
    id: "bnb",
    name: "BNB Chain",
    symbol: "BNB",
    color: "#F3BA2F",
    categories: ["layer1", "evm"],
    popular: true,
    evm: true,
  },
  {
    id: "polygon",
    name: "Polygon",
    symbol: "POL",
    color: "#8247E5",
    categories: ["layer2", "evm"],
    popular: true,
    evm: true,
  },
  {
    id: "arbitrum",
    name: "Arbitrum",
    symbol: "ETH",
    color: "#28A0F0",
    categories: ["layer2", "evm"],
    popular: true,
    evm: true,
  },
  {
    id: "solana",
    name: "Solana",
    symbol: "SOL",
    color: "#9945FF",
    categories: ["layer1"],
    popular: true,
    evm: false,
  },
  {
    id: "bitcoin",
    name: "Bitcoin",
    symbol: "BTC",
    color: "#F7931A",
    categories: ["layer1"],
    popular: false,
    evm: false,
  },
  {
    id: "avalanche",
    name: "Avalanche",
    symbol: "AVAX",
    color: "#E84142",
    categories: ["layer1", "evm"],
    popular: false,
    evm: true,
  },
  {
    id: "optimism",
    name: "Optimism",
    symbol: "ETH",
    color: "#FF0420",
    categories: ["layer2", "evm"],
    popular: false,
    evm: true,
  },
  {
    id: "base",
    name: "Base",
    symbol: "ETH",
    color: "#0052FF",
    categories: ["layer2", "evm"],
    popular: false,
    evm: true,
  },
  {
    id: "zksync",
    name: "zkSync Era",
    symbol: "ETH",
    color: "#8C8DFC",
    categories: ["layer2", "evm"],
    popular: false,
    evm: true,
  },
  {
    id: "linea",
    name: "Linea",
    symbol: "ETH",
    color: "#61DFFF",
    categories: ["layer2", "evm"],
    popular: false,
    evm: true,
  },
  {
    id: "scroll",
    name: "Scroll",
    symbol: "ETH",
    color: "#FFEEDA",
    categories: ["layer2", "evm"],
    popular: false,
    evm: true,
  },
  {
    id: "fantom",
    name: "Fantom",
    symbol: "FTM",
    color: "#1969FF",
    categories: ["layer1", "evm"],
    popular: false,
    evm: true,
  },
  {
    id: "cronos",
    name: "Cronos",
    symbol: "CRO",
    color: "#002D74",
    categories: ["evm"],
    popular: false,
    evm: true,
  },
  {
    id: "gnosis",
    name: "Gnosis",
    symbol: "xDAI",
    color: "#04795B",
    categories: ["evm"],
    popular: false,
    evm: true,
  },
];

export const CHAINS: Chain[] = RAW_CHAINS.map((c) => ({
  ...c,
  logoUrl: chainLogoUrl(c.id),
}));

export const POPULAR_CHAINS = CHAINS.filter((c) => c.popular);
export const DEFAULT_CHAIN_ID = "ethereum";

export const LAYER1_CHAINS = CHAINS.filter((c) => c.categories.includes("layer1"));
export const LAYER2_CHAINS = CHAINS.filter((c) => c.categories.includes("layer2"));
export const EVM_CHAINS = CHAINS.filter((c) => c.categories.includes("evm"));

export function getChain(id: string): Chain | undefined {
  return CHAINS.find((c) => c.id === id);
}
