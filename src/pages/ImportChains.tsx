import { useNavigate } from "react-router-dom";
import { ChainSelectSections } from "../components/ChainSelectSections";
import { Layout } from "../components/Layout";
import { getChain } from "../data/chains";
import { useOnboarding } from "../store/onboarding";

export function ImportChainsPage() {
  const navigate = useNavigate();
  const { selectedChainId, selectionAnchor, selectChain } = useOnboarding();
  const chain = getChain(selectedChainId);

  return (
    <Layout backTo="/import">
      <header className="page-header">
        <h1>選擇鏈帳戶</h1>
        <p>已預設一條鏈，可點選其他鏈切換。導入後仍為同一組助記詞／私鑰。</p>
      </header>

      <ChainSelectSections
        selectionAnchor={selectionAnchor}
        onSelect={selectChain}
      />

      <p className="field-hint" style={{ marginTop: 16 }}>
        目前選擇：{chain?.name ?? selectedChainId}
      </p>

      <div className="actions-stack">
        <button
          type="button"
          className="btn btn--primary"
          onClick={() => navigate("/import")}
        >
          確認並返回
        </button>
      </div>
    </Layout>
  );
}
