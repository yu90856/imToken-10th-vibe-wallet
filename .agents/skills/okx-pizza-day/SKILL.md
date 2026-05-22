---
name: okx-pizza-day
description: "OKX Pizza Day on X Layer: Agentic Wallet setup, BTC pizza tx last-6 lookup, doubleSHA256 (OKX_UID||btc_last6), and PizzaDay.claim(bytes32) on 0x03C1d16a0a13A17F3583f43698CE94fE05900503. Triggers: pizza day, 披萨, PizzaDay, claim pizza, OKX 披萨活动, onchainos pizza, X Layer 披萨."
license: MIT
metadata:
  author: vibe-wallet
  version: "1.0.0"
  homepage: "https://web3.okx.com/zh-hans/onchainos/pizza-day/agent-guide"
---

# OKX Pizza Day (X Layer)

End-to-end flow for [OKX Pizza Day Agent Guide](https://web3.okx.com/zh-hans/onchainos/pizza-day/agent-guide).

## Instruction priority

1. **`<NEVER>`** — Use Vibe Wallet iOS mnemonic / Sepolia wallet / user's main EOA for this campaign.
2. **`<MUST>`** — Use **OKX Agentic Wallet** only; prefer a **new empty** account on **X Layer mainnet** (`xlayer`, chain id `196`).
3. **`<MUST>`** — User must have **OKX KYC completed** before claim; `fullHash` includes their numeric OKX UID.

## Dependencies (read before running commands)

| Step | Skill / doc |
|------|-------------|
| CLI install + version | `okx-agentic-wallet` → `_shared/preflight.md` |
| Login, new account, switch chain | `okx-agentic-wallet` |
| Optional tx scan | `okx-security` |
| Contract call + broadcast | `okx-agentic-wallet` (`wallet contract-call`) |
| Order / confirmation | `okx-onchain-gateway` (`gateway orders`) if needed |

Project helpers: `docs/OKX_PIZZA_DAY.md`, `scripts/okx-pizza-day-hash.mjs`.

## Constants

| Field | Value |
|-------|--------|
| PizzaDay contract | `0x03C1d16a0a13A17F3583f43698CE94fE05900503` |
| Chain | `xlayer` (196) |
| `claim(bytes32)` selector | `0xbd66528a` |
| BTC pizza payment tx (2010-05-22) | `a1075db55d416d3ca199f55b6084e2115b9345e16c5cf302fc80e9d5fbf5d48d` |
| BTC hash **last 6** (lowercase hex) | `f5d48d` |

## Flow

### 0. Preflight

<MUST>
Run `okx-agentic-wallet` preflight (install/update `onchainos`). Then `onchainos wallet status`.
</MUST>

### 1. Agentic Wallet on X Layer

If `loggedIn: false` → guide user through **email login** (`onchainos wallet login` / `verify`) per `okx-agentic-wallet`. Do **not** ask for API secrets in chat.

If user already has other Agentic accounts → **add a new empty account**:

```bash
onchainos wallet add
onchainos wallet switch <new_account_id>
```

Show EVM address: `onchainos wallet addresses --chain xlayer`

Confirm network context is X Layer mainnet for the claim (chain `xlayer` on contract-call).

### 2. Local double SHA256 (off-chain)

<MUST>
Ask user for **numeric OKX UID** (KYC account). Never log UID to git or commit messages.

Concatenate UTF-8 string: `OKX_UID + btc_last6` (no separator). Default `btc_last6` = `f5d48d` unless user proved another tx.

Run:

```bash
node scripts/okx-pizza-day-hash.mjs <OKX_UID> [btc_last6]
```

Present `fullHash` (64 hex) and `claim calldata` to user. Explain this is **not** the final credential yet.

Formula (if computing manually): `fullHash = SHA256(SHA256(utf8(UID || last6)))` as 64-char hex.

### 3. On-chain claim (credential = this tx hash)

Build calldata: `0xbd66528a` + `fullHash` (32 bytes, no extra padding).

<MUST>
Run security scan before broadcast:

```bash
onchainos security tx-scan --chain xlayer --to 0x03C1d16a0a13A17F3583f43698CE94fE05900503 --input-data <calldata> --from <evm_address>
```

Then contract call (Gas Station / Paymaster on X Layer — no user gas needed):

```bash
onchainos wallet contract-call \
  --to 0x03C1d16a0a13A17F3583f43698CE94fE05900503 \
  --chain xlayer \
  --input-data <calldata> \
  --from <evm_address> \
  --amt 0
```

On success, output **`txHash`** clearly — user must paste **this** hash into the Pizza Day web form within 10 minutes and complete UID + address binding.

If revert: wrong UID/last6/KYC mismatch — recompute `fullHash` and retry (failed claim does not consume slot per FAQ).

### 4. Post-claim

- Link explorer: `https://www.okx.com/explorer/xlayer/tx/<txHash>` (or OKX Web3 explorer for X Layer).
- Remind: prize redemption needs KYC UID + registered email; delivery CN/HK only.

## Acceptance criteria

1. New or dedicated empty Agentic Wallet used; not Vibe app wallet.
2. `fullHash` computed locally from user UID + `f5d48d` (or user-verified last6).
3. Successful `claim` on X Layer; user has copy-pasteable **claim tx hash**.
4. No secrets / UID committed to repository.
