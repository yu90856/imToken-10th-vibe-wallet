import { TokenIcon } from "../../components/TokenIcon";
import {
  DEMO_HOLDINGS,
  formatChange,
  formatPrice,
  getToken,
} from "../../data/tokens";
import { holdingValueUsdt, computePortfolio } from "../../lib/portfolio";
import { useAppStore } from "../../store/app";

export function AssetsPage() {
  const hidden = useAppStore((s) => s.balanceHidden);
  const toggle = useAppStore((s) => s.toggleBalanceHidden);
  const { totalUsdt, change24hPct } = computePortfolio();
  const up = change24hPct >= 0;

  return (
    <div className="tab-page tab-page--scroll">
      <section className="hero-balance card">
        <div className="hero-balance__head">
          <span>總持倉 (USDT)</span>
          <button type="button" className="eye-btn" onClick={toggle} aria-label="切換隱藏">
            {hidden ? "🙈" : "👁"}
          </button>
        </div>
        <p className="hero-balance__amount">
          {hidden ? "••••••" : `$${formatPrice(totalUsdt)}`}
        </p>
        <p
          className={`hero-balance__chg${up ? " token-row__chg--up" : " token-row__chg--down"}`}
        >
          24h {up ? "+" : ""}
          {change24hPct.toFixed(2)}%
        </p>
      </section>

      <h2 className="section-title">持倉明細</h2>
      <div className="token-list">
        {DEMO_HOLDINGS.map((h) => {
          const token = getToken(h.tokenId);
          if (!token) return null;
          const value = holdingValueUsdt(h.tokenId, h.amount);
          const tokenUp = token.change24h >= 0;
          return (
            <div key={h.tokenId} className="holding-row card">
              <TokenIcon symbol={token.symbol} />
              <div className="holding-row__main">
                <div className="token-row__top">
                  <span className="token-row__name">{token.name}</span>
                  <span className="token-row__price">
                    {hidden ? "••••" : `$${formatPrice(value)}`}
                  </span>
                </div>
                <div className="token-row__bottom">
                  <span className="token-row__vol">
                    {hidden ? "••••" : `${h.amount} ${token.symbol}`}
                  </span>
                  <span
                    className={`token-row__chg${
                      tokenUp ? " token-row__chg--up" : " token-row__chg--down"
                    }`}
                  >
                    {formatChange(token.change24h)}
                  </span>
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
