import { Link } from "react-router-dom";
import { getChain } from "../../data/chains";
import { formatPrice } from "../../data/tokens";
import { loadVault } from "../../lib/vault";
import { useAppStore } from "../../store/app";
import { computePortfolio } from "../../lib/portfolio";

export function DashboardHomePage() {
  const vault = loadVault()!;
  const hidden = useAppStore((s) => s.balanceHidden);
  const toggle = useAppStore((s) => s.toggleBalanceHidden);
  const { totalUsdt, change24hPct } = computePortfolio();
  const chain = getChain(vault.chainIds[0] ?? "ethereum");

  return (
    <div className="tab-page">
      <section className="hero-balance card">
        <div className="hero-balance__head">
          <span>總資產 (USDT)</span>
          <button type="button" className="eye-btn" onClick={toggle} aria-label="切換顯示">
            {hidden ? "🙈" : "👁"}
          </button>
        </div>
        <p className="hero-balance__amount">
          {hidden ? "••••••" : `$${formatPrice(totalUsdt)}`}
        </p>
        <p
          className={`hero-balance__chg${
            change24hPct >= 0 ? " token-row__chg--up" : " token-row__chg--down"
          }`}
        >
          24h {change24hPct >= 0 ? "+" : ""}
          {change24hPct.toFixed(2)}%
        </p>
      </section>

      <section className="card" style={{ marginTop: 16 }}>
        <p className="field-hint">{chain?.name} 地址</p>
        <p className="ready-address" style={{ fontSize: "0.75rem" }}>
          {vault.evmAddress}
        </p>
      </section>

      <h2 className="section-title">快捷入口</h2>
      <div className="quick-grid">
        <Link to="/app/market" className="quick-card">
          <span>市場</span>
          <small>行情與關注</small>
        </Link>
        <Link to="/app/swap" className="quick-card">
          <span>SWAP</span>
          <small>鏈上兌換</small>
        </Link>
        <Link to="/app/explore" className="quick-card">
          <span>探索</span>
          <small>Dapp · DeFi 瀏覽</small>
        </Link>
        <Link to="/app/assets" className="quick-card quick-card--wide">
          <span>資產</span>
          <small>持倉明細</small>
        </Link>
        <Link to="/debug" className="quick-card quick-card--wide">
          <span>整合自檢</span>
          <small>Token Core / UI / 安全</small>
        </Link>
      </div>
    </div>
  );
}
