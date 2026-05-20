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
