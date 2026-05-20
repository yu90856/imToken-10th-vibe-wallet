import { useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { Layout } from "../components/Layout";
import { mnemonicToWords } from "../lib/tokenCore";
import { useOnboarding } from "../store/onboarding";

function shuffle<T>(arr: T[]): T[] {
  const copy = [...arr];
  for (let i = copy.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy;
}

export function BackupVerifyPage() {
  const navigate = useNavigate();
  const mnemonic = useOnboarding((s) => s.mnemonic);
  const words = mnemonicToWords(mnemonic);

  const pool = useMemo(() => shuffle(words), [mnemonic]);
  const [filled, setFilled] = useState<string[]>([]);
  const [error, setError] = useState("");

  const pickWord = (word: string) => {
    if (filled.length >= words.length) return;
    setFilled((prev) => [...prev, word]);
    setError("");
  };

  const clearSlot = (index: number) => {
    setFilled((prev) => prev.filter((_, i) => i !== index));
    setError("");
  };

  const usedCount = (word: string) =>
    filled.filter((w) => w === word).length;

  const poolUsed = (word: string) =>
    words.filter((w) => w === word).length;

  const isWordDisabled = (word: string) =>
    usedCount(word) >= poolUsed(word);

  const submit = () => {
    if (filled.length !== words.length) {
      setError("請依序選滿 12 個單字");
      return;
    }
    const ok = filled.every((w, i) => w === words[i]);
    if (!ok) {
      setError("順序不正確，請對照您的備份重試");
      setFilled([]);
      return;
    }
    navigate("/finish");
  };

  return (
    <Layout backTo="/backup-reveal">
      <header className="page-header">
        <h1>確認助記詞</h1>
        <p>請依正確順序點選單字，以驗證您已正確備份。</p>
      </header>

      <div className="verify-slots">
        {words.map((_, i) => (
          <button
            key={i}
            type="button"
            className={`verify-slot${filled[i] ? " verify-slot--filled" : ""}`}
            onClick={() => filled[i] && clearSlot(i)}
          >
            {filled[i] ? (
              <>
                <span className="mnemonic-index">{i + 1}</span> {filled[i]}
              </>
            ) : (
              <span className="mnemonic-index">{i + 1}</span>
            )}
          </button>
        ))}
      </div>

      <div className="verify-pool">
        {pool.map((word, i) => (
          <button
            key={`${word}-${i}`}
            type="button"
            className="verify-chip"
            disabled={isWordDisabled(word)}
            onClick={() => pickWord(word)}
          >
            {word}
          </button>
        ))}
      </div>

      {error && <p className="field-error">{error}</p>}

      <div className="actions-stack">
        <button
          type="button"
          className="btn btn--primary"
          disabled={filled.length !== words.length}
          onClick={submit}
        >
          完成備份
        </button>
      </div>
    </Layout>
  );
}
