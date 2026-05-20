import { useMemo } from "react";
import { Link } from "react-router-dom";
import { getChain } from "../data/chains";
import { Layout } from "../components/Layout";
import { loadVault } from "../lib/vault";

export function HomePage() {
  const vault = useMemo(() => loadVault(), []);

  if (!vault) {
    return (
      <Layout center>
        <p>尚未建立錢包</p>
        <Link to="/" className="btn btn--primary" style={{ marginTop: 16 }}>
          開始使用
        </Link>
      </Layout>
    );
  }

  const chains = vault.chainIds
    .map((id) => getChain(id))
    .filter(Boolean);

  return (
    <Layout>
      <header className="page-header">
        <h1>{vault.walletName}</h1>
        <p>您的 AI 個人錢包已就緒。以下為 EVM 主帳戶地址（示例）。</p>
      </header>

      <div className="card" style={{ marginBottom: 16 }}>
        <p className="field-hint" style={{ marginBottom: 8 }}>
          EVM 地址
        </p>
        <p
          style={{
            fontFamily: "var(--mono)",
            fontSize: "0.8125rem",
            wordBreak: "break-all",
            lineHeight: 1.5,
          }}
        >
          {vault.evmAddress}
        </p>
      </div>

      <div className="card">
        <p className="field-hint" style={{ marginBottom: 12 }}>
          已啟用鏈（{chains.length}）
        </p>
        <div className="chain-grid">
          {chains.map(
            (c) =>
              c && (
                <div
                  key={c.id}
                  className="chain-chip chain-chip--selected"
                  style={{ minWidth: "auto", cursor: "default" }}
                >
                  <div className="chain-icon" style={{ background: c.color }}>
                    {c.symbol.slice(0, 2)}
                  </div>
                  <span>{c.name}</span>
                </div>
              )
          )}
        </div>
      </div>

      {!vault.backupCompleted && (
        <div className="alert alert--warning" style={{ marginTop: 20 }}>
          <p className="alert-title">尚未完成助記詞備份</p>
          <p>請盡快備份助記詞，以免無法恢復錢包。</p>
        </div>
      )}

      <p className="field-hint" style={{ marginTop: 24, textAlign: "center" }}>
        後續可在此整合 AI 助理、轉帳與多鏈餘額等功能。
      </p>
    </Layout>
  );
}
