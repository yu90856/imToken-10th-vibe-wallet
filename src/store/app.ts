import { create } from "zustand";
import type { SortKey } from "../data/tokens";

const WATCHLIST_KEY = "vibe-watchlist";

function loadWatchlist(): string[] {
  try {
    const raw = localStorage.getItem(WATCHLIST_KEY);
    return raw ? (JSON.parse(raw) as string[]) : ["btc", "eth"];
  } catch {
    return ["btc", "eth"];
  }
}

interface AppState {
  watchlist: string[];
  balanceHidden: boolean;
  marketSort: SortKey;
  toggleWatchlist: (tokenId: string) => void;
  isWatched: (tokenId: string) => boolean;
  toggleBalanceHidden: () => void;
  setMarketSort: (sort: SortKey) => void;
}

export const useAppStore = create<AppState>()((set, get) => ({
  watchlist: loadWatchlist(),
  balanceHidden: false,
  marketSort: "volume",
  toggleWatchlist: (tokenId) =>
    set((s) => {
      const next = s.watchlist.includes(tokenId)
        ? s.watchlist.filter((id) => id !== tokenId)
        : [...s.watchlist, tokenId];
      localStorage.setItem(WATCHLIST_KEY, JSON.stringify(next));
      return { watchlist: next };
    }),
  isWatched: (tokenId) => get().watchlist.includes(tokenId),
  toggleBalanceHidden: () => set((s) => ({ balanceHidden: !s.balanceHidden })),
  setMarketSort: (marketSort) => set({ marketSort }),
}));
