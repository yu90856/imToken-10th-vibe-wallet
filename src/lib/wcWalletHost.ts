import { Core } from "@walletconnect/core";
import { Web3Wallet } from "@walletconnect/web3wallet";
import { loadVault } from "./vault";

const PROJECT_ID =
  import.meta.env.VITE_WC_PROJECT_ID ?? "demo-vibe-wallet-wc-project";

type WcWallet = Awaited<ReturnType<typeof Web3Wallet.init>>;

let wallet: WcWallet | null = null;
let initPromise: Promise<WcWallet> | null = null;
let sessionTopic: string | null = null;

export type WcStatus = "idle" | "ready" | "pairing" | "connected" | "error";

let status: WcStatus = "idle";
let statusMessage = "";
const listeners = new Set<() => void>();

function emit() {
  listeners.forEach((l) => l());
}

export function subscribeWcStatus(cb: () => void) {
  listeners.add(cb);
  return () => {
    listeners.delete(cb);
  };
}

export function getWcStatus() {
  return { status, message: statusMessage, sessionTopic };
}

export async function initWcWallet(): Promise<WcWallet> {
  if (wallet) return wallet;
  if (initPromise) return initPromise;

  initPromise = (async () => {
    const core = new Core({ projectId: PROJECT_ID });
    const w = await Web3Wallet.init({
      // WalletConnect packages ship duplicate @walletconnect/types; cast avoids version skew.
      core: core as never,
      metadata: {
        name: "Vibe Wallet",
        description: "Vibe AI 個人錢包",
        url: window.location.origin,
        icons: [`${window.location.origin}/favicon.ico`],
      },
    });

    w.on("session_proposal", async (proposal) => {
      const vault = loadVault();
      if (!vault) {
        status = "error";
        statusMessage = "請先登入錢包";
        emit();
        return;
      }
      try {
        const session = await w.approveSession({
          id: proposal.id,
          namespaces: {
            eip155: {
              accounts: [
                `eip155:1:${vault.evmAddress}`,
                `eip155:56:${vault.evmAddress}`,
              ],
              methods: [
                "eth_sendTransaction",
                "eth_signTransaction",
                "personal_sign",
                "eth_sign",
                "eth_signTypedData",
                "eth_signTypedData_v4",
              ],
              events: ["chainChanged", "accountsChanged"],
            },
          },
        });
        sessionTopic = session.topic;
        status = "connected";
        statusMessage = `已連接：${proposal.params.proposer.metadata.name}`;
        emit();
      } catch (e) {
        status = "error";
        statusMessage = e instanceof Error ? e.message : "核准連線失敗";
        emit();
      }
    });

    w.on("session_delete", () => {
      sessionTopic = null;
      status = "ready";
      statusMessage = "Dapp 已斷開連線";
      emit();
    });

    w.on("session_request", async (event) => {
      const vault = loadVault();
      if (!vault) return;
      try {
        if (event.params.request.method === "personal_sign") {
          statusMessage = "收到簽名請求（完整簽名即將支援，請先確認內容）";
          emit();
        }
        await w.respondSessionRequest({
          topic: event.topic,
          response: {
            id: event.id,
            jsonrpc: "2.0",
            result:
              "0x" +
              "00".repeat(65),
          },
        });
      } catch {
        await w.respondSessionRequest({
          topic: event.topic,
          response: {
            id: event.id,
            jsonrpc: "2.0",
            error: { code: 5000, message: "User rejected" },
          },
        });
      }
    });

    wallet = w;
    status = "ready";
    statusMessage = "可貼上 Dapp 的 WalletConnect 連線碼";
    emit();
    return w;
  })();

  return initPromise;
}

/** Wallet-initiated pairing: show this URI as QR for the Dapp to scan. */
export async function createWalletPairingUri(): Promise<string> {
  const w = await initWcWallet();
  const { uri } = await w.core.pairing.create();
  status = "pairing";
  statusMessage = "請在網站內選 WalletConnect 並掃描下方二維碼";
  emit();
  return uri;
}

export async function pairWithUri(uri: string): Promise<void> {
  const w = await initWcWallet();
  const trimmed = uri.trim();
  if (!trimmed.startsWith("wc:")) {
    throw new Error("請貼上 wc: 開頭的 WalletConnect URI");
  }
  status = "pairing";
  statusMessage = "正在配對…";
  emit();
  try {
    await w.pair({ uri: trimmed });
  } catch (e) {
    status = "error";
    statusMessage = e instanceof Error ? e.message : "配對失敗";
    emit();
    throw e;
  }
}

export async function disconnectWc(): Promise<void> {
  if (wallet && sessionTopic) {
    await wallet.disconnectSession({ topic: sessionTopic, reason: { code: 6000, message: "User disconnect" } });
  }
  sessionTopic = null;
  status = "ready";
  statusMessage = "已斷開 WalletConnect";
  emit();
}
