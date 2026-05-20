import { Link, Navigate, Outlet, useLocation } from "react-router-dom";
import { BottomNav } from "../components/BottomNav";
import { LogoutButton } from "../components/LogoutButton";
import { loadVault } from "../lib/vault";

export function AppShell() {
  const vault = loadVault();
  const location = useLocation();
  const onHome = location.pathname === "/app/home";

  if (!vault) {
    return <Navigate to="/" replace />;
  }

  return (
    <div className="app-frame">
      <header className="app-topbar">
        <Link
          to="/app/home"
          className="app-topbar__brand"
          title="回到首頁"
        >
          <span className="app-topbar__logo">◈</span>
          <span>{vault.walletName}</span>
        </Link>
        <div className="app-topbar__actions">
          {!onHome && (
            <Link to="/app/home" className="app-topbar__home-btn">
              首頁
            </Link>
          )}
          <LogoutButton variant="topbar" />
        </div>
      </header>

      <main className="app-main">
        <Outlet />
      </main>

      <BottomNav />
    </div>
  );
}
