import { useNavigate } from "react-router-dom";
import { Button } from "@repo/ui/components/button";
import { Layout } from "../components/Layout";
import { useOnboarding } from "../store/onboarding";

export function WelcomePage() {
  const navigate = useNavigate();
  const setMode = useOnboarding((s) => s.setMode);

  return (
    <Layout center>
      <div className="logo-mark" aria-hidden>
        ◈
      </div>
      <h1 className="welcome-title">Vibe Wallet</h1>
      <p className="welcome-sub">
        AI 個人錢包 — 基於 imToken Token Core 與 Design System 構建。
      </p>
      <div className="actions-stack" style={{ marginTop: 0 }}>
        <Button type="button" className="w-full" size="lg" onClick={() => {
          useOnboarding.getState().reset();
          setMode("create");
          navigate("/create");
        }}>
          創建錢包
        </Button>
        <Button
          type="button"
          variant="secondary"
          className="w-full"
          size="lg"
          onClick={() => {
            useOnboarding.getState().reset();
            setMode("import");
            navigate("/import");
          }}
        >
          導入錢包
        </Button>
        <Button
          type="button"
          variant="ghost"
          className="w-full"
          onClick={() => navigate("/debug")}
        >
          整合自檢
        </Button>
      </div>
    </Layout>
  );
}
