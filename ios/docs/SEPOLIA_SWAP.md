# Sepolia 鏈上功能（交易紀錄 · 行情 · 交換）

## 交易紀錄（錢包 → 點代幣）

- 從 **Sepolia Etherscan API** 讀取真實交易
- 可選在 `Secrets.plist` 加入 `ETHERSCAN_API_KEY`（提高限流額度）

## 行情

- 列表與價格來自 **CoinGecko 即時 API**
- ETH / vUSDC 餘額會合併你錢包鏈上持倉

## 交換（Sepolia 測試網）

| 代幣對 | 說明 |
|--------|------|
| ETH → pufETH | Puffer 演示 Vault（需已配置 `PUFFER_SEPOLIA_VAULT`） |
| ETH ↔ vUSDC | `VibeSwapDemo` 合約（需部署） |

### 部署 vUSDC 交換合約

```bash
export SEPOLIA_DEPLOYER_KEY=0x你的部署私鑰   # 或沿用 setup-puffer 寫入 Secrets 的 key
node scripts/setup-swap-sepolia.mjs
```

成功後 `Secrets.plist` 會有 `SEPOLIA_SWAP_DEMO`，Xcode Clean Build 再 Run。

### 測試步驟

1. 錢包有 Sepolia ETH
2. **交換** → 選 ETH 支付、vUSDC 接收 → 輸入小額（如 `0.001`）→ 確認並廣播
3. **錢包** 應出現 vUSDC 持倉；點進可見鏈上歷史
