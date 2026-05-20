import { useEffect, useMemo, useState } from "react";
import { Link, useParams } from "react-router-dom";
import {
  CartesianGrid,
  Line,
  LineChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { TokenIcon } from "../../components/TokenIcon";
import {
  type ChartRange,
  fetchTokenChart,
  formatChartTime,
  type ChartPoint,
} from "../../lib/marketChart";
import {
  formatChange,
  formatPrice,
  formatVolume,
  getToken,
} from "../../data/tokens";

const RANGES: ChartRange[] = ["1H", "24H", "7D", "30D", "90D"];

export function TokenDetailPage() {
  const { tokenId } = useParams<{ tokenId: string }>();
  const token = tokenId ? getToken(tokenId) : undefined;
  const [range, setRange] = useState<ChartRange>("24H");
  const [points, setPoints] = useState<ChartPoint[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!tokenId) return;
    let cancelled = false;
    setLoading(true);
    fetchTokenChart(tokenId, range)
      .then((data) => {
        if (!cancelled) setPoints(data);
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [tokenId, range]);

  const chartData = useMemo(
    () =>
      points.map((p) => ({
        ...p,
        label: formatChartTime(p.time, range),
      })),
    [points, range]
  );

  const rangeChange = useMemo(() => {
    if (points.length < 2) return token?.change24h ?? 0;
    const first = points[0].price;
    const last = points[points.length - 1].price;
    return ((last - first) / first) * 100;
  }, [points, token]);

  if (!token) {
    return (
      <div className="tab-page">
        <p>找不到此代幣</p>
        <Link to="/app/market">返回市場</Link>
      </div>
    );
  }

  const up = rangeChange >= 0;

  return (
    <div className="tab-page tab-page--scroll token-detail">
      <Link to="/app/market" className="back-link">
        ← 市場
      </Link>

      <header className="token-detail__head">
        <TokenIcon symbol={token.symbol} size={48} />
        <div>
          <h1>{token.name}</h1>
          <p className="field-hint">{token.symbol} / USDT</p>
        </div>
        <div className="token-detail__price-block">
          <p className="token-detail__price">${formatPrice(token.priceUsdt)}</p>
          <p
            className={`token-row__chg${up ? " token-row__chg--up" : " token-row__chg--down"}`}
          >
            {formatChange(rangeChange)}（{range}）
          </p>
        </div>
      </header>

      <div className="range-tabs">
        {RANGES.map((r) => (
          <button
            key={r}
            type="button"
            className={`range-tabs__btn${range === r ? " range-tabs__btn--active" : ""}`}
            onClick={() => setRange(r)}
          >
            {r}
          </button>
        ))}
      </div>

      <div className="chart-card card">
        {loading ? (
          <p className="field-hint chart-placeholder">載入圖表中…</p>
        ) : chartData.length === 0 ? (
          <p className="field-hint chart-placeholder">暫無圖表資料</p>
        ) : (
          <ResponsiveContainer width="100%" height={220}>
            <LineChart data={chartData}>
              <CartesianGrid stroke="rgba(255,255,255,0.06)" strokeDasharray="3 3" />
              <XAxis
                dataKey="label"
                tick={{ fill: "#8b92a8", fontSize: 10 }}
                interval="preserveStartEnd"
                minTickGap={24}
              />
              <YAxis
                domain={["auto", "auto"]}
                tick={{ fill: "#8b92a8", fontSize: 10 }}
                width={56}
                tickFormatter={(v) =>
                  v >= 1000 ? `${(v / 1000).toFixed(1)}k` : String(v)
                }
              />
              <Tooltip
                contentStyle={{
                  background: "#181b26",
                  border: "1px solid rgba(255,255,255,0.1)",
                  borderRadius: 8,
                }}
                formatter={(value) => [
                  `$${formatPrice(Number(value ?? 0))}`,
                  "價格",
                ]}
              />
              <Line
                type="monotone"
                dataKey="price"
                stroke={up ? "#4ade80" : "#f87171"}
                strokeWidth={2}
                dot={false}
                activeDot={{ r: 4 }}
              />
            </LineChart>
          </ResponsiveContainer>
        )}
      </div>

      <div className="card token-detail__stats">
        <div>
          <span className="field-hint">24h 漲跌</span>
          <p className={token.change24h >= 0 ? "token-row__chg--up" : "token-row__chg--down"}>
            {formatChange(token.change24h)}
          </p>
        </div>
        <div>
          <span className="field-hint">24h 交易量</span>
          <p>{formatVolume(token.volume24h)}</p>
        </div>
      </div>
    </div>
  );
}
