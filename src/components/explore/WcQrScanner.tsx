import { useEffect, useRef } from "react";
import { Html5Qrcode } from "html5-qrcode";
import { Button } from "@repo/ui/components/button";

const READER_ID = "wc-qr-reader";

export function extractWcUri(raw: string): string | null {
  const text = raw.trim();
  if (text.startsWith("wc:")) return text;
  try {
    const url = new URL(text);
    for (const key of ["uri", "wc", "wcUri"]) {
      const v = url.searchParams.get(key);
      if (v?.startsWith("wc:")) return decodeURIComponent(v);
    }
  } catch {
    /* not a URL */
  }
  const match = text.match(/wc:[^\s"']+/);
  return match ? match[0] : null;
}

interface WcQrScannerProps {
  onScan: (uri: string) => void;
  onClose: () => void;
}

export function WcQrScanner({ onScan, onClose }: WcQrScannerProps) {
  const scannerRef = useRef<Html5Qrcode | null>(null);

  useEffect(() => {
    const scanner = new Html5Qrcode(READER_ID);
    scannerRef.current = scanner;

    scanner
      .start(
        { facingMode: "environment" },
        { fps: 8, qrbox: { width: 220, height: 220 } },
        (decoded) => {
          const uri = extractWcUri(decoded);
          if (!uri) return;
          scanner
            .stop()
            .then(() => onScan(uri))
            .catch(() => onScan(uri));
        },
        () => {
          /* ignore scan misses */
        }
      )
      .catch(() => {
        /* camera denied or unavailable */
      });

    return () => {
      scanner
        .stop()
        .then(() => scanner.clear())
        .catch(() => {});
      scannerRef.current = null;
    };
  }, [onScan]);

  return (
    <div className="wc-qr-scanner">
      <div className="wc-qr-scanner__head">
        <p className="wc-qr-scanner__title">掃描 Venus 的 WalletConnect QR</p>
        <Button type="button" variant="ghost" size="sm" onClick={onClose}>
          關閉
        </Button>
      </div>
      <p className="field-hint">
        將相機對準下方 Venus 彈窗裡的 QR 碼（電腦版可把 QR 放在畫面中央）。
      </p>
      <div id={READER_ID} className="wc-qr-scanner__view" />
    </div>
  );
}
