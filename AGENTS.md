# Vibe Wallet — Agent Instructions

## Security Skill（參賽必讀）

在處理助記詞、私鑰、簽名、授權、DApp 互動或風險相關 UI 之前，請閱讀並遵守：

`./security/SKILL.md`

（來源：[token-ui/security](https://github.com/consenlabs/token-ui/tree/main/security)）

## UI Kit

- 設計規範見 `vendor/token-ui/DESIGN.md`
- 元件自 `@repo/ui/components/*` 匯入
- 全域樣式於 `src/main.tsx` 引入 token-ui `globals.css`

## 錢包核心

- 使用 `@consenlabs/tcx-wasm`（[token-core-monorepo](https://github.com/consenlabs/token-core-monorepo)）
- 封裝於 `src/lib/tokenCore.ts`

## OKX Pizza Day（X Layer 活動）

參與 [OKX Pizza Day Agent 指南](https://web3.okx.com/zh-hans/onchainos/pizza-day/agent-guide) 時：

1. **必讀 Skill**：`.agents/skills/okx-pizza-day/SKILL.md`（並依賴已安裝的 `okx-agentic-wallet`、`okx-onchain-gateway`）
2. **勿用** Vibe iOS 錢包 / 助記詞；只用 **OKX Agentic Wallet 空錢包** + `onchainos` CLI
3. 人類可讀說明：`docs/OKX_PIZZA_DAY.md`；本地双哈希：`node scripts/okx-pizza-day-hash.mjs <OKX_UID>`
4. OnChainOS Skills 安裝：`npx skills add okx/onchainos-skills --agent cursor -y`（已執行則見 `skills-lock.json`）
