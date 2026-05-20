import { create } from "zustand";
import { DEFAULT_CHAIN_ID } from "../data/chains";

export type OnboardingMode = "create" | "import";
export type ChainSectionId = "popular" | "layer1" | "layer2" | "evm";

interface OnboardingState {
  mode: OnboardingMode | null;
  walletName: string;
  password: string;
  passwordHint: string;
  mnemonic: string;
  keystoreJson: string;
  evmAddress: string;
  selectedChainId: string;
  selectionAnchor: string;
  backupSkipped: boolean;

  setMode: (mode: OnboardingMode) => void;
  setWalletMeta: (name: string, password: string, hint: string) => void;
  setMnemonic: (mnemonic: string) => void;
  setKeystoreJson: (keystoreJson: string) => void;
  setEvmAddress: (evmAddress: string) => void;
  selectChain: (section: ChainSectionId, chainId: string) => void;
  setBackupSkipped: (skipped: boolean) => void;
  reset: () => void;
}

const defaultAnchor = `popular:${DEFAULT_CHAIN_ID}`;

const initial = {
  mode: null as OnboardingMode | null,
  walletName: "",
  password: "",
  passwordHint: "",
  mnemonic: "",
  keystoreJson: "",
  evmAddress: "",
  selectedChainId: DEFAULT_CHAIN_ID,
  selectionAnchor: defaultAnchor,
  backupSkipped: false,
};

export const useOnboarding = create<OnboardingState>((set) => ({
  ...initial,
  setMode: (mode) => set({ mode }),
  setWalletMeta: (walletName, password, passwordHint) =>
    set({ walletName, password, passwordHint }),
  setMnemonic: (mnemonic) => set({ mnemonic }),
  setKeystoreJson: (keystoreJson) => set({ keystoreJson }),
  setEvmAddress: (evmAddress) => set({ evmAddress }),
  selectChain: (section, chainId) =>
    set({
      selectedChainId: chainId,
      selectionAnchor: `${section}:${chainId}`,
    }),
  setBackupSkipped: (backupSkipped) => set({ backupSkipped }),
  reset: () => set(initial),
}));

export function isChainSelected(
  selectionAnchor: string,
  section: ChainSectionId,
  chainId: string
): boolean {
  return selectionAnchor === `${section}:${chainId}`;
}
