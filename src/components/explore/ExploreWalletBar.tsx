import { useEffect, useState } from "react";
import { Button } from "@repo/ui/components/button";
import { toast } from "@repo/ui/components/toast";
import {
  disconnectWc,
  getWcStatus,
  initWcWallet,
  pairWithUri,
  subscribeWcStatus,
} from "../../lib/wcWalletHost";
import { loadVault } from "../../lib/vault";
import { extractWcUri, WcQrScanner } from "./WcQrScanner";

interface ExploreWalletBarProps {
  dappUrl: string;
}

export function ExploreWalletBar({ dappUrl }: ExploreWalletBarProps) {
  const vault = loadVault();
  const [wcUri, setWcUri] = useState("");
  const [scanning, setScanning] = useState(false);
  const [, tick] = useState(0);
  const { status, message } = getWcStatus();
  const isBnb = /venus|pancake|biswap/i.test(dappUrl);

  useEffect(() => {
    initWcWallet().catch(() => {
      toast.error("WalletConnect 初始化失敗，請設定 VITE_WC_PROJECT_ID");
    });
    return subscribeWcStatus(() => {
      tick((n) => n + 1);
    });
  }, []);

  if (!vault) return null;

  const copyAddress = async () => {
    await navigator.clipboard.writeText(vault.evmAddress);
    toast.success("地址已複製");
  };

  const pairUri = async (uri: string) => {
    try {
      await pairWithUri(uri);
      setWcUri(uri);
      setScanning(false);
      toast.success("配對請求已送出，請在 Venus 確認連線");
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "配對失敗");
    }
  };

  const onPair = () => pairUri(wcUri);

  const pasteFromClipboard = async () => {
    try {
      const text = await navigator.clipboard.readText();
      const uri = extractWcUri(text);
      if (!uri) {
        toast.error("剪貼簿沒有 wc: 連線碼，請在 Venus 點「Copy link」再試");
        return;
      }
      setWcUri(uri);
      toast.success("已貼上連線碼");
    } catch {
      toast.error("無法讀取剪貼簿，請手動貼到下方文字框");
    }
  };

  return (
    <div className="explore-wallet-bar card">
      <div className="explore-wallet-bar__row">
        <div>
          <p className="field-hint">Vibe 錢包</p>
          <p className="explore-wallet-bar__addr">
            {vault.evmAddress.slice(0, 6)}…{vault.evmAddress.slice(-4)}
          </p>
        </div>
        <Button type="button" variant="outline" size="sm" onClick={copyAddress}>
          複製地址
        </Button>
      </div>

      <details className="explore-wallet-bar__wc" open={status !== "connected"}>
        <summary>連接 Venus（WalletConnect）</summary>

        <ol className="explore-wc-steps field-hint">
          <li>在下方 Venus 頁點 <strong>Connect Wallet</strong></li>
          <li>選 <strong>WalletConnect</strong>（會出現 QR 碼）</li>
          <li>
            用本工具列 <strong>掃描 QR</strong>，或點 QR 旁的{" "}
            <strong>Copy link / 複製連結</strong> 後按「從剪貼簿貼上」
          </li>
          <li>按 <strong>配對連線</strong>，狀態顯示「已連接」即可在 Venus 操作</li>
        </ol>

        {scanning ? (
          <WcQrScanner
            onScan={(uri) => {
              setWcUri(uri);
              void pairUri(uri);
            }}
            onClose={() => setScanning(false)}
          />
        ) : (
          <div className="explore-wallet-bar__actions explore-wallet-bar__actions--top">
            <Button type="button" size="sm" onClick={() => setScanning(true)}>
              掃描 Venus QR
            </Button>
            <Button type="button" variant="outline" size="sm" onClick={() => void pasteFromClipboard()}>
              從剪貼簿貼上
            </Button>
          </div>
        )}

        <textarea
          className="explore-wc-input"
          placeholder="wc:…（或貼上 Copy link 的內容）"
          value={wcUri}
          onChange={(e) => setWcUri(e.target.value)}
          rows={2}
        />
        <div className="explore-wallet-bar__actions">
          <Button type="button" size="sm" onClick={onPair} disabled={!wcUri.trim()}>
            配對連線
          </Button>
          {status === "connected" && (
            <Button type="button" variant="ghost" size="sm" onClick={() => disconnectWc()}>
              斷開
            </Button>
          )}
        </div>
        <p className={`field-hint explore-wc-status explore-wc-status--${status}`}>
          {message || "等待連線"}
        </p>
        {isBnb && (
          <p className="field-hint explore-wallet-bar__hint">
            請確認 Venus 網路為 BNB Chain；本錢包已支援 Ethereum 與 BNB（鏈 ID 56）。
          </p>
        )}
      </details>
    </div>
  );
}
