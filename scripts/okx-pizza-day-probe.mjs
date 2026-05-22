#!/usr/bin/env node
/**
 * Probe PizzaDay.claim(bytes32) on X Layer for UID + various btc_last6.
 */
import { createHash } from "node:crypto";

const UID = process.argv[2] || "380013825254106106";
const FROM = process.argv[3] || "0x294539d7413964988a3cbed9e6e1ade88dbbcda5";
const TO = "0x03C1d16a0a13A17F3583f43698CE94fE05900503";
const RPC = "https://rpc.xlayer.tech";

const TXS = [
  ["pay_57043", "a1075db55d416d3ca199f55b6084e2115b9345e16c5cf302fc80e9d5fbf5d48d"],
  ["pay_alt", "a1075c984162ca71956bdce25082826caa2042ff37166c2a1b347da3ccb4367"],
  ["forum_offer", "4a5e1e4baa9f0bcb020b0307eafc0e0c2c6be90c7c41c6004a0a4eb4784b7854"],
  ["demo_guide", "0000000000000000000000000000000000000000000000000000000000000000"],
];

function fullHash(last6) {
  const i = UID + last6.toLowerCase();
  const f = createHash("sha256").update(i, "utf8").digest();
  return createHash("sha256").update(f).digest("hex");
}

async function ethCall(data) {
  const body = {
    jsonrpc: "2.0",
    id: 1,
    method: "eth_call",
    params: [{ from: FROM, to: TO, data }, "latest"],
  };
  const res = await fetch(RPC, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });
  return res.json();
}

for (const [name, txid] of TXS) {
  const last6 = txid.slice(-6).toLowerCase();
  const h = fullHash(last6);
  const data = `0xbd66528a${h}`;
  const out = await ethCall(data);
  const ok = !out.error;
  console.log(
    `${ok ? "OK " : "REV"} ${name} last6=${last6} fullHash=${h.slice(0, 16)}...`,
    ok ? out.result : out.error?.message
  );
}
