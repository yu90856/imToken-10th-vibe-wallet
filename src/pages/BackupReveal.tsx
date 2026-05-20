import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Button } from "@repo/ui/components/button";
import { Layout } from "../components/Layout";
import {
  ScreenshotWarningDialog,
  SecurityWarningBanner,
} from "../components/security/SecurityAlerts";
import { mnemonicToWords } from "../lib/tokenCore";
import { useOnboarding } from "../store/onboarding";

export function BackupRevealPage() {
  const navigate = useNavigate();
  const mnemonic = useOnboarding((s) => s.mnemonic);
  const words = mnemonicToWords(mnemonic);

  const [showModal, setShowModal] = useState(true);
  const [revealed, setRevealed] = useState(false);

  return (
    <Layout backTo="/backup-intro">
      <ScreenshotWarningDialog
        open={showModal}
        onConfirm={() => setShowModal(false)}
      />

      <header className="page-header">
        <h1>您的助記詞</h1>
        <p>請依序抄寫以下 12 個單字，並妥善保管紙本備份。</p>
      </header>

      <div className="mnemonic-grid">
        {words.map((word, i) => (
          <div
            key={i}
            className={`mnemonic-word${!revealed ? " mnemonic-word--masked" : ""}`}
          >
            <span className="mnemonic-index">{i + 1}</span>
            {word}
          </div>
        ))}
      </div>

      {!revealed ? (
        <div className="actions-stack">
          <Button
            type="button"
            variant="secondary"
            className="w-full"
            size="lg"
            onClick={() => setRevealed(true)}
          >
            點擊顯示助記詞
          </Button>
        </div>
      ) : (
        <div className="actions-stack">
          <SecurityWarningBanner title="顯示後請勿截圖">
            請勿截圖或分享。確認已手寫備份後再繼續（符合 security/SKILL.md 安全預設）。
          </SecurityWarningBanner>
          <Button
            type="button"
            className="w-full"
            size="lg"
            onClick={() => navigate("/backup-verify")}
          >
            已確認備份助記詞
          </Button>
        </div>
      )}
    </Layout>
  );
}
