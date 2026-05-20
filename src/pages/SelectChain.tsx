import { useNavigate } from "react-router-dom";
import { ChainSelectSections } from "../components/ChainSelectSections";
import { Layout } from "../components/Layout";
import { getChain } from "../data/chains";
import { useOnboarding } from "../store/onboarding";

export function SelectChainPage() {
  const navigate = useNavigate();
  const { selectedChainId, selectionAnchor, selectChain } = useOnboarding();
  const chain = getChain(selectedChainId);

  return (
    <Layout backTo="/create">
      <header className="page-header">
        <h1>新增鏈帳戶</h1>
        <p>
          已預設一條鏈，您可隨時切換。同一錢包僅有一組助記詞，新增鏈不會產生新的助記詞。
        </p>
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
          onClick={() => navigate("/backup-intro")}
        >
          繼續
        </button>
      </div>
    </Layout>
  );
}
