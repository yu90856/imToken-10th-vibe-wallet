import { useMemo, useState } from "react";
import { SortBar } from "../../components/SortBar";
import { TokenRow } from "../../components/TokenRow";
import {
  MARKET_TOKENS,
  sortTokens,
  type SortKey,
  type TokenMarket,
} from "../../data/tokens";
import { useAppStore } from "../../store/app";

function TokenSection({
  title,
  tokens,
  sort,
  emptyHint,
}: {
  title: string;
  tokens: TokenMarket[];
  sort: SortKey;
  emptyHint?: string;
}) {
  const sorted = useMemo(() => sortTokens(tokens, sort), [tokens, sort]);

  return (
    <section className="market-section">
      <h2 className="section-title">{title}</h2>
      {sorted.length === 0 ? (
        <p className="field-hint">{emptyHint ?? "暫無資料"}</p>
      ) : (
        <div className="token-list">
          {sorted.map((t) => (
            <TokenRow key={t.id} token={t} />
          ))}
        </div>
      )}
    </section>
  );
}

export function MarketPage() {
  const [query, setQuery] = useState("");
  const sort = useAppStore((s) => s.marketSort);
  const setSort = useAppStore((s) => s.setMarketSort);
  const watchlist = useAppStore((s) => s.watchlist);

  const q = query.trim().toLowerCase();

  const filtered = useMemo(() => {
    if (!q) return MARKET_TOKENS;
    return MARKET_TOKENS.filter(
      (t) =>
        t.name.toLowerCase().includes(q) ||
        t.symbol.toLowerCase().includes(q) ||
        t.address?.toLowerCase().includes(q)
    );
  }, [q]);

  const watchTokens = useMemo(
    () =>
      watchlist
        .map((id) => MARKET_TOKENS.find((t) => t.id === id))
        .filter((t): t is TokenMarket => !!t),
    [watchlist]
  );

  const mainstream = filtered.filter((t) => t.category === "mainstream");
  const onchain = filtered.filter((t) => t.category === "onchain");

  return (
    <div className="tab-page tab-page--scroll">
      <div className="search-bar">
        <input
          type="search"
          placeholder="搜尋代幣名稱或合約地址"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />
      </div>

      <p className="field-hint market-pair-hint">報價交易對：代幣 / USDT</p>

      <SortBar value={sort} onChange={setSort} />

      <TokenSection
        title="關注列表"
        tokens={q ? watchTokens.filter((t) => filtered.includes(t)) : watchTokens}
        sort={sort}
        emptyHint="點擊星號將代幣加入關注列表"
      />
      <TokenSection title="主流代幣" tokens={mainstream} sort={sort} />
      <TokenSection title="鏈上代幣" tokens={onchain} sort={sort} />
    </div>
  );
}
