import { FormEvent, useState } from "react";
import { useNavigate } from "react-router-dom";
import { Button } from "@repo/ui/components/button";
import { Layout } from "../components/Layout";
import { createWalletKeystore, deriveEthereumAddress } from "../lib/tokenCore";
import { useOnboarding } from "../store/onboarding";

export function CreateWalletPage() {
  const navigate = useNavigate();
  const { setWalletMeta, setMnemonic, setKeystoreJson, setEvmAddress } =
    useOnboarding();

  const [name, setName] = useState("");
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [hint, setHint] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const onSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setError("");

    if (!name.trim()) {
      setError("請輸入錢包名稱");
      return;
    }
    if (password.length < 8) {
      setError("密碼至少需要 8 個字元");
      return;
    }
    if (password !== confirm) {
      setError("兩次輸入的密碼不一致");
      return;
    }

    setLoading(true);
    try {
      const { keystoreJson, mnemonic } = await createWalletKeystore(password);
      const evmAddress = await deriveEthereumAddress(keystoreJson, password);
      setWalletMeta(name.trim(), password, hint.trim());
      setKeystoreJson(keystoreJson);
      setEvmAddress(evmAddress);
      setMnemonic(mnemonic);
      navigate("/select-chain");
    } catch {
      setError("建立錢包失敗，請重試");
    } finally {
      setLoading(false);
    }
  };

  return (
    <Layout backTo="/">
      <header className="page-header">
        <h1>創建錢包</h1>
        <p>
          由 Token Core（tcx-wasm）在本機生成加密 keystore，助記詞不會離開您的裝置。
        </p>
      </header>

      <form onSubmit={onSubmit}>
        <div className="field">
          <label htmlFor="wallet-name">錢包名稱</label>
          <input
            id="wallet-name"
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="例如：我的主錢包"
            autoComplete="off"
          />
        </div>

        <div className="field">
          <label htmlFor="password">密碼</label>
          <input
            id="password"
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            placeholder="至少 8 個字元"
            autoComplete="new-password"
          />
        </div>

        <div className="field">
          <label htmlFor="confirm">確認密碼</label>
          <input
            id="confirm"
            type="password"
            value={confirm}
            onChange={(e) => setConfirm(e.target.value)}
            autoComplete="new-password"
          />
        </div>

        <div className="field">
          <label htmlFor="hint">密碼提示（選填）</label>
          <input
            id="hint"
            value={hint}
            onChange={(e) => setHint(e.target.value)}
            placeholder="僅供您自己回想，請勿寫入密碼本身"
            autoComplete="off"
          />
          <p className="field-hint">提示會以明文儲存於本機，請勿包含敏感資訊。</p>
        </div>

        {error && <p className="field-error">{error}</p>}

        <div className="actions-stack">
          <Button type="submit" className="w-full" size="lg" disabled={loading}>
            {loading ? "正在建立…" : "下一步：選擇鏈"}
          </Button>
        </div>
      </form>
    </Layout>
  );
}
