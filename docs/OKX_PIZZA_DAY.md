# OKX Pizza Day（X Layer）— Agent 參與指南

活動頁：[OKX Pizza Day Agent Guide](https://web3.okx.com/zh-hans/onchainos/pizza-day/agent-guide)

## 本倉庫已就緒

| 項目 | 路徑 / 說明 |
|------|-------------|
| OnChainOS Skills（22 個） | `.agents/skills/okx-*` |
| 鎖定版本 | `skills-lock.json` |
| Pizza Day 專用 Skill | `.agents/skills/okx-pizza-day/SKILL.md` |
| 本地双哈希腳本 | `scripts/okx-pizza-day-hash.mjs` |
| CLI | `onchainos`（`~/.local/bin`，安裝腳本見 onchainos-skills） |

**重要**：必須用 **OKX Agentic Wallet 空錢包**，不要用 Vibe Wallet iOS 裡的主錢包或助記詞錢包。

## 快速開始（對 Cursor Agent 說）

```
幫我完成 OKX Pizza Day：裝好 OnChainOS、用 Agentic Wallet 新建空錢包並切到 X Layer 主網，然後走 claim 流程。
```

Agent 應讀取並執行 `.agents/skills/okx-pizza-day/SKILL.md`，並依賴 `okx-agentic-wallet`、`okx-onchain-gateway`。

## 第三步：BTC 披萨交易 hash 末 6 位

2010-05-22 Laszlo 用 10,000 BTC 買兩個披萨的鏈上付款（OKX 學習文章與區塊瀏覽器一致）：

- **完整 hash**：`a1075db55d416d3ca199f55b6084e2115b9345e16c5cf302fc80e9d5fbf5d48d`
- **末 6 位**：`f5d48d`

瀏覽器：[bitcoinexplorer.org 該筆 tx](https://bitcoinexplorer.org/tx/a1075db55d416d3ca199f55b6084e2115b9345e16c5cf302fc80e9d5fbf5d48d@57043)

## 第四步：双哈希 + 鏈上 claim

1. 準備 **已完成 KYC** 的歐易 UID（純數字）。
2. 本地計算（勿把 UID 提交到 Git）：

```bash
node scripts/okx-pizza-day-hash.mjs <你的OKX_UID>
# 可覆寫末六位：node scripts/okx-pizza-day-hash.mjs <UID> f5d48d
```

3. 用 Agentic Wallet 在 X Layer 調用合約 `0x03C1d16a0a13A17F3583f43698CE94fE05900503` 的 `claim(bytes32)`（gas 由 X Layer Paymaster / Gas Station 代付）。
4. 把 **claim 那筆交易的 tx hash**（`0x` + 64 hex）貼到活動頁表單；前 50 名以服務器校驗通過時間為準。

## API Key（可選）

沙盒內建 key 可能被限流。生產建議在 [OKX Developer Portal](https://web3.okx.com/onchain-os/dev-portal) 申請，並在專案根目錄 `.env` 設定（已在 `.gitignore`）：

```bash
OKX_API_KEY="..."
OKX_SECRET_KEY="..."
OKX_PASSPHRASE="..."
```

## 與 Vibe Wallet iOS 的關係

iOS 應用目前預設 **Sepolia 測試網**（`ChainConfig.usesTestnet`），與本活動的 **X Layer 主網 + Agentic Wallet** 無關。參與 Pizza Day 請只用本指南與 `onchainos` CLI，不要混用 App 內錢包簽名。
