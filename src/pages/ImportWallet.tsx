import { FormEvent, useState } from "react";
import { useNavigate } from "react-router-dom";
import { getChain } from "../data/chains";
import { Layout } from "../components/Layout";
import {
  deriveEthereumAddress,
  importWalletKeystore,
  normalizeMnemonic,
  validateMnemonicWithCore,
} from "../lib/tokenCore";
import {
  addressFromPrivateKey,
  externalPrivateKeyKeystore,
} from "../lib/wallet";
import { saveVault } from "../lib/vault";
import { useOnboarding } from "../store/onboarding";

type ImportTab = "mnemonic" | "privateKey";

export function ImportWalletPage() {
  const navigate = useNavigate();
  const { walletName, password, passwordHint, selectedChainId, setMnemonic } =
    useOnboarding();

  const [tab, setTab] = useState<ImportTab>("mnemonic");
  const [name, setName] = useState(walletName);
  const [pwd, setPwd] = useState(password);
  const [confirm, setConfirm] = useState("");
  const [hint, setHint] = useState(passwordHint);
  const [secret, setSecret] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const onSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setError("");

    if (!name.trim()) {
      setError("請輸入錢包名稱");
      return;
    }
    if (pwd.length < 8) {
      setError("密碼至少需要 8 個字元");
      return;
    }
    if (pwd !== confirm) {
      setError("兩次輸入的密碼不一致");
      return;
    }
    if (!selectedChainId) {
      setError("請先選擇鏈帳戶");
      return;
    }

    setLoading(true);
    try {
      let keystoreJson: string;
      let evmAddress: string;

      if (tab === "mnemonic") {
        const phrase = normalizeMnemonic(secret);
        const valid = await validateMnemonicWithCore(pwd, phrase);
        if (!valid) {
          setError("助記詞格式無效，請檢查單字與順序");
          setLoading(false);
          return;
        }
        keystoreJson = await importWalletKeystore(pwd, phrase);
        evmAddress = await deriveEthereumAddress(keystoreJson, pwd);
      } else {
        const key = secret.trim().replace(/^0x/, "");
        if (!/^[0-9a-fA-F]{64}$/.test(key)) {
          setError("私鑰格式無效（需為 64 位十六進制）");
          setLoading(false);
          return;
        }
        evmAddress = addressFromPrivateKey(key);
        keystoreJson = externalPrivateKeyKeystore(key);
      }

      await saveVault({
        walletName: name.trim(),
        passwordHint: hint.trim() || undefined,
        keystoreJson,
        chainIds: [selectedChainId],
        evmAddress,
        backupCompleted: true,
        createdAt: new Date().toISOString(),
      });

      setMnemonic("");
      useOnboarding.getState().reset();
      navigate("/wallet-ready", { replace: true });
    } catch {
      setError("導入失敗，請稍後重試");
      setLoading(false);
    }
  };

  const goSelectChain = () => {
    if (!name.trim() || pwd.length < 8 || pwd !== confirm) {
      setError("請先完成錢包名稱與密碼設定");
      return;
    }
    useOnboarding.getState().setWalletMeta(name.trim(), pwd, hint.trim());
    navigate("/import/chains");
  };

  return (
    <Layout backTo="/">
      <header className="page-header">
        <h1>導入錢包</h1>
        <p>使用助記詞或私鑰恢復已有錢包。請在安全環境下操作。</p>
      </header>

      <div className="tabs" role="tablist">
        <button
          type="button"
          role="tab"
          className={`tab${tab === "mnemonic" ? " tab--active" : ""}`}
          onClick={() => setTab("mnemonic")}
        >
          助記詞
        </button>
        <button
          type="button"
          role="tab"
          className={`tab${tab === "privateKey" ? " tab--active" : ""}`}
          onClick={() => setTab("privateKey")}
        >
          私鑰
        </button>
      </div>

      <form onSubmit={onSubmit}>
        <div className="field">
          <label htmlFor="import-name">錢包名稱</label>
          <input
            id="import-name"
            value={name}
            onChange={(e) => setName(e.target.value)}
            autoComplete="off"
          />
        </div>

        <div className="field">
          <label htmlFor="import-pwd">密碼</label>
          <input
            id="import-pwd"
            type="password"
            value={pwd}
            onChange={(e) => setPwd(e.target.value)}
            autoComplete="new-password"
          />
        </div>

        <div className="field">
          <label htmlFor="import-confirm">確認密碼</label>
          <input
            id="import-confirm"
            type="password"
            value={confirm}
            onChange={(e) => setConfirm(e.target.value)}
          />
        </div>

        <div className="field">
          <label htmlFor="import-hint">密碼提示（選填）</label>
          <input
            id="import-hint"
            value={hint}
            onChange={(e) => setHint(e.target.value)}
          />
        </div>

        <div className="field">
          <label htmlFor="import-secret">
            {tab === "mnemonic" ? "助記詞（12 個單字）" : "私鑰"}
          </label>
          <textarea
            id="import-secret"
            rows={tab === "mnemonic" ? 4 : 3}
            value={secret}
            onChange={(e) => setSecret(e.target.value)}
            placeholder={
              tab === "mnemonic"
                ? "word1 word2 word3 …"
                : "0x 或 64 位十六進制私鑰"
            }
            style={{
              width: "100%",
              padding: "14px 16px",
              background: "var(--bg-card)",
              border: "1px solid var(--border)",
              borderRadius: "var(--radius-sm)",
              fontFamily: tab === "mnemonic" ? "var(--mono)" : "inherit",
              resize: "vertical",
            }}
          />
        </div>

        <p className="field-hint">
          目前鏈：{selectedChainId ? getChain(selectedChainId)?.name : "預設 Ethereum"}
        </p>

        {error && <p className="field-error">{error}</p>}

        <div className="actions-stack">
          <button type="button" className="btn btn--secondary" onClick={goSelectChain}>
            變更所選鏈
          </button>
          <button
            type="submit"
            className="btn btn--primary"
            disabled={loading}
          >
            {loading ? "導入中…" : "完成導入"}
          </button>
        </div>
      </form>
    </Layout>
  );
}
