import { useNavigate } from "react-router-dom";
import { Layout } from "../components/Layout";
import { getChain } from "../data/chains";
import { loadVault } from "../lib/vault";

export function WalletReadyPage() {
  const navigate = useNavigate();
  const vault = loadVault();

  if (!vault) {
    navigate("/", { replace: true });
    return null;
  }

  const chain = getChain(vault.chainIds[0] ?? "ethereum");

  return (
    <Layout center>
      <div className="logo-mark" aria-hidden>
        ✓
      </div>
      <header className="page-header" style={{ textAlign: "center" }}>
        <h1>錢包已就緒</h1>
        <p>{vault.walletName} 已建立，以下為您的鏈上地址。</p>
      </header>

      <div className="card ready-card">
        <p className="field-hint">{chain?.name ?? "主網"} 地址</p>
        <p className="ready-address">{vault.evmAddress}</p>
        {!vault.backupCompleted && (
          <p className="field-hint" style={{ marginTop: 12, color: "var(--warning)" }}>
            助記詞尚未備份，請稍後於設定中完成。
          </p>
        )}
      </div>

      <div className="actions-stack">
        <button
          type="button"
          className="btn btn--primary"
          onClick={() => navigate("/app/home", { replace: true })}
        >
          確認進入錢包
        </button>
      </div>
    </Layout>
  );
}
