import { useNavigate } from "react-router-dom";
import { Button } from "@repo/ui/components/button";
import { Layout } from "../components/Layout";
import {
  SecurityDangerBanner,
  SecurityWarningBanner,
} from "../components/security/SecurityAlerts";
import { useOnboarding } from "../store/onboarding";

export function BackupIntroPage() {
  const navigate = useNavigate();
  const setBackupSkipped = useOnboarding((s) => s.setBackupSkipped);

  return (
    <Layout backTo="/select-chain">
      <header className="page-header">
        <h1>備份助記詞</h1>
        <p>
          助記詞是恢復錢包的唯一憑證。若遺失且未備份，您的資產將無法找回。
        </p>
      </header>

      <div style={{ marginBottom: 16 }}>
        <SecurityDangerBanner title="⚠ 風險提示">
          請勿將助記詞告知他人、輸入不明網站，或儲存於雲端相簿與截圖。任何取得助記詞的人都能轉走您的資產。
        </SecurityDangerBanner>
      </div>

      <SecurityWarningBanner title="最安全的備份方式">
        <ul className="bullet-list" style={{ marginTop: 8 }}>
          <li>手寫抄錄於紙本，存放於安全、防火防潮處</li>
          <li>使用金屬助記詞板（可選）提高耐久性</li>
          <li>分開保存兩份副本於不同物理位置</li>
          <li>絕不使用截圖、郵件、聊天軟體或雲端筆記</li>
        </ul>
      </SecurityWarningBanner>

      <div className="actions-stack">
        <Button
          type="button"
          className="w-full"
          size="lg"
          onClick={() => {
            setBackupSkipped(false);
            navigate("/backup-reveal");
          }}
        >
          立即備份
        </Button>
        <Button
          type="button"
          variant="ghost"
          className="w-full"
          onClick={() => {
            setBackupSkipped(true);
            navigate("/finish?skipped=1");
          }}
        >
          稍後再說
        </Button>
        </div>
    </Layout>
  );
}
