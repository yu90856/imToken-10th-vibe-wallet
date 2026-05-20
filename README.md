# Vibe Wallet — AI 個人錢包

非託管 Web 錢包原型，涵蓋首次使用的完整 onboarding 流程。

## 功能

- **創建錢包**：名稱、密碼、選填密碼提示
- **選擇鏈**：熱門 5 鏈橫幅 + Layer 1 / Layer 2 / EVM 分類（熱門鏈在分類中仍會顯示）
- **備份助記詞**：安全說明、立即備份 / 稍後再說
- **立即備份**：防截圖彈窗 → 馬賽克遮蔽 → 顯示 → 確認 → 順序驗證
- **導入錢包**：助記詞或私鑰 + 選鏈

助記詞以 PBKDF2 + AES-GCM 加密後存於 `localStorage`（僅供原型，正式產品請使用更安全的儲存方案）。

## 開發

```bash
npm install
npm run dev
```

瀏覽器開啟終端顯示的本地網址（通常為 `http://localhost:5173`）。

```bash
npm run build
```

## 參賽整合（imToken 共創）

| 資源 | 用途 |
|------|------|
| [@consenlabs/tcx-wasm](https://github.com/consenlabs/token-core-monorepo) | 錢包 keystore、助記詞、EVM 地址派生 |
| [token-ui](https://github.com/consenlabs/token-ui) | imToken Design System（`vendor/token-ui`） |
| [security/SKILL.md](https://github.com/consenlabs/token-ui/tree/main/security) | 助記詞／簽名／風險 UI 安全規範（`./security/`） |

詳見 `AGENTS.md`。

## 技術棧

- React 19 + TypeScript + Vite + Tailwind（token-ui）
- React Router、Zustand
- `@consenlabs/tcx-wasm`（Token Core）
- `ethers`（僅私鑰導入地址推導）

## iOS 原生（SwiftUI）

見 [`ios/README.md`](ios/README.md)。SwiftUI 原生 App，**錢包建立／匯入已接入 Token Core（tcx-wasm）**，與 Web 版 `src/lib/tokenCore.ts` 相同 WASM；行情／資產仍為 Mock。

```bash
open ios/VibeWallet.xcodeproj
```

## 後續可擴展

- AI 助理（轉帳建議、風險提示）
- 多鏈非 EVM 地址派生（Solana、Bitcoin）
- 硬體錢包、生物辨識解鎖
- Token Core 原生橋接（iOS Secure Enclave）
