import { useState } from "react";
import { tokenLogoUrl } from "../lib/chainLogo";

interface TokenIconProps {
  symbol: string;
  size?: number;
}

export function TokenIcon({ symbol, size = 36 }: TokenIconProps) {
  const [failed, setFailed] = useState(false);

  if (failed) {
    return (
      <div
        className="token-icon token-icon--fallback"
        style={{ width: size, height: size, fontSize: size * 0.35 }}
      >
        {symbol.slice(0, 2)}
      </div>
    );
  }

  return (
    <img
      className="token-icon"
      src={tokenLogoUrl(symbol)}
      alt=""
      width={size}
      height={size}
      onError={() => setFailed(true)}
    />
  );
}
