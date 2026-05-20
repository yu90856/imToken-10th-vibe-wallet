# Risk Control Materials for imToken 10th Anniversary Co-Creation Activity

This folder contains three security materials to support the **AI Wallet Co-Creation Activity**.

They are designed to work alongside the `token-ui` frontend template and the Token Core CLI,
helping participants build wallets that are not just functional, but genuinely secure.

---

## Files in This Package

| File | Audience | Purpose |
|------|----------|---------|
| `SKILL.md` | AI Agent | Security knowledge base the agent applies when helping users build wallet features |
| `wallet-security-handbook.md` | Co-creation participants | Bilingual reference covering real attack scenarios, design principles, and a dev checklist |
| `README.md` | Co-creation participants | This file — how to use everything together |

---

## How These Materials Fit Into Your Workflow

```
token-ui repo                      Token Core CLI
  ├── AGENTS.md  ─────────┐          ├── analyze
  ├── CLAUDE.md  ─────────┤          ├── sign
  └── DESIGN.md           │          ├── broadcast
                          │          └── src/policies/
                          │
           ┌──────────────▼──────────────────────┐
           │            AI Agent                  │
           │   reads SKILL.md on every            │
           │   security-sensitive interaction      │
           └──────────────┬──────────────────────┘
                          │
           ┌──────────────▼──────────────────────┐
           │      Your wallet co-creation          │
           │      project                          │
           │                                       │
           │  Reference wallet-security-           │
           │  handbook.md while designing          │
           └───────────────────────────────────────┘
```

---

## Quick Start

### 1. Give the AI Agent Access to `SKILL.md`

The agent needs to see `SKILL.md` to apply security reasoning and use correct UI conventions
when generating wallet code. Add it to your agent context in one of these ways:

**Option A — In `AGENTS.md` or `CLAUDE.md` (recommended for token-ui projects)**

Add to the bottom of your `token-ui` project's `AGENTS.md` or `CLAUDE.md`:

```markdown
## Security Skill

Before generating any code that involves mnemonic phrases, private keys, transaction signing,
token approvals, DApp interaction, or risk-related UI components, read and apply:

@./risk-control/SKILL.md
```

Then place `SKILL.md` at `<your-project>/risk-control/SKILL.md`.

**Option B — As a system prompt prefix**

Paste the full content of `SKILL.md` at the top of your AI session's system prompt before
starting the co-creation session.

**Option C — Reference at conversation start**

At the start of a co-creation session, paste the content of `SKILL.md` into the chat and say:
> "This is a security skill. Apply it whenever I ask you to build wallet features."

---

### 2. Use the Security Handbook While Designing

`wallet-security-handbook.md` is your design-time reference. You do not need to read it
top to bottom — jump to the section relevant to the feature you are currently building:

| Building this feature | Read this section |
|----------------------|-------------------|
| Mnemonic generation or import | Section 2 (threat overview) + Section 3.1 |
| Transaction signing flow | Section 2.1, 2.2 + Section 3.2 |
| Transaction history display | Section 2.3 + Section 3.3 |
| DApp interaction or contract calls | Section 2.1, 2.4, 2.5 + Section 3.4 |
| Warning banners or confirmation modals | Section 3.5 |
| Preparing your submission safety statement | Section 5 |

---

### 3. Run Token Core CLI Policy Checks

Before implementing a sign or approve flow, test it against the Token Core CLI to understand
what the policy engine will flag:

```bash
npm run cli -- analyze --chain eth-sepolia \
  --input '{"chainId":11155111,"account":"0xYOUR_ADDR","to":"0xCONTRACT","data":"0x...","value":"0"}' \
  --policy ./src/policies/default-risk-policy.json
```

Map the output to your wallet's risk UI using the table in **Handbook Section 4.3**.

---

### 4. Self-Review Before Submission

Run through the **Developer Security Design Checklist** in `wallet-security-handbook.md`
Section 3 before submitting. Then use **Section 5** to draft the safety statement required
in your submission form.

---

## Activity Safety Reminder

> ⚠️ **Do not use your real mnemonic phrase in any demo, AI session, or public recording.**
>
> Create a dedicated wallet with testnet assets for all co-creation work.
> If your submission involves mainnet, use only a small, disposable amount.
> Your submission must include a safety statement — see **Handbook Section 5** for a template.

---

## Related Links

| Resource | URL |
|----------|-----|
| Token Core CLI README | https://github.com/consenlabs/token-core-monorepo/blob/demo/token-core-cli/token-core/tcx-examples/cli/README.md |
| Activity rules & submission page | imToken 10th Anniversary Co-Creation Page |
| Discord community | Official Activity Discord Group |
| Sepolia testnet faucet | https://sepolia-faucet.pk910.de/ |
| Circle testnet USDC faucet | https://faucet.circle.com/ |
