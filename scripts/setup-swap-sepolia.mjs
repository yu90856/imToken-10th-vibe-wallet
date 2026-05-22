#!/usr/bin/env node
/**
 * 部署 Sepolia VibeSwapDemo（ETH ↔ vUSDC）→ 寫入 Secrets.plist
 * 需 deployer 有 Sepolia ETH（可與 setup-puffer-sepolia.mjs 共用 SEPOLIA_DEPLOYER_KEY）
 */
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import { ethers } from "ethers";
import solc from "solc";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(__dirname, "..");
const plistPath = path.join(root, "ios/VibeWallet/Config/Secrets.plist");
const sourcePath = path.join(root, "contracts/VibeSwapDemo.sol");
const rpc = process.env.SEPOLIA_RPC || "https://ethereum-sepolia-rpc.publicnode.com";

function readPlist() {
  if (!fs.existsSync(plistPath)) return {};
  const xml = fs.readFileSync(plistPath, "utf8");
  const keys = {};
  const keyRe = /<key>([^<]+)<\/key>\s*<string>([^<]*)<\/string>/g;
  let m;
  while ((m = keyRe.exec(xml))) keys[m[1]] = m[2];
  return keys;
}

function writePlist(entries) {
  const merged = { ...readPlist(), ...entries };
  const lines = [
    `<?xml version="1.0" encoding="UTF-8"?>`,
    `<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">`,
    `<plist version="1.0">`,
    `<dict>`,
  ];
  for (const [k, v] of Object.entries(merged)) {
    lines.push(`\t<key>${k}</key>`, `\t<string>${v}</string>`);
  }
  lines.push(`</dict>`, `</plist>`, ``);
  fs.writeFileSync(plistPath, lines.join("\n"));
  console.log("Updated", plistPath);
}

function compileContract() {
  const source = fs.readFileSync(sourcePath, "utf8");
  const input = {
    language: "Solidity",
    sources: { "VibeSwapDemo.sol": { content: source } },
    settings: {
      optimizer: { enabled: true, runs: 200 },
      outputSelection: { "*": { "*": ["abi", "evm.bytecode.object"] } },
    },
  };
  const output = JSON.parse(solc.compile(JSON.stringify(input)));
  for (const e of output.errors || []) {
    if (e.severity === "error") throw new Error(e.formattedMessage || e.message);
  }
  const c = output.contracts["VibeSwapDemo.sol"].VibeSwapDemo;
  return { abi: c.abi, bytecode: "0x" + c.evm.bytecode.object };
}

async function main() {
  const existing = readPlist();
  const deployerKey =
    process.env.SEPOLIA_DEPLOYER_KEY ||
    existing.SEPOLIA_DEPLOYER_KEY ||
    "";

  if (!deployerKey || deployerKey.length < 64) {
    console.error("Set SEPOLIA_DEPLOYER_KEY or run setup-puffer-sepolia.mjs first.");
    process.exit(1);
  }

  const provider = new ethers.JsonRpcProvider(rpc);
  const wallet = new ethers.Wallet(deployerKey, provider);
  console.log("Deployer:", wallet.address);

  const balance = await provider.getBalance(wallet.address);
  console.log("Balance:", ethers.formatEther(balance), "ETH");
  if (balance < ethers.parseEther("0.01")) {
    console.error("Need Sepolia ETH on deployer. Fund then re-run.");
    process.exit(2);
  }

  const { abi, bytecode } = compileContract();
  const factory = new ethers.ContractFactory(abi, bytecode, wallet);
  console.log("Deploying VibeSwapDemo…");
  const contract = await factory.deploy();
  await contract.waitForDeployment();
  const address = await contract.getAddress();
  console.log("Swap demo deployed:", address);

  writePlist({ SEPOLIA_SWAP_DEMO: address });
  console.log("\nDone. Rebuild VibeWallet — 交換 tab 可測 ETH ↔ vUSDC。");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
