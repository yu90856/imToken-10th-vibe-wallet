#!/usr/bin/env node
/**
 * 從助記詞導出 Sepolia 部署用地址與私鑰（僅本機、勿提交 Git）
 *
 * 用法（不要把助記詞寫進命令列歷史）：
 *   export MNEMONIC="word1 word2 ... word12"
 *   node scripts/export-sepolia-deployer-from-mnemonic.mjs
 *
 * 然後：
 *   export SEPOLIA_DEPLOYER_KEY=<輸出的私鑰>
 *   node scripts/setup-puffer-sepolia.mjs
 */
import { ethers } from "ethers";

const phrase = process.env.MNEMONIC?.trim().replace(/\s+/g, " ");
if (!phrase) {
  console.error("請設定環境變數 MNEMONIC（12/24 個英文單詞，空格分隔）");
  process.exit(1);
}

// 與 App ChainConfig.active.derivationPath 一致：m/44'/60'/0'/0/0
const path = "m/44'/60'/0'/0/0";
const wallet = ethers.HDNodeWallet.fromPhrase(phrase, undefined, path);

console.log("--- 僅供本機部署 Sepolia 演示合約 ---");
console.log("地址:", wallet.address);
console.log("私鑰:", wallet.privateKey);
console.log("");
console.log("下一步:");
console.log("  export SEPOLIA_DEPLOYER_KEY=" + wallet.privateKey);
console.log("  node scripts/setup-puffer-sepolia.mjs");
