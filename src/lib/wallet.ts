import { Wallet } from "ethers";

/** 私鑰導入 fallback（Token Core 以助記詞 keystore 為主） */
export function addressFromPrivateKey(privateKey: string): string {
  const key = privateKey.startsWith("0x") ? privateKey : `0x${privateKey}`;
  return new Wallet(key).address;
}

export function externalPrivateKeyKeystore(privateKey: string): string {
  return JSON.stringify({ type: "externalPrivateKey", key: privateKey });
}
