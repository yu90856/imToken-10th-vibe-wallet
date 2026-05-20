import { Link } from "react-router-dom";
import type { TokenMarket } from "../data/tokens";
import { formatChange, formatPrice, formatVolume } from "../data/tokens";
import { useAppStore } from "../store/app";
import { TokenIcon } from "./TokenIcon";

interface TokenRowProps {
  token: TokenMarket;
  showStar?: boolean;
}

export function TokenRow({ token, showStar = true }: TokenRowProps) {
  const watched = useAppStore((s) => s.isWatched(token.id));
  const toggle = useAppStore((s) => s.toggleWatchlist);
  const up = token.change24h >= 0;

  return (
    <Link to={`/app/market/${token.id}`} className="token-row token-row--link">
      {showStar && (
        <button
          type="button"
          className={`token-row__star${watched ? " token-row__star--on" : ""}`}
          onClick={(e) => {
            e.preventDefault();
            e.stopPropagation();
            toggle(token.id);
          }}
          aria-label={watched ? "取消關注" : "加入關注"}
        >
          {watched ? "★" : "☆"}
        </button>
      )}
      <TokenIcon symbol={token.symbol} />
      <div className="token-row__main">
        <div className="token-row__top">
          <span className="token-row__name">{token.name}</span>
          <span className="token-row__price">${formatPrice(token.priceUsdt)}</span>
        </div>
        <div className="token-row__bottom">
          <span className="token-row__vol">
            {token.chainLabel ? `${token.chainLabel} · ` : ""}
            Vol {formatVolume(token.volume24h)}
          </span>
          <span className={`token-row__chg${up ? " token-row__chg--up" : " token-row__chg--down"}`}>
            {formatChange(token.change24h)}
          </span>
        </div>
      </div>
    </Link>
  );
}
