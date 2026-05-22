# Puffer · Sepolia 鏈上測試

> **官方 SDK**：`@pufferfinance/puffer-sdk` 在 Sepolia **沒有** `PufferVault` / `pufETH` 地址；真實 `depositETH` 須用 **Holesky**。本頁是 **Vibe 自建演示合約**，不是官方 Sepolia staking。詳見 [PUFFER_SDK_CHAINS.md](./PUFFER_SDK_CHAINS.md)。

## 1. 部署演示合約（一次性）

1. 打開 [Remix](https://remix.ethereum.org)
2. 新建檔案 `VibePufferDemoVault.sol`，貼上倉庫 `contracts/VibePufferDemoVault.sol` 內容
3. 編譯器 **0.8.20+**，編譯
4. **Deploy & Run** → Environment: **Injected Provider** 或 **WalletConnect**，網路選 **Sepolia**
5. 部署 `VibePufferDemoVault`，複製合約地址

## 1b. 只有助記詞、要跑腳本部署？

助記詞可推導出**同一個**以太坊地址的私鑰（路徑與 App 一致：`m/44'/60'/0'/0/0`）。

**請只在 Mac 本機執行，勿把助記詞貼到聊天、Git 或公開網站。**

```bash
cd /Users/viola/Desktop/Vibe

# 把 12 個詞貼進引號（不要 commit、不要截圖上傳）
export MNEMONIC="你的 twelve words 助記詞"

node scripts/export-sepolia-deployer-from-mnemonic.mjs
```

終端會印出 **地址** 和 **私鑰**。接著：

```bash
export SEPOLIA_DEPLOYER_KEY=0x上一步印出的私鑰
node scripts/setup-puffer-sepolia.mjs
```

也可用 MetaMask：匯入助記詞 → 帳戶詳情 → 匯出私鑰（僅測試錢包）。

> 若這組助記詞曾用於**真實資產**，請改用**全新測試助記詞**做黑客松演示。

## 2. 寫入 App

```bash
cp ios/VibeWallet/Config/Secrets.plist.example ios/VibeWallet/Config/Secrets.plist
```

將 `PUFFER_SEPOLIA_VAULT` 改為你的 Sepolia 合約地址（`0x` 開頭 42 字元）。

或在 Xcode 中編輯 `Secrets.plist`（已在 `.gitignore`）。

## 3. 領水與測試

1. 探索頁領 **Sepolia ETH**（Google / Chainlink Faucet）
2. **Puffer 質押** → 輸入數量（需 ≤ 餘額 − 0.002 ETH Gas 預留）
3. 確認後輸入**錢包密碼**（建立錢包時設定的密碼）完成簽名
4. 在 [Sepolia Etherscan](https://sepolia.etherscan.io) 查看交易與 `balanceOf` 的 pufETH
5. **解質押**：有 pufETH 餘額時，在「解質押」區塊輸入數量（或點「全部」）→ 確認解質押

## 解質押與舊 Vault

若提示「不支援解質押」，代表 `PUFFER_SEPOLIA_VAULT` 為舊版（僅 `deposit`）。請用最新 `contracts/VibePufferDemoVault.sol` **重新部署**到 Sepolia，更新 `Secrets.plist` 後再操作。

## 說明

- 此合約為 **VibePufferDemoVault（演示）**，邏輯對齊「存 ETH → 鑄 pufETH → withdraw 贖回 ETH」。
- **不是** 官方 `PufferVault.depositETH`；Sepolia 上 SDK 亦無官方 Vault 地址（僅 GaugeRegistry）。
- 若要接官方 SDK 質押，需 **Holesky** 或等 Puffer 公布 Sepolia Vault 後再整合。
- Puffer Hackathon API 匯率僅供 UI 參考；鏈上鑄造比例由 `exchangeRateWei` 決定（預設 1 ETH = 1 pufETH）。
