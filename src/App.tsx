import type { ReactNode } from "react";
import { Navigate, Route, Routes } from "react-router-dom";
import { AppShell } from "./layouts/AppShell";
import { hasVault } from "./lib/vault";
import { BackupIntroPage } from "./pages/BackupIntro";
import { BackupRevealPage } from "./pages/BackupReveal";
import { BackupVerifyPage } from "./pages/BackupVerify";
import { CreateWalletPage } from "./pages/CreateWallet";
import { FinishSetupPage } from "./pages/FinishSetup";
import { ImportChainsPage } from "./pages/ImportChains";
import { ImportWalletPage } from "./pages/ImportWallet";
import { SelectChainPage } from "./pages/SelectChain";
import { WalletReadyPage } from "./pages/WalletReady";
import { WelcomePage } from "./pages/Welcome";
import { AssetsPage } from "./pages/app/Assets";
import { DashboardHomePage } from "./pages/app/DashboardHome";
import { ExplorePage } from "./pages/app/Explore";
import { MarketPage } from "./pages/app/Market";
import { TokenDetailPage } from "./pages/app/TokenDetail";
import { SwapPage } from "./pages/app/Swap";
import { IntegrationCheckPage } from "./pages/IntegrationCheck";

function RootRedirect() {
  return hasVault() ? <Navigate to="/app/home" replace /> : <WelcomePage />;
}

function AppGuard({ children }: { children: ReactNode }) {
  if (!hasVault()) return <Navigate to="/" replace />;
  return children;
}

export default function App() {
  return (
    <Routes>
      <Route path="/" element={<RootRedirect />} />
      <Route path="/create" element={<CreateWalletPage />} />
      <Route path="/select-chain" element={<SelectChainPage />} />
      <Route path="/backup-intro" element={<BackupIntroPage />} />
      <Route path="/backup-reveal" element={<BackupRevealPage />} />
      <Route path="/backup-verify" element={<BackupVerifyPage />} />
      <Route path="/finish" element={<FinishSetupPage />} />
      <Route path="/import" element={<ImportWalletPage />} />
      <Route path="/import/chains" element={<ImportChainsPage />} />
      <Route path="/wallet-ready" element={<WalletReadyPage />} />
      <Route path="/debug" element={<IntegrationCheckPage />} />

      <Route
        path="/app"
        element={
          <AppGuard>
            <AppShell />
          </AppGuard>
        }
      >
        <Route index element={<Navigate to="home" replace />} />
        <Route path="home" element={<DashboardHomePage />} />
        <Route path="market" element={<MarketPage />} />
        <Route path="market/:tokenId" element={<TokenDetailPage />} />
        <Route path="swap" element={<SwapPage />} />
        <Route path="explore" element={<ExplorePage />} />
        <Route path="assets" element={<AssetsPage />} />
      </Route>

      <Route path="/home" element={<Navigate to="/app/home" replace />} />
      <Route path="/app/defi" element={<Navigate to="/app/explore" replace />} />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
