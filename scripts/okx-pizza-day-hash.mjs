#!/usr/bin/env node
/**
 * OKX Pizza Day — 本地 doubleSHA256（UTF-8 拼接 OKX_UID + btc_hash_last6）
 *
 * 用法：
 *   node scripts/okx-pizza-day-hash.mjs <OKX_UID> [btc_last6]
 *
 * 預設 btc_last6 為 2010-05-22 那筆 10,000 BTC 披萨付款 tx 的 hash 末 6 位（見 docs/OKX_PIZZA_DAY.md）。
 */
import { createHash } from "node:crypto";

const DEFAULT_BTC_LAST6 = "f5d48d";

function doubleSha256Hex(utf8Input) {
  const first = createHash("sha256").update(utf8Input, "utf8").digest();
  const second = createHash("sha256").update(first).digest("hex");
  return second;
}

function claimCalldata(fullHash) {
  const h = fullHash.replace(/^0x/i, "").toLowerCase();
  if (!/^[0-9a-f]{64}$/.test(h)) {
    throw new Error("fullHash must be 64 hex chars");
  }
  return `0xbd66528a${h}`;
}

const okxUid = process.argv[2]?.trim();
const btcLast6 = (process.argv[3]?.trim() || DEFAULT_BTC_LAST6).toLowerCase();

if (!okxUid) {
  console.error("用法: node scripts/okx-pizza-day-hash.mjs <OKX_UID> [btc_hash_last6]");
  process.exit(1);
}

if (!/^\d+$/.test(okxUid)) {
  console.error("OKX UID 應為純數字（歐易 APP 用戶中心）");
  process.exit(1);
}

if (!/^[0-9a-f]{6}$/.test(btcLast6)) {
  console.error("btc_hash_last6 應為 6 位十六進制");
  process.exit(1);
}

const input = `${okxUid}${btcLast6}`;
const fullHash = doubleSha256Hex(input);

console.log("--- OKX Pizza Day 本地双哈希 ---");
console.log("input:", JSON.stringify(input), "(OKX_UID || btc_hash_last6)");
console.log("fullHash:", fullHash, "(bytes32 for claim)");
console.log("claim calldata:", claimCalldata(fullHash));
console.log("contract:", "0x03C1d16a0a13A17F3583f43698CE94fE05900503");
console.log("chain:", "xlayer (196)");
