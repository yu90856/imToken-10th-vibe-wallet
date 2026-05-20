import { useOnboarding } from "../store/onboarding";
import { clearVault } from "./vault";

const WATCHLIST_KEY = "vibe-watchlist";

/** 登出：清除本機錢包與相關快取（不會刪除鏈上資產）。 */
export function clearWalletSession(): void {
  clearVault();
  localStorage.removeItem(WATCHLIST_KEY);
  useOnboarding.getState().reset();
}
