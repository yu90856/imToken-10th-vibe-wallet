import { useEffect, useRef, useState } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { Button } from "@repo/ui/components/button";
import { getChain } from "../data/chains";
import { Layout } from "../components/Layout";
import { deriveEthereumAddress } from "../lib/tokenCore";
import { saveVault } from "../lib/vault";
import { useOnboarding } from "../store/onboarding";

export function FinishSetupPage() {
  const navigate = useNavigate();
  const [params] = useSearchParams();
  const skipped = params.get("skipped") === "1";

  const state = useOnboarding();
  const [error, setError] = useState("");
  const [saving, setSaving] = useState(true);
  const started = useRef(false);

  const persist = async () => {
    setSaving(true);
    setError("");
    try {
      let evmAddress = state.evmAddress;
      if (!evmAddress) {
        evmAddress = await deriveEthereumAddress(
          state.keystoreJson,
          state.password
        );
      }
      await saveVault({
        walletName: state.walletName,
        passwordHint: state.passwordHint || undefined,
        keystoreJson: state.keystoreJson,
        chainIds: [state.selectedChainId],
        evmAddress,
        backupCompleted: !skipped && !state.backupSkipped,
        createdAt: new Date().toISOString(),
      });
      useOnboarding.getState().reset();
      navigate("/wallet-ready", { replace: true });
    } catch (e) {
      console.error("[FinishSetup]", e);
      setError(
        e instanceof Error && e.message
          ? `儲存失敗：${e.message}`
          : "儲存錢包失敗，請重試"
      );
      setSaving(false);
    }
  };

  useEffect(() => {
    if (!state.mnemonic || !state.keystoreJson || !state.selectedChainId) {
      navigate("/", { replace: true });
      return;
    }
    if (started.current) return;
    started.current = true;
    persist();
  }, [
    navigate,
    state.keystoreJson,
    state.mnemonic,
    state.selectedChainId,
  ]);

  const chainName = getChain(state.selectedChainId)?.name;

  return (
    <Layout center>
      <header className="page-header" style={{ textAlign: "center" }}>
        <h1>{saving ? "正在建立錢包…" : "建立失敗"}</h1>
        <p>
          {saving
            ? `Token Core 正在為您設定 ${chainName ?? "區塊鏈"} 帳戶。`
            : error}
        </p>
      </header>
      {!skipped && saving && (
        <p className="field-hint" style={{ textAlign: "center" }}>
          助記詞備份已完成 ✓
        </p>
      )}
      {skipped && saving && (
        <div className="alert alert--warning" style={{ marginTop: 16 }}>
          您選擇稍後備份。請盡快於設定中完成助記詞備份，以免遺失資產。
        </div>
      )}
      {!saving && error && (
        <div className="actions-stack">
          <Button type="button" className="w-full" size="lg" onClick={persist}>
            重試
          </Button>
          <Button
            type="button"
            variant="ghost"
            className="w-full"
            onClick={() => navigate("/create")}
          >
            返回創建錢包
          </Button>
        </div>
      )}
    </Layout>
  );
}
