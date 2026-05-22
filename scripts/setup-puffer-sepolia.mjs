#!/usr/bin/env node
/**
 * 一鍵：生成/使用 Sepolia 部署錢包 → 嘗試領水 → 部署 Vault → 寫入 Secrets.plist
 */
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import { ethers } from "ethers";
import solc from "solc";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(__dirname, "..");
const plistPath = path.join(root, "ios/VibeWallet/Config/Secrets.plist");
const sourcePath = path.join(root, "contracts/VibePufferDemoVault.sol");
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
    sources: { "VibePufferDemoVault.sol": { content: source } },
    settings: {
      optimizer: { enabled: true, runs: 200 },
      outputSelection: { "*": { "*": ["abi", "evm.bytecode.object"] } },
    },
  };
  const output = JSON.parse(solc.compile(JSON.stringify(input)));
  for (const e of output.errors || []) {
    if (e.severity === "error") throw new Error(e.formattedMessage || e.message);
  }
  const c = output.contracts["VibePufferDemoVault.sol"].VibePufferDemoVault;
  return { abi: c.abi, bytecode: "0x" + c.evm.bytecode.object };
}

async function tryChainlinkFaucet(address) {
  try {
    const res = await fetch("https://faucets.chain.link/sepolia", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ address, chain: "sepolia" }),
    });
    if (res.ok) return true;
  } catch (_) {}
  return false;
}

async function waitForBalance(provider, address, minWei, timeoutMs = 180_000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const bal = await provider.getBalance(address);
    if (bal >= minWei) return bal;
    await new Promise((r) => setTimeout(r, 8000));
  }
  return await provider.getBalance(address);
}

async function main() {
  const existing = readPlist();
  let deployerKey =
    process.env.SEPOLIA_DEPLOYER_KEY ||
    existing.SEPOLIA_DEPLOYER_KEY ||
    "";

  if (!deployerKey || deployerKey.length < 64) {
    const w = ethers.Wallet.createRandom();
    deployerKey = w.privateKey;
    console.log("Generated new Sepolia deployer:", w.address);
    writePlist({ SEPOLIA_DEPLOYER_KEY: deployerKey });
  }

  const provider = new ethers.JsonRpcProvider(rpc);
  const wallet = new ethers.Wallet(deployerKey, provider);
  console.log("Deployer:", wallet.address);

  const minDeploy = ethers.parseEther("0.02");
  let balance = await provider.getBalance(wallet.address);
  console.log("Balance:", ethers.formatEther(balance), "ETH");

  if (balance < minDeploy) {
    console.log("Requesting test ETH (Chainlink faucet)…");
    await tryChainlinkFaucet(wallet.address);
    console.log("Waiting for faucet (up to 3 min). If still 0, fund this address via:");
    console.log("  https://faucets.chain.link/sepolia");
    console.log("  https://cloud.google.com/application/web3/faucet/ethereum/sepolia");
    balance = await waitForBalance(provider, wallet.address, minDeploy);
  }

  if (balance < minDeploy) {
    console.error("\nDeployer still has insufficient Sepolia ETH:", wallet.address);
    console.error("Fund the address above, then re-run: node scripts/setup-puffer-sepolia.mjs");
    process.exit(2);
  }

  const { abi, bytecode } = compileContract();
  const factory = new ethers.ContractFactory(abi, bytecode, wallet);
  console.log("Deploying VibePufferDemoVault…");
  const contract = await factory.deploy();
  await contract.waitForDeployment();
  const vault = await contract.getAddress();
  console.log("Vault deployed:", vault);

  writePlist({
    PUFFER_SEPOLIA_VAULT: vault,
    PUFFER_SEPOLIA_DEPLOYER: wallet.address,
  });

  const code = await provider.getCode(vault);
  if (code === "0x") {
    console.error("Warning: no code at vault address");
    process.exit(3);
  }
  console.log("\nDone. Rebuild & run VibeWallet in Xcode.");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
