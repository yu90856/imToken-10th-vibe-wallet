import init, {
  create_keystore,
  derive_accounts,
  export_mnemonic,
} from "@consenlabs/tcx-wasm";

let ready: Promise<void> | null = null;

export async function initTokenCore(): Promise<void> {
  if (!ready) {
    ready = init().then(() => undefined);
  }
  await ready;
}

export async function createWalletKeystore(
  password: string,
  mnemonic?: string
): Promise<{ keystoreJson: string; mnemonic: string }> {
  await initTokenCore();
  const keystoreJson = create_keystore(
    JSON.stringify({
      password,
      network: "MAINNET",
      ...(mnemonic ? { mnemonic: normalizeMnemonic(mnemonic) } : {}),
    })
  );
  const { mnemonic: exported } = JSON.parse(
    export_mnemonic(
      JSON.stringify({
        keystoreJson,
        key: password,
      })
    )
  ) as { mnemonic: string };
  return { keystoreJson, mnemonic: exported };
}

export async function importWalletKeystore(
  password: string,
  mnemonic: string
): Promise<string> {
  await initTokenCore();
  return create_keystore(
    JSON.stringify({
      password,
      mnemonic: normalizeMnemonic(mnemonic),
      network: "MAINNET",
    })
  );
}

interface DerivedAccount {
  address: string;
  chain?: string;
  derivationPath?: string;
}

/** tcx-wasm returns AccountResponse[] (not { accounts: [] }). */
function parseDerivedAccounts(raw: string): DerivedAccount[] {
  const parsed = JSON.parse(raw) as DerivedAccount[] | { accounts?: DerivedAccount[] };
  if (Array.isArray(parsed)) return parsed;
  if (parsed.accounts?.length) return parsed.accounts;
  throw new Error("derive_accounts: unexpected response shape");
}

export async function deriveEthereumAddress(
  keystoreJson: string,
  password: string,
  chainId = "1"
): Promise<string> {
  await initTokenCore();
  const raw = derive_accounts(
    JSON.stringify({
      keystoreJson,
      key: password,
      derivations: [
        {
          chain: "ETHEREUM",
          derivationPath: "m/44'/60'/0'/0/0",
          chainId,
          network: "MAINNET",
        },
      ],
    })
  );
  const accounts = parseDerivedAccounts(raw);
  const eth =
    accounts.find((a) => a.chain === "ETHEREUM") ?? accounts[0];
  const address = eth?.address;
  if (!address) throw new Error("derive_accounts returned no address");
  return address;
}

export function normalizeMnemonic(phrase: string): string {
  return phrase.trim().toLowerCase().replace(/\s+/g, " ");
}

export function mnemonicToWords(phrase: string): string[] {
  return normalizeMnemonic(phrase).split(" ");
}

export async function validateMnemonicWithCore(
  password: string,
  phrase: string
): Promise<boolean> {
  try {
    await importWalletKeystore(password, phrase);
    return true;
  } catch {
    return false;
  }
}
