# Demo Day — Puffer Sepolia 演示檢查

## 上台前 30 分鐘（必做）

1. **手機連穩定 Wi‑Fi**，關閉低耗電模式。
2. 打開 App → **探索 → Puffer 質押／解質押**，**下拉刷新**。
3. 確認畫面**沒有黃色「待確認交易」橫幅**；若有，先處理 nonce（見下）再上台。
4. 在 [Sepolia Etherscan](https://sepolia.etherscan.io) 打開演示錢包地址：
   - **Pending Txns = 0**
   - 有足夠 Sepolia ETH（建議 ≥ 0.02）
   - 若要演示解質押：鏈上 **pufETH > 0**
5. 用密碼解鎖一次，確認 **Face ID** 可用（避免台上第一次才要輸入長密碼）。
6. 重新安裝最新 IPA（含「解質押全部」與 nonce 橫幅）：`./ios/scripts/build-ipa.sh`

## 推薦演示腳本（降低卡住）

| 步驟 | 操作 | 注意 |
|------|------|------|
| 1 | 只演示 **質押 0.01 ETH** 或 **解質押全部** 擇一 | 不要連點按鈕 |
| 2 | 按一次後等 **「廣播交易中…」** 結束 | 約 10–30 秒 |
| 3 | 等結果卡片出現 **tx hash** | 可點開 Etherscan 給評審看 |
| 4 | 若要第二筆操作 | 等上一筆 Etherscan **Success** 再做 |

**不要**在台上連續：質押 → 立刻解質押 → 再質押（容易留下 Pending）。

## 若上台前發現 nonce 卡住

1. App Puffer 頁黃色橫幅 → **「清除 Pending（取消待確認）」**（需 Face ID／密碼，會消耗少量 Gas）。
2. 或 Etherscan → **Pending** → MetaMask **Cancel**。
3. **下拉刷新**，橫幅消失後再演示。

## 台上若突然跳出「待確認交易」

1. 對評審說：「上一筆還在 Sepolia 排隊，我們先看鏈上狀態。」
2. 點彈窗 **「在 Etherscan 查看」** 或橫幅連結。
3. **備援 A**：若 Pending 快確認，等 1 分鐘 → App **再試一次**。
4. **備援 B**：改講已成功的 **tx hash**（結果卡片在頁面頂部），不必當場再送交易。
5. **備援 C**（事前準備）：另建一組「演示專用」錢包，上台前確認該地址 Pending = 0。

## 設定建議

- **脅迫防護**：演示前關閉（預設已關）。
- **Face ID**：開啟，減少輸密碼時間。
- **Secrets.plist**：確認 `PUFFER_SEPOLIA_VAULT` 為含 `withdraw` 的新 Vault。
