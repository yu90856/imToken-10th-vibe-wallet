# iPhone 實機除錯（Xcode 線接）

## 1. 準備

- Mac 安裝 **Xcode**（App Store）
- iPhone 用 **USB 線**連 Mac
- iPhone：**設定 → 一般 → VPN 與裝置管理** 若曾用 Sideloadly，不影響 Xcode 安裝（可並存，建議除錯時刪掉 Sideloadly 版再 Run）

## 2. iPhone 設定

1. 解鎖手機，點 **信任此電腦**
2. iOS 16+：**設定 → 隱私權與安全性 → 開發者模式** → 開啟 → 重開機
3. 保持螢幕亮著（或關閉自動鎖定）避免除錯中斷

## 3. Xcode 簽署

1. 開啟專案：
   ```bash
   open /Users/viola/Desktop/Vibe/ios/VibeWallet.xcodeproj
   ```
2. 左側點藍色 **VibeWallet** 專案 → **TARGETS** → **VibeWallet** → **Signing & Capabilities**
3. 勾選 **Automatically manage signing**
4. **Team** 選你的 Apple ID（Personal Team）
5. 若 Bundle ID 衝突，改成唯一值，例如 `com.你的名字.vibewallet`

## 4. 選裝置並 Run

1. Xcode **上方中間**裝置選單：選你的 **iPhone 名稱**（不要選 Simulator）
2. 左側 Scheme 選 **VibeWallet**
3. 按 **▶ Run**（或 `⌘R`）
4. 第一次會編譯 1–3 分鐘，App 會裝進手機並自動打開

## 5. 看閃退原因（最重要）

1. Xcode 底部點 **Debug area**（或 `⌘⇧Y` 打開）
2. 選 **Console** 分頁
3. 在手機上重現：**建立新錢包 → 設密碼 → 建立錢包**
4. Console 右下角過濾框輸入 **`TokenCore`**（或 **`[TokenCore]`**），然後清空舊 log（垃圾桶圖示）再重現操作。

   **Debug 建置**應依序看到類似：

   ```
   [TokenCore] 開始初始化 WebView…
   [TokenCore] HTML pageReady
   [TokenCore] HTML 就緒，注入 WASM（… bytes）…
   [TokenCore] WASM 就緒 ✓
   [TokenCore] 使用者按下建立／匯入錢包
   [TokenCore] 呼叫 createWallet…
   [TokenCore] 建立錢包成功，進入備份助記詞
   ```

   若過濾後**完全空白**：代表還沒跑到 Token Core（或用的是 Release IPA／舊版），請確認 Scheme 為 **Debug**、裝置為 **真機**、並用 `⌘R` 重新 Run。

5. 若閃退，Console 最後幾行會有錯誤，搜尋：
   - `TokenCore`
   - `WebContent process`
   - `fatal error`
   - `assertion`
   - `WalletKeychain`

把 **閃退前 20 行**複製下來即可排查。

### 進階：斷點

在 `WalletOnboardingView.swift` 的 `submitPassword()` 第一行設斷點，Run 後逐步執行，看卡在哪一行。

## 6. 常見 Signing 錯誤

| 訊息 | 處理 |
|------|------|
| Failed to register bundle identifier | 改 Bundle ID |
| No signing certificate | Xcode → Settings → Accounts → 登入 Apple ID → Download Manual Profiles |
| Developer Mode disabled | 手機開啟開發者模式 |

## 7. 與 Sideloadly 差異

Xcode Run 會用**開發簽名**直接安裝，除錯資訊完整、較不易因 IPA 打包方式出問題。建議**先用 Xcode 跑通**，再重新 `build-ipa.sh` 給 Sideloadly。
