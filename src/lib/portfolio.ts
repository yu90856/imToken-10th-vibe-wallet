import { DEMO_HOLDINGS, getToken, USDT_TOKEN } from "../data/tokens";

export function computePortfolio() {
  let totalUsdt = 0;
  let weightedChange = 0;

  for (const h of DEMO_HOLDINGS) {
    const token = getToken(h.tokenId);
    if (!token) continue;
    const value = h.amount * token.priceUsdt;
    totalUsdt += value;
    weightedChange += value * token.change24h;
  }

  const change24hPct = totalUsdt > 0 ? weightedChange / totalUsdt : 0;
  return { totalUsdt, change24hPct };
}

export function holdingValueUsdt(tokenId: string, amount: number): number {
  const token = getToken(tokenId) ?? USDT_TOKEN;
  return amount * token.priceUsdt;
}
