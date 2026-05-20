import { useEffect, useState } from "react";
import { Button } from "@repo/ui/components/button";
import {
  disconnectWc,
  getWcStatus,
  initWcWallet,
  subscribeWcStatus,
} from "../../lib/wcWalletHost";
import { loadVault } from "../../lib/vault";
import { ConnectSiteSheet } from "./ConnectSiteSheet";

function siteLabelFromUrl(url: string): string {
  try {
    const host = new URL(url).hostname.replace(/^www\./, "");
    if (/venus/i.test(host)) return "Venus";
    if (/pancake/i.test(host)) return "PancakeSwap";
    if (/uniswap/i.test(host)) return "Uniswap";
    return host.split(".")[0] || "網站";
  } catch {
    return "網站";
  }
}

interface DappConnectBarProps {
  dappUrl: string;
}

export function DappConnectBar({ dappUrl }: DappConnectBarProps) {
  const vault = loadVault();
  const [sheetOpen, setSheetOpen] = useState(false);
  const [, tick] = useState(0);
  const { status } = getWcStatus();
  const connected = status === "connected";
  const label = siteLabelFromUrl(dappUrl);

  useEffect(() => {
    initWcWallet().catch(() => {});
    return subscribeWcStatus(() => tick((n) => n + 1));
  }, []);

  useEffect(() => {
    if (!dappUrl || connected) return;
    const key = `vibe-connect-prompt:${dappUrl}`;
    if (sessionStorage.getItem(key)) return;
    sessionStorage.setItem(key, "1");
    const t = window.setTimeout(() => setSheetOpen(true), 600);
    return () => clearTimeout(t);
  }, [dappUrl, connected]);

  if (!vault) return null;

  return (
    <>
      <div className={`dapp-connect-bar${connected ? " dapp-connect-bar--on" : ""}`}>
        <div className="dapp-connect-bar__status">
          <span className={`dapp-connect-bar__dot${connected ? " dapp-connect-bar__dot--on" : ""}`} />
          <div>
            <p className="dapp-connect-bar__title">
              {connected ? `已連接 ${label}` : `尚未連接 ${label}`}
            </p>
            <p className="field-hint dapp-connect-bar__addr">
              {vault.evmAddress.slice(0, 8)}…{vault.evmAddress.slice(-6)}
            </p>
          </div>
        </div>
        <div className="dapp-connect-bar__actions">
          {connected ? (
            <Button type="button" variant="outline" size="sm" onClick={() => disconnectWc()}>
              斷開
            </Button>
          ) : (
            <Button type="button" size="sm" onClick={() => setSheetOpen(true)}>
              連接網站
            </Button>
          )}
        </div>
      </div>

      {sheetOpen && !connected && (
        <ConnectSiteSheet siteLabel={label} onClose={() => setSheetOpen(false)} />
      )}
    </>
  );
}
