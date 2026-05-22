# Puffer SDK 鏈別與 Vibe 演示策略

## 官方 `@pufferfinance/puffer-sdk`（實測 v1.31.0）

| 鏈 | chain id | GaugeRegistry | PufferVault | PufferDepositor | pufETH |
|----|----------|---------------|-------------|-----------------|--------|
| **Sepolia** | 11155111 | `0x14b25b3a3C1e6032e7Fbf0309d1ef6881e9A8D7A` | **MISSING** | **MISSING** | **MISSING** |
| **Holesky** | 17000 | （見 SDK） | `0x9196830bB4c05504E0A8475A0aD566AceEB6BeC9` | `0x824AC05aeb86A0aD770b8acDe0906d2d4a6c4A8c` | `0x9196830bB4c05504E0A8475A0aD566AceEB6BeC9` |

結論（與 [Puffer SDK Getting Started](https://docs.puffer.fi/) / [Puffer Docs](https://docs.puffer.fi/) 一致）：

- **ETH → pufETH** 須呼叫 **`PufferVault.depositETH(...)`**。
- SDK quick start 使用 **`Chain.Holesky`**，Sepolia enum 存在但 **沒有** 官方 Vault / Depositor / pufETH 地址。
- 在官方補齊 Sepolia 合約或 SDK 更新前，**不應假裝**「Sepolia 上已接官方 Puffer staking」。

## Vibe Wallet 目前做法（刻意與 SDK 分開）

本 App **未** 嵌入 `puffer-sdk`，黑客松 Sepolia 路徑為：

1. **鏈**：與全 App 一致，使用 **Ethereum Sepolia**（`ChainConfig.usesTestnet`）。
2. **合約**：自建 **`VibePufferDemoVault`**（`contracts/VibePufferDemoVault.sol`），模擬「存 ETH → 鑄 pufETH → withdraw」流程，地址寫入 `PUFFER_SEPOLIA_VAULT`。
3. **匯率 UI**：Puffer Hackathon API（`api-v2.puffer.fi/imtoken-hackathon`），僅供展示；鏈上比例以演示 Vault 的 `exchangeRateWei` 為準。
4. **賽道敘事**：Sepolia 上展示 **可簽名、可 Etherscan 查詢** 的質押／解質押；**不是** 官方 `PufferVault.depositETH`。

## 若未來要接「真」官方 staking

1. 切換或新增 **Holesky** 測試網配置（與現有 Sepolia 演示並存或取代）。
2. 使用 SDK 提供的 **Holesky** `PufferVault` / `PufferDepositor` / `pufETH` 地址組 calldata（或等官方發布 Sepolia 地址後再評估）。
3. 更新整合檢測與 UI 文案，明確標示「官方 PufferVault」vs「Vibe 演示 Vault」。

## 參考

- Puffer SDK Getting Started — `Chain.Holesky` + `depositETH`
- 本倉 `ios/docs/PUFFER_SEPOLIA.md` — 演示 Vault 部署步驟
