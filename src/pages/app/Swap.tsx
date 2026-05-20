import { useState } from "react";
import { MARKET_TOKENS, formatPrice } from "../../data/tokens";

const PROVIDERS = [
  { id: "1inch", name: "1inch", fee: "0.3%" },
  { id: "uniswap", name: "Uniswap", fee: "0.25%" },
  { id: "pancake", name: "PancakeSwap", fee: "0.25%" },
];

export function SwapPage() {
  const [fromId, setFromId] = useState("eth");
  const [toId, setToId] = useState("usdt");
  const [amount, setAmount] = useState("1");
  const [provider, setProvider] = useState("1inch");
  const [antiMev, setAntiMev] = useState(true);

  const from = MARKET_TOKENS.find((t) => t.id === fromId) ?? MARKET_TOKENS[1];
  const to =
    fromId === "usdt"
      ? MARKET_TOKENS[0]
      : MARKET_TOKENS.find((t) => t.id === toId) ?? MARKET_TOKENS[0];

  const amt = parseFloat(amount) || 0;
  const rate = from.priceUsdt / (to.priceUsdt || 1);
  const estimated = amt * rate * 0.997;
  const minReceived = estimated * 0.995;
  const gasUsd = antiMev ? 4.2 : 2.8;

  return (
    <div className="tab-page tab-page--scroll">
      <header className="page-header" style={{ marginBottom: 16 }}>
        <h1>SWAP</h1>
        <p>鏈上資產兌換，選擇流動性來源與防夾保護。</p>
      </header>

      <div className="swap-card card">
        <label className="field">
          <span>支付</span>
          <div className="swap-row">
            <input
              type="number"
              min="0"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
            />
            <select value={fromId} onChange={(e) => setFromId(e.target.value)}>
              {MARKET_TOKENS.map((t) => (
                <option key={t.id} value={t.id}>
                  {t.symbol}
                </option>
              ))}
              <option value="usdt">USDT</option>
            </select>
          </div>
        </label>

        <button type="button" className="swap-flip" aria-label="交換方向">
          ↕
        </button>

        <label className="field">
          <span>獲得（預估）</span>
          <div className="swap-row swap-row--readonly">
            <span>{formatPrice(estimated)}</span>
            <select value={toId} onChange={(e) => setToId(e.target.value)}>
              {MARKET_TOKENS.map((t) => (
                <option key={t.id} value={t.id}>
                  {t.symbol}
                </option>
              ))}
            </select>
          </div>
        </label>
      </div>

      <div className="card" style={{ marginTop: 12 }}>
        <label className="field">
          <span>流動池供應商</span>
          <select
            className="swap-select-full"
            value={provider}
            onChange={(e) => setProvider(e.target.value)}
          >
            {PROVIDERS.map((p) => (
              <option key={p.id} value={p.id}>
                {p.name} · 手續費 {p.fee}
              </option>
            ))}
          </select>
        </label>

        <ul className="swap-meta">
          <li>
            <span>預估 Gas</span>
            <strong>~${gasUsd.toFixed(2)}</strong>
          </li>
          <li>
            <span>最少到帳</span>
            <strong>
              {formatPrice(minReceived)} {to.symbol}
            </strong>
          </li>
          <li className="swap-meta__mev">
            <span>防夾（MEV 保護）</span>
            <button
              type="button"
              className={`toggle-pill${antiMev ? " toggle-pill--on" : ""}`}
              onClick={() => setAntiMev(!antiMev)}
            >
              {antiMev ? "已開啟" : "關閉"}
            </button>
          </li>
        </ul>
      </div>

      <button type="button" className="btn btn--primary" style={{ marginTop: 20 }}>
        確認兌換
      </button>
    </div>
  );
}
