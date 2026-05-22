# imToken 十周年 AI 共創 — 金数据提交稿

表单链接：https://eylyq7xd.jsjform.com/f/dS0f4E  

**请用 Chrome / Edge / Safari 最新版打开**（微信内置浏览器可能显示「当前浏览器不支持」）。

GitHub 仓库：https://github.com/yu90856/imToken-10th-vibe-wallet  

---

## 一、基本信息（按表单常见字段）

| 字段 | 建议填写 |
|------|----------|
| 参赛者 / 昵称 | `yu90856`（或你的真实姓名） |
| 联系邮箱 | 你的常用邮箱 |
| 作品名称 | **Vibe Wallet** |
| 作品类型 | 钱包 / Web3 钱包 / iOS 原生钱包 |
| 是否团队 | 个人 |

---

## 二、作品链接

| 字段 | 内容 |
|------|------|
| **GitHub 仓库** | https://github.com/yu90856/imToken-10th-vibe-wallet |
| **演示视频** | （请自行上传 B 站 / YouTube / 飞书，填链接） |
| **在线演示** | 无（iOS 原生为主；Web 端可 `npm run dev` 本地演示） |

### 演示视频建议脚本（约 2～3 分钟）

1. 打开 App → 建立 / 导入钱包（Sepolia）
2. 领 Sepolia 测试 ETH → 首页显示余额
3. 行情页（CoinGecko 实时）→ 探索页 DApp（Uniswap / Etherscan）
4. 设置 → **一键检测 GitHub 整合**（给评委看 Token Core 等通过项）
5. Face ID 锁定 → 提示词解锁（可选）
6. 说明：测试网、无私钥上传

---

## 三、作品简介（可直接粘贴）

```
Vibe Wallet 是一款以「用户主权」为核心的非托管 Ethereum 钱包，主打 iOS 原生体验与笔记本手绘风 UI。

参赛作品深度整合 imToken 官方三大资源：
① Token Core（@consenlabs/tcx-wasm）— 本机 WKWebView 执行 WASM，完成助记词创建/导入、Keystore 与 Sepolia 地址派生；
② Token UI 设计规范 — 笔记本横线、便利贴卡片与 token-ui 色彩体系；
③ Security SKILL — 助记词/签名/假钱包胁迫防护、DApp 内建浏览器等按安全规范实现。

核心功能：Sepolia 测试网钱包、实时行情（CoinGecko）、资讯（CryptoCompare）、内建 DApp 浏览器（EIP-1193 注入）、Face ID 应用锁、胁迫假钱包、提示词备用解锁，以及设置内「参赛功能自检」供评委一键验证开源组件是否真实接入。

默认仅使用 Sepolia 测试网，助记词与 Keystore 仅存本机 Keychain，不上传任何服务器。
```

---

## 四、作品亮点（短版，适合「一句话」或 bullet 字段）

```
• 必用 Token Core：iOS 与 Web 共用 tcx-wasm，非 mock 地址派生
• 必用 Token UI：手绘笔记本 + 便利贴组件风格
• 必用 Security SKILL：胁迫假钱包、交易确认、测试网优先
• 评委模式：设置内一键检测 Token Core / CoinGecko / DApp 等是否 live
• Sepolia 全流程：领水 → 余额 → 探索 Uniswap / thirdweb
```

---

## 五、必参赛作品说明（三项）

### 1. Token Core  
https://github.com/consenlabs/token-core-monorepo  

**使用方式：**
- iOS：`ios/VibeWallet/Services/TokenCore/`（`TokenCoreBridge.swift` + `TokenCoreService.swift`）
- Web：`src/lib/tokenCore.ts`
- 资源同步：`ios/scripts/sync-token-core-ios.sh`

**能力：** `createKeystore`、`exportMnemonic`、`deriveAccounts`（Sepolia / TESTNET）

### 2. Token UI  
https://github.com/consenlabs/token-ui  

**使用方式：**
- Web：`vendor/token-ui`，`@repo/ui` 组件与 `globals.css`
- iOS：参考 DESIGN 色票与笔记本视觉（`AppTheme`、`NotebookPaperBackground`）

### 3. Security SKILL  
https://github.com/consenlabs/token-ui/tree/main/security  

**使用方式：**
- 仓库内 `security/SKILL.md`、`AGENTS.md` 引用
- 实现：Face ID、胁迫假钱包、DApp 确认、测试网默认、Keychain 存密钥

---

## 六、技术栈

| 层级 | 技术 |
|------|------|
| iOS | SwiftUI、WKWebView、LocalAuthentication、Keychain |
| 钱包核心 | @consenlabs/tcx-wasm（Token Core） |
| Web | React 19、TypeScript、Vite、Tailwind |
| 行情 | CoinGecko API |
| 资讯 | CryptoCompare API |
| 链 | Ethereum Sepolia（chainId 11155111） |
| DApp | 内建 WKWebView + window.ethereum（EIP-1193） |

---

## 七、安全说明（活动必填，直接粘贴）

```
安全说明：
- 使用网络：Ethereum Sepolia 测试网（ChainConfig.usesTestnet = true）
- 是否涉及真实资产：否，仅使用测试网水龙头领取的 Sepolia ETH
- 助记词 / 私钥存储：仅本机 Keychain（iOS）/ 浏览器本地（Web 原型），不上传至任何服务器
- 演示环境：专用演示钱包，未使用个人真实助记词
- AI 使用：开发过程使用 Cursor AI 辅助编码；App 内可选 Gemini 解读（需用户自行配置 API Key，默认 Mock，不涉及代签）
- 开源仓库：不含 Secrets.plist、不含 .env 密钥
```

---

## 八、评委 / 复现说明（「如何运行」类字段）

```
【iOS 真机 / 模拟器】
1. git clone https://github.com/yu90856/imToken-10th-vibe-wallet
2. cd 项目根目录 && ./ios/scripts/sync-token-core-ios.sh
3. open ios/VibeWallet.xcodeproj → 选 Team 签名 → Run
4. 或安装 ios/build/VibeWallet.ipa（需 Sideloadly + Apple ID 签名）

【验证开源整合】
App 内：首页 → 设置 →「一键检测 GitHub 整合」

【测试网】
探索页领 Sepolia ETH → 首页下拉刷新看余额

【Web 原型（可选）】
npm install && npm run dev
```

---

## 九、AI 使用说明（若表单有此项）

```
本作品在开发阶段使用 Cursor AI 辅助编写 Swift / TypeScript 代码与文档。

App 内「AI 助理」仅提供资产解读类问答（可选接入 Google Gemini），不接触助记词、不代签交易。未配置 API Key 时使用本地 Mock 回复。

演示与提交均未在 AI 对话或公开录屏中输入真实助记词。
```

---

## 十、截图建议（若需上传图片）

建议 4～6 张：

1. 主屏 + Sepolia 余额  
2. 行情列表（CoinGecko）  
3. 探索 / DApp 浏览器连接  
4. 设置 → 参赛功能检测（多项绿色通过）  
5. 笔记本尺规 Deck 底栏 + 五 tab  
6. App 图标（笔記本+锁）

---

## 十一、提交前检查清单

- [ ] GitHub 仓库为 **Public**（若活动要求公开）  
- [ ] 仓库内无 `Secrets.plist`、无 API Key  
- [ ] 演示视频已上传并填链接  
- [ ] 用 Chrome 打开金数据链接填写  
- [ ] 安全说明已粘贴  

---

*生成日期：2026-05-20 · 对应仓库 main 分支*
