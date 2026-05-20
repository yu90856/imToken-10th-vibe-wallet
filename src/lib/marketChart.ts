export type ChartRange = "1H" | "24H" | "7D" | "30D" | "90D";

export interface ChartPoint {
  time: number;
  price: number;
}

const COINGECKO_IDS: Record<string, string> = {
  btc: "bitcoin",
  eth: "ethereum",
  bnb: "binancecoin",
  sol: "solana",
  xrp: "ripple",
  ada: "cardano",
  doge: "dogecoin",
  link: "chainlink",
  pepe: "pepe",
  shib: "shiba-inu",
  bonk: "bonk",
  wif: "dogwifcoin",
  floki: "floki",
  brett: "based-brett",
  usdt: "tether",
};

export function getCoingeckoId(tokenId: string): string | undefined {
  return COINGECKO_IDS[tokenId];
}

function rangeToDays(range: ChartRange): number {
  switch (range) {
    case "1H":
    case "24H":
      return 1;
    case "7D":
      return 7;
    case "30D":
      return 30;
    case "90D":
      return 90;
  }
}

/** Fetch USDT-denominated price history from CoinGecko (free API). */
export async function fetchTokenChart(
  tokenId: string,
  range: ChartRange
): Promise<ChartPoint[]> {
  const cgId = getCoingeckoId(tokenId);
  if (!cgId) {
    return generateMockChart(tokenId, range);
  }

  const days = rangeToDays(range);
  const url = `https://api.coingecko.com/api/v3/coins/${cgId}/market_chart?vs_currency=usd&days=${days}`;

  const res = await fetch(url);
  if (!res.ok) {
    return generateMockChart(tokenId, range);
  }

  const data = (await res.json()) as { prices: [number, number][] };
  let points: ChartPoint[] = data.prices.map(([time, price]) => ({
    time,
    price,
  }));

  if (range === "1H" && points.length > 0) {
    const cutoff = Date.now() - 60 * 60 * 1000;
    points = points.filter((p) => p.time >= cutoff);
  }

  return points;
}

function generateMockChart(tokenId: string, range: ChartRange): ChartPoint[] {
  const seed = tokenId.split("").reduce((a, c) => a + c.charCodeAt(0), 0);
  const base = 100 + (seed % 500);
  const count =
    range === "1H" ? 60 : range === "24H" ? 96 : range === "7D" ? 168 : 120;
  const ms =
    range === "1H"
      ? 60_000
      : range === "24H"
        ? 15 * 60_000
        : range === "7D"
          ? 60 * 60_000
          : 24 * 60 * 60_000;
  const now = Date.now();
  const points: ChartPoint[] = [];
  let price = base;
  for (let i = count; i >= 0; i--) {
    price *= 1 + (Math.sin(seed + i) * 0.008);
    points.push({ time: now - i * ms, price });
  }
  return points;
}

export function formatChartTime(ts: number, range: ChartRange): string {
  const d = new Date(ts);
  if (range === "1H" || range === "24H") {
    return d.toLocaleTimeString("zh-TW", { hour: "2-digit", minute: "2-digit" });
  }
  return d.toLocaleDateString("zh-TW", { month: "short", day: "numeric" });
}
