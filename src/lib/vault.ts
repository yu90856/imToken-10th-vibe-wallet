import type { Chain } from "../data/chains";

export const VAULT_STORAGE_KEY = "vibe-wallet-vault";

/** v2: Token Core keystore (tcx-wasm) */
export interface WalletVault {
  version: 2;
  walletName: string;
  passwordHint?: string;
  keystoreJson: string;
  chainIds: string[];
  evmAddress: string;
  backupCompleted: boolean;
  createdAt: string;
}

export async function saveVault(
  vault: Omit<WalletVault, "version">
): Promise<WalletVault> {
  const stored: WalletVault = { version: 2, ...vault };
  localStorage.setItem(VAULT_STORAGE_KEY, JSON.stringify(stored));
  return stored;
}

export function loadVault(): WalletVault | null {
  const raw = localStorage.getItem(VAULT_STORAGE_KEY);
  if (!raw) return null;
  try {
    const data = JSON.parse(raw) as WalletVault & { version?: number };
    if (data.version !== 2 || !data.keystoreJson) return null;
    return data as WalletVault;
  } catch {
    return null;
  }
}

export function hasVault(): boolean {
  return loadVault() !== null;
}

export function clearVault(): void {
  localStorage.removeItem(VAULT_STORAGE_KEY);
}

export function formatChains(chains: Chain[]): string {
  return chains.map((c) => c.name).join("、");
}
