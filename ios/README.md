# Vibe Wallet — iOS 原生

主打「最佳使用者掌控」的非託管錢包（SwiftUI）。

**黑客松預設：Ethereum Sepolia（chainId 11155111）** — 首頁／資產會讀取鏈上 **Sepolia ETH**；行情／交換為示範 UI。

## 開啟專案

```bash
open ios/VibeWallet.xcodeproj
```

首次啟動若無本機 keystore → **建立／匯入錢包**（Token Core + Sepolia 地址）。

## API 金鑰（勿提交 Git）

公開倉庫**不含** `Config/Secrets.plist`（已在 `.gitignore`）。Clone 後若需 Bitrefill 搜尋等，請在本機自行建立：

```bash
cp ios/VibeWallet/Config/Secrets.plist.example ios/VibeWallet/Config/Secrets.plist
```

填入 `BITREFILL_API_KEY` 等（見 example 註解）。**Sepolia Puffer 演示質押**走鏈上 `VibePufferDemoVault`，不依賴 Bitrefill API。

## 實機閃退除錯

請用 **USB + Xcode Run** 查看 Console 日誌，步驟見 [DEVICE_DEBUG.md](DEVICE_DEBUG.md)。

## 安裝到 iPhone 實機

需求：**iPhone（iOS 17+）**、**Mac + Xcode**、**Apple ID**（免費帳號即可開發者模式安裝，每 7 天需重新簽一次）。

### 1. 準備專案

在專案根目錄執行（確保 WASM 在 App 內）：

```bash
npm install
./ios/scripts/sync-token-core-ios.sh
open ios/VibeWallet.xcodeproj
```

### 2. 簽署（Signing）

1. 左側選 **VibeWallet** 專案 → **TARGETS** → **VibeWallet** → **Signing & Capabilities**
2. 勾選 **Automatically manage signing**
3. **Team** 選你的 Apple ID（Personal Team）
4. 若 Bundle Identifier `com.vibe.wallet` 與別人衝突，改成唯一值，例如 `com.你的名字.vibewallet`

### 3. 連接 iPhone

1. USB 連接手機，解鎖並在 iPhone 點 **信任此電腦**
2. Xcode 上方執行目標從模擬器改為 **你的 iPhone 名稱**
3. 按 **Run（▶）** 編譯並安裝

第一次可能出現 **「無法驗證開發者」**：

- iPhone：**設定 → 一般 → VPN 與裝置管理** → 點你的開發者帳號 → **信任**

iOS 16+ 若提示開發者模式：

- **設定 → 隱私權與安全性 → 開發者模式** → 開啟並重開機

### 4. 實機試用建議

| 項目 | 說明 |
|------|------|
| Face ID | 實機在 **設定** 內開啟 Face ID，無需模擬器 Enrolled |
| 測試網 | 預設 **Sepolia**，到探索／錢包頁領水後下拉首頁重新整理 |
| 脅迫防護 | 開 Face ID + 脅迫防護後，背景再開 App 會鎖定；秘密手勢：交換→交換→錢包→錢包 |
| 免費帳號 | App 約 **7 天**後需用 Xcode 再 Run 一次重新安裝 |

### 5. Sideloadly 安裝（IPA）

已建置未簽名 IPA 時路徑為：

`ios/build/VibeWallet.ipa`

自行重打包：

```bash
./ios/scripts/build-ipa.sh
```

Sideloadly 步驟：

1. 安裝 [Sideloadly](https://sideloadly.io/)，USB 連接 iPhone  
2. 拖入 `VibeWallet.ipa`，登入你的 **Apple ID**（由 Sideloadly 代簽）  
3. 安裝後：**設定 → 一般 → VPN 與裝置管理** → 信任  
4. 免費帳號約 **7 天** 需重新用 Sideloadly 安裝一次  

### 6. 常見錯誤

- **Signing requires a development team** → 在 Signing 選 Team，或 Xcode → Settings → Accounts 登入 Apple ID
- **No devices** → 確認線材、信任電腦、iPhone 已解鎖
- **Token Core 載入失敗** → 再跑一次 `sync-token-core-ios.sh` 後 Clean Build（Product → Clean Build Folder）

### 同步 Token Core 資源

```bash
./ios/scripts/sync-token-core-ios.sh
```

## 測試網快速開始

1. 建立錢包 → 複製 **0x** 地址  
2. 探索頁或首頁橫幅 → **領取 Sepolia ETH**  
   - 建議：[Google Cloud Sepolia Faucet](https://cloud.google.com/application/web3/faucet/ethereum/sepolia)（通常不需主網 ETH）  
   - 備用：Chainlink、Alchemy（見 App 內連結）  
3. 首頁 **重新整理** → 應看到 ETH 餘額  

切回主網：修改 `ChainConfig.swift` 的 `usesTestnet = false`。

## 底部 Deck（常駐）

| 項目 | 功能 |
|------|------|
| **首頁** | 鏈上 ETH 餘額、主權防衛 |
| **行情** | ETH / USDC / WETH 等示範行情 |
| **交換**（中央） | SWAP 頁 |
| **探索** | Uniswap、Aave、Etherscan Sepolia、水龍頭 |
| **錢包** | Sepolia 持倉與地址 |

代幣列表圖示右下角會顯示目前鏈標記（Sepolia ETH）。

## 脅迫防護

設定中開啟 **Face ID** 與 **脅迫防護** 後，解鎖會先進入假錢包；秘密手勢為 Deck：**交換 → 交換 → 錢包 → 錢包**。

若在假錢包模式下仍嘗試 **發送、交換、簽名** 等操作，會跳出「應用程式出現錯誤請稍後再試…」並倒數 5 秒；倒數結束後自動恢復。若提前點「確認」會重新計時 5 秒。

## 探索頁（Ethereum）

- **DeFi**：Uniswap、Aave、OpenSea Testnets  
- **工具**：Etherscan Sepolia、Sepolia 水龍頭、DeBank  
