const SLUG: Record<string, string> = {
  ethereum: "ethereum",
  bnb: "smartchain",
  polygon: "polygon",
  arbitrum: "arbitrum",
  solana: "solana",
  bitcoin: "bitcoin",
  avalanche: "avalanchec",
  optimism: "optimism",
  base: "base",
  zksync: "zksync",
  linea: "linea",
  scroll: "scroll",
  fantom: "fantom",
  cronos: "cronos",
  gnosis: "xdai",
};

export function chainLogoUrl(chainId: string): string {
  const slug = SLUG[chainId] ?? chainId;
  return `https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/${slug}/info/logo.png`;
}

export function tokenLogoUrl(symbol: string): string {
  return `https://assets.coincap.io/assets/icons/${symbol.toLowerCase()}@2x.png`;
}
