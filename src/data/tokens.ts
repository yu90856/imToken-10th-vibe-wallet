export type TokenCategory = "mainstream" | "onchain";
export type SortKey = "name" | "volume" | "change";

export interface TokenMarket {
  id: string;
  symbol: string;
  name: string;
  priceUsdt: number;
  change24h: number;
  volume24h: number;
  category: TokenCategory;
  address?: string;
  chainLabel?: string;
}

export const MARKET_TOKENS: TokenMarket[] = [
  {
    id: "btc",
    symbol: "BTC",
    name: "Bitcoin",
    priceUsdt: 97842.5,
    change24h: 2.34,
    volume24h: 42_800_000_000,
    category: "mainstream",
  },
  {
    id: "eth",
    symbol: "ETH",
    name: "Ethereum",
    priceUsdt: 3642.18,
    change24h: -1.12,
    volume24h: 18_200_000_000,
    category: "mainstream",
    address: "0x0000000000000000000000000000000000000000",
  },
  {
    id: "bnb",
    symbol: "BNB",
    name: "BNB",
    priceUsdt: 628.44,
    change24h: 0.87,
    volume24h: 2_100_000_000,
    category: "mainstream",
  },
  {
    id: "sol",
    symbol: "SOL",
    name: "Solana",
    priceUsdt: 178.92,
    change24h: 4.56,
    volume24h: 3_800_000_000,
    category: "mainstream",
  },
  {
    id: "xrp",
    symbol: "XRP",
    name: "XRP",
    priceUsdt: 2.41,
    change24h: -0.45,
    volume24h: 1_900_000_000,
    category: "mainstream",
  },
  {
    id: "ada",
    symbol: "ADA",
    name: "Cardano",
    priceUsdt: 0.78,
    change24h: 1.23,
    volume24h: 520_000_000,
    category: "mainstream",
  },
  {
    id: "doge",
    symbol: "DOGE",
    name: "Dogecoin",
    priceUsdt: 0.21,
    change24h: 3.88,
    volume24h: 1_200_000_000,
    category: "mainstream",
  },
  {
    id: "link",
    symbol: "LINK",
    name: "Chainlink",
    priceUsdt: 18.64,
    change24h: -2.1,
    volume24h: 680_000_000,
    category: "mainstream",
  },
  {
    id: "pepe",
    symbol: "PEPE",
    name: "Pepe",
    priceUsdt: 0.0000124,
    change24h: 12.4,
    volume24h: 890_000_000,
    category: "onchain",
    chainLabel: "Ethereum",
    address: "0x6982508145454ce325ddbe47a25d4ec3d2311933",
  },
  {
    id: "shib",
    symbol: "SHIB",
    name: "Shiba Inu",
    priceUsdt: 0.0000248,
    change24h: -5.2,
    volume24h: 420_000_000,
    category: "onchain",
    chainLabel: "Ethereum",
    address: "0x95ad61b0a150d79219dcf64e1e6cc01f0b64c4ce",
  },
  {
    id: "bonk",
    symbol: "BONK",
    name: "Bonk",
    priceUsdt: 0.0000286,
    change24h: 8.9,
    volume24h: 310_000_000,
    category: "onchain",
    chainLabel: "Solana",
    address: "DezXAZ8z7PnrnRJjz3wXBoRgixCa6xjnB7YaB1pPB263",
  },
  {
    id: "wif",
    symbol: "WIF",
    name: "dogwifhat",
    priceUsdt: 1.84,
    change24h: -3.6,
    volume24h: 280_000_000,
    category: "onchain",
    chainLabel: "Solana",
  },
  {
    id: "floki",
    symbol: "FLOKI",
    name: "FLOKI",
    priceUsdt: 0.000182,
    change24h: 6.1,
    volume24h: 195_000_000,
    category: "onchain",
    chainLabel: "BNB Chain",
  },
  {
    id: "brett",
    symbol: "BRETT",
    name: "Brett",
    priceUsdt: 0.142,
    change24h: 15.2,
    volume24h: 88_000_000,
    category: "onchain",
    chainLabel: "Base",
  },
];

export interface Holding {
  tokenId: string;
  amount: number;
}

export const DEMO_HOLDINGS: Holding[] = [
  { tokenId: "eth", amount: 1.24 },
  { tokenId: "usdt", amount: 3200 },
  { tokenId: "bnb", amount: 4.5 },
  { tokenId: "pepe", amount: 125_000_000 },
];

export const USDT_TOKEN: TokenMarket = {
  id: "usdt",
  symbol: "USDT",
  name: "Tether",
  priceUsdt: 1,
  change24h: 0.01,
  volume24h: 55_000_000_000,
  category: "mainstream",
};

export function getToken(id: string): TokenMarket | undefined {
  if (id === "usdt") return USDT_TOKEN;
  return MARKET_TOKENS.find((t) => t.id === id);
}

export function sortTokens(list: TokenMarket[], sort: SortKey): TokenMarket[] {
  const copy = [...list];
  switch (sort) {
    case "name":
      return copy.sort((a, b) => a.name.localeCompare(b.name));
    case "volume":
      return copy.sort((a, b) => b.volume24h - a.volume24h);
    case "change":
      return copy.sort((a, b) => b.change24h - a.change24h);
  }
}

export function formatPrice(n: number): string {
  if (n >= 1000) return n.toLocaleString("en-US", { maximumFractionDigits: 2 });
  if (n >= 1) return n.toFixed(2);
  if (n >= 0.0001) return n.toFixed(6);
  return n.toExponential(2);
}

export function formatVolume(n: number): string {
  if (n >= 1e9) return `$${(n / 1e9).toFixed(2)}B`;
  if (n >= 1e6) return `$${(n / 1e6).toFixed(2)}M`;
  return `$${n.toLocaleString()}`;
}

export function formatChange(pct: number): string {
  const sign = pct >= 0 ? "+" : "";
  return `${sign}${pct.toFixed(2)}%`;
}
