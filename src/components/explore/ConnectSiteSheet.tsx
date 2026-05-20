import { useEffect, useState } from "react";
import { QRCodeSVG } from "qrcode.react";
import { Button } from "@repo/ui/components/button";
import { toast } from "@repo/ui/components/toast";
import {
  createWalletPairingUri,
  getWcStatus,
  pairWithUri,
  subscribeWcStatus,
} from "../../lib/wcWalletHost";
import { WcQrScanner } from "./WcQrScanner";

type ConnectTab = "wallet-qr" | "scan-dapp";

interface ConnectSiteSheetProps {
  siteLabel: string;
  onClose: () => void;
}

export function ConnectSiteSheet({ siteLabel, onClose }: ConnectSiteSheetProps) {
  const [tab, setTab] = useState<ConnectTab>("wallet-qr");
  const [walletUri, setWalletUri] = useState("");
  const [dappUri, setDappUri] = useState("");
  const [loadingQr, setLoadingQr] = useState(false);
  const [, tick] = useState(0);
  const { status, message } = getWcStatus();

  useEffect(() => {
    return subscribeWcStatus(() => tick((n) => n + 1));
  }, []);

  useEffect(() => {
    if (status === "connected") {
      toast.success("已連接網站");
      onClose();
    }
  }, [status, onClose]);

  useEffect(() => {
    if (tab !== "wallet-qr") return;
    let cancelled = false;
    setLoadingQr(true);
    createWalletPairingUri()
      .then((uri) => {
        if (!cancelled) setWalletUri(uri);
      })
      .catch((e) => {
        toast.error(e instanceof Error ? e.message : "無法建立連線碼");
      })
      .finally(() => {
        if (!cancelled) setLoadingQr(false);
      });
    return () => {
      cancelled = true;
    };
  }, [tab]);

  const copyWalletUri = async () => {
    if (!walletUri) return;
    await navigator.clipboard.writeText(walletUri);
    toast.success("連線碼已複製，可貼到網站的 WalletConnect");
  };

  const pairDapp = async () => {
    try {
      await pairWithUri(dappUri);
      toast.success("配對請求已送出");
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "配對失敗");
    }
  };

  return (
    <div className="connect-sheet-backdrop" role="presentation" onClick={onClose}>
      <div
        className="connect-sheet"
        role="dialog"
        aria-labelledby="connect-sheet-title"
        onClick={(e) => e.stopPropagation()}
      >
        <header className="connect-sheet__head">
          <h2 id="connect-sheet-title">連接 {siteLabel}</h2>
          <button type="button" className="connect-sheet__close" onClick={onClose} aria-label="關閉">
            ×
          </button>
        </header>

        <div className="connect-tabs">
          <button
            type="button"
            className={`connect-tabs__btn${tab === "wallet-qr" ? " connect-tabs__btn--active" : ""}`}
            onClick={() => setTab("wallet-qr")}
          >
            推薦 · 網站掃碼
          </button>
          <button
            type="button"
            className={`connect-tabs__btn${tab === "scan-dapp" ? " connect-tabs__btn--active" : ""}`}
            onClick={() => setTab("scan-dapp")}
          >
            掃網站 QR
          </button>
        </div>

        {tab === "wallet-qr" ? (
          <div className="connect-sheet__body">
            <ol className="connect-steps">
              <li>
                在下方 <strong>{siteLabel}</strong> 頁點 <strong>Connect Wallet</strong>
              </li>
              <li>
                選 <strong>WalletConnect</strong> → 點 <strong>掃描 / Scan QR</strong>（或「貼上連結」）
              </li>
              <li>掃描本頁這個二維碼，或複製連線碼貼到網站</li>
            </ol>
            <div className="connect-qr-wrap">
              {loadingQr ? (
                <p className="field-hint">產生連線碼…</p>
              ) : walletUri ? (
                <QRCodeSVG value={walletUri} size={200} level="M" includeMargin />
              ) : (
                <p className="field-hint">無法產生二維碼</p>
              )}
            </div>
            <Button type="button" variant="outline" size="sm" onClick={() => void copyWalletUri()} disabled={!walletUri}>
              複製連線碼
            </Button>
          </div>
        ) : (
          <div className="connect-sheet__body">
            <p className="field-hint">
              若網站只顯示自己的 QR、無法掃碼，請用相機掃描下方網站彈窗中的 QR。
            </p>
            <WcQrScanner
              onScan={(uri) => {
                setDappUri(uri);
                void pairWithUri(uri);
              }}
              onClose={() => setTab("wallet-qr")}
            />
            <textarea
              className="explore-wc-input"
              placeholder="或貼上 wc: 連線碼"
              value={dappUri}
              onChange={(e) => setDappUri(e.target.value)}
              rows={2}
            />
            <Button type="button" size="sm" onClick={() => void pairDapp()} disabled={!dappUri.trim()}>
              配對連線
            </Button>
          </div>
        )}

        <p className={`field-hint explore-wc-status explore-wc-status--${status}`}>{message}</p>
      </div>
    </div>
  );
}
