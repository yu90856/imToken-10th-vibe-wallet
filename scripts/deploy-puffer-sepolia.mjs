#!/usr/bin/env node
/**
 * 可選：用環境變數 SEPOLIA_RPC、SEPOLIA_DEPLOYER_KEY 部署 VibePufferDemoVault
 * 需先: npm install ethers solc
 * 部署後把地址寫入 ios/VibeWallet/Config/Secrets.plist → PUFFER_SEPOLIA_VAULT
 */
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import { ethers } from "ethers";
import solc from "solc";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(__dirname, "..");
const sourcePath = path.join(root, "contracts/VibePufferDemoVault.sol");

const rpc = process.env.SEPOLIA_RPC || "https://ethereum-sepolia-rpc.publicnode.com";
const key = process.env.SEPOLIA_DEPLOYER_KEY;

if (!key) {
  console.error("Set SEPOLIA_DEPLOYER_KEY (hex private key, test wallet only).");
  process.exit(1);
}

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
const errors = (output.errors || []).filter((e) => e.severity === "error");
if (errors.length) {
  console.error(errors);
  process.exit(1);
}
const contract = output.contracts["VibePufferDemoVault.sol"].VibePufferDemoVault;
const abi = contract.abi;
const bytecode = "0x" + contract.evm.bytecode.object;

const provider = new ethers.JsonRpcProvider(rpc);
const wallet = new ethers.Wallet(key, provider);
const factory = new ethers.ContractFactory(abi, bytecode, wallet);

console.log("Deploying from", wallet.address, "to Sepolia...");
const deployed = await factory.deploy();
await deployed.waitForDeployment();
const addr = await deployed.getAddress();
console.log("VibePufferDemoVault:", addr);
console.log("\nAdd to Secrets.plist:\n  PUFFER_SEPOLIA_VAULT =", addr);
