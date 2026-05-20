# Wallet Security Reference Handbook

> A security reference for participants of the imToken 10th Anniversary AI Co-Creation Activity.

---

## Contents

1. [Security Model of Non-Custodial Wallets](#1-security-model-of-non-custodial-wallets)
2. [Key Security Threats Relevant to This Activity](#2-key-security-threats-relevant-to-this-activity)
3. [Developer Security Design Checklist](#3-developer-security-design-checklist)
4. [Token Core CLI Security Features](#4-token-core-cli-security-features)
5. [Activity Safety Boundaries](#5-activity-safety-boundaries)

---

## 1. Security Model of Non-Custodial Wallets

### Core Principle

**Your keys, your assets. No keys, no assets.**

A non-custodial wallet means the user has full, sole control over their private key and mnemonic
phrase. No third party — including the wallet developer — can operate assets on the user's behalf.
This is both the greatest strength and the greatest security responsibility of this model.

### Attack Surface Overview

```
User
 │
 ├── Off-Chain Attack Surface
 │       ├── Social Engineering: fake support, fake campaigns, phishing links
 │       ├── Client Forgery: fake apps, fake websites
 │       └── UI Deception: misleading signing pages, fake payment QR codes
 │
 └── On-Chain Attack Surface
         ├── Malicious Contracts: approve scams, Permit phishing
         ├── Data Pollution: address-tail collision, fake token airdrops
         └── Memo Phishing: on-chain message fields used as phishing channels
```

As a wallet developer, your product needs to protect users from both attack categories at the
**client layer** — the layer you actually control.

---

## 2. Key Security Threats Relevant to This Activity

The following security events are highly relevant to the scope of this activity (EVM web wallets,
on-chain interactions). The selection focuses on attacks where wallet UX design can make a
meaningful difference. Each entry covers: the attack scenario, the underlying mechanism, and
design-level mitigations for wallet builders.

---

### 2.1 Malicious Contract Interaction & Blind Signing

**Attack Scenario**

When interacting with a DApp, a user is induced to sign a request that looks like a "login
verification" or "simple payment," but is actually an ERC-20 `approve` transaction granting an
attacker's address permission to transfer the user's tokens. After signing, the attacker can
call `transferFrom` at any time to drain the token — with no further user confirmation required.

Common variants:
- **ERC-20 approve:** Direct on-chain approval, often set to `uint256 max` (unlimited)
- **Permit (EIP-2612):** Off-chain signature, no gas cost, harder for users to detect
- **Permit2 (Uniswap):** Single off-chain signature can authorize multiple tokens at once,
  expanding the attack surface further

**Attack Mechanism**

Exploits the information asymmetry between what users see (a "Confirm" button) and what they
are actually signing (permanent transfer authority over all their USDC to an unknown contract).
Users cannot read raw calldata or ABI, so they rely entirely on what the wallet UI tells them.

**Developer Defense**

| Design principle | Details |
|-----------------|---------|
| Decode before confirm | Before the sign button is active, display: function name, contract address with verification status, token being approved, exact amount |
| Unlimited approval warning | Detect `uint256 max` and trigger a red Danger modal requiring explicit user confirmation |
| Distinguish Permit signatures | Visually separate Permit / Permit2 signatures from login signatures; label them "This action grants token transfer permission" |
| Editable approval amount | Let users reduce the approval amount to exactly what the DApp needs, rather than accepting the contract's default |

> 💡 **Useful tool:** The Token Core CLI `analyze` command automatically decodes calldata and
> outputs a human-readable summary with policy check results. See Section 4.

---

### 2.2 Permit2 Off-Chain Signature Phishing

**Attack Scenario**

Permit2 is a token authorization standard (EIP-712) that allows off-chain authorization of
token transfers with zero gas cost. Attackers craft signing requests that appear identical to
harmless login prompts. Once signed, the attacker calls the Permit2 contract to transfer assets
— no further on-chain action by the victim is needed.

**Attack Mechanism**

- Users are conditioned to treat "sign to connect" as a safe, reversible action like logging in
- Permit2 defaults to authorizing the full token balance
- The signature is off-chain and invisible in the user's transaction history until the attacker
  acts on it
- Asset loss is on-chain and irreversible once the attacker executes the transfer

**Developer Defense**

| Design principle | Details |
|-----------------|---------|
| Type labeling | In the signing preview, explicitly label the signature type: "EIP-712 Permit2 Authorization" vs "Login / Connection Signature" |
| Authorization details | Display: token being authorized, amount, expiry, and the address being authorized |
| Amount warning | When Permit2 defaults to the full balance, trigger the same Danger-level flow as for unlimited ERC-20 approve |
| Source verification | Show the requesting domain and indicate whether it is a known trusted DApp |

---

### 2.3 On-Chain Visual Fraud: Address-Tail Collision

**Attack Scenario**

Attackers use scripts to generate addresses that match the first and last N characters of
a user's frequent recipients (e.g., same first 4 + last 4 characters). They send 0 USDT or
a dust amount to the user's wallet, planting the spoofed record in transaction history. The
next time the user copies an address from history to make a transfer, they may unknowingly
select the attacker's address.

**Attack Mechanism**

Exploits two habits simultaneously: wallets faithfully rendering all on-chain data, and users
copying addresses from transaction history rather than from a saved address book. The collision
is invisible when addresses are truncated in the display.

**Developer Defense**

| Design principle | Details |
|-----------------|---------|
| Filter dust transactions | Hide transfers with token amount = 0 or below a threshold (e.g., ≤ 0.001 USDT) from the default history view |
| Full address on confirm | Transfer confirmation screens must show the complete address — no truncation |
| Copy with verification nudge | After copying an address, show a toast: "Copied. Please verify the full address before sending." |
| Address book promotion | Guide users to save trusted addresses to an address book after each successful transfer; make address book the preferred starting point for sending |

---

### 2.4 On-Chain Data Pollution: Transaction Memo Phishing

**Attack Scenario**

Attackers send small amounts of cryptocurrency to victim addresses with phishing instructions
embedded in the transaction memo field. The messages typically direct users to contact fake
support channels (e.g., a Telegram bot) to "resolve" a wallet issue, then charge them a fee
or steal credentials. Some users mistake memo content for official wallet notifications.

**Attack Mechanism**

Blockchain data is open — anyone can send a transaction with arbitrary memo content to any
address. Wallets that faithfully display all memo content inadvertently become a delivery
channel for attackers, with the wallet's own UI lending credibility to the phishing message.

**Developer Defense**

| Design principle | Details |
|-----------------|---------|
| Treat memo as untrusted input | Apply XSS sanitization to all memo / input data fields before rendering |
| Risk masking | Collapse memo content containing contact info, URLs, or social handles by default; show a risk label and require user action to expand |
| Clear attribution | Display a note next to memo content: "This message was sent by the transaction sender, not by this wallet" |
| Isolated notification channel | Maintain a separate, clearly branded in-app notification area so users can distinguish wallet communications from on-chain data |

---

### 2.5 Fake Token Airdrop Scams

**Attack Scenario**

Attackers airdrop counterfeit tokens with names identical to high-value assets (e.g., fake
USDC, fake ARB) to user wallets. Users who see an unexpected balance are lured to an attacker-
controlled DApp to "swap" or "claim" the tokens. The DApp interaction is actually an approval
transaction, giving the attacker authority to drain the user's real assets.

**Attack Mechanism**

Exploits two things: users' hope of receiving a legitimate airdrop, and their inability to
distinguish real tokens from counterfeits by name or balance display alone. The wallet UI —
by showing an unfamiliar token as a normal balance item — provides a false sense of legitimacy.

**Developer Defense**

| Design principle | Details |
|-----------------|---------|
| Unverified token badge | Tokens not present in a trusted registry (CoinGecko, official token lists) are marked "Unverified" |
| Restricted actions on unknown tokens | Hide Swap / Send shortcuts on unverified tokens by default; require an explicit opt-in step |
| Pre-interaction warning | Show a full-screen risk notice before any contract interaction initiated from an unverified token |
| Blacklist integration | Integrate a known-malicious contract list; hard-block all interactions with blacklisted addresses |

---

## 3. Developer Security Design Checklist

Use this checklist to self-review before submitting your co-creation work. Items are grouped
by feature area.

### 3.1 Key Material & Mnemonic

- [ ] Mnemonic and private key are processed only on-device; never transmitted to any server
- [ ] The mnemonic display screen includes a screenshot risk notice or recommendation to record
  offline
- [ ] Private key / mnemonic input fields have `autocomplete="off"` to prevent browser caching
- [ ] All demos use a dedicated test wallet, not a wallet holding real assets

### 3.2 Signing & Authorization

- [ ] All signing requests are decoded and displayed in human-readable format before the confirm
  button is active
- [ ] ERC-20 approve shows: authorized contract address, token, exact amount
- [ ] Permit / Permit2 signatures are visually distinct from login signatures in the UI
- [ ] Unlimited approval (`uint256 max`) triggers a Danger-level warning modal
- [ ] The signing confirmation screen shows contract verification status

### 3.3 Address Display & Transfers

- [ ] Transfer confirmation screens show the full recipient address — no truncation
- [ ] One-click copy is accompanied by a "Please verify the full address" prompt
- [ ] Users are guided to save trusted addresses to an address book
- [ ] Transaction history filters out zero-value and dust-amount records by default

### 3.4 DApp & Contract Interaction

- [ ] The requesting domain is displayed and labeled (known / unknown DApp)
- [ ] Unverified contracts trigger a Warning-level notice before interaction
- [ ] A known-malicious contract blacklist is integrated; listed addresses are hard-blocked
- [ ] Unknown tokens do not show Swap / Send shortcuts by default

### 3.5 Risk UI Components

- [ ] A consistent four-level severity system is used (Info / Warning / Danger / Block)
- [ ] Danger-level actions require explicit user confirmation; not dismissible by clicking outside
- [ ] Confirm buttons for high-risk actions use descriptive labels, not generic "OK" or "Confirm"
- [ ] All risk UI components follow the token-ui design system conventions

---

## 4. Token Core CLI Security Features

The Token Core CLI (branch: `demo/token-core-cli`) provides built-in security capabilities
that can be integrated directly into your wallet.

### 4.1 Transaction Analysis (`analyze`)

```bash
npm run cli -- analyze --chain eth-sepolia \
  --input '{"chainId":11155111,"account":"0x...","to":"0x...","data":"0x...","value":"0"}' \
  --policy ./src/policies/default-risk-policy.json
```

**Output includes:**
- Human-readable function call summary (Traditional Chinese, AI-generated)
- Policy check result: pass / warn / block
- Tenderly simulation result: asset delta preview, revert risk

**When to call:** Before the user clicks "Sign." Map results to your risk severity system
using the table in Section 4.3.

### 4.2 Policy-Gated Signing (`sign`) and Broadcasting (`broadcast`)

Both `sign` and `broadcast` require a `--policy` flag and abort on violation. Surface the
violated rule in your UI at the appropriate severity level.

### 4.3 CLI Output → UI Risk Level Mapping

| CLI output state | Recommended UI treatment |
|-----------------|--------------------------|
| Contract unverified on Etherscan / Sourcify | Warning banner + user confirmation required |
| Function selector unrecognized (4byte miss) | Warning banner + display raw calldata |
| Tenderly simulation failed or reverted | Danger modal + strong cancellation recommendation |
| Policy rule violated | Block — hard stop with explanation of the violated rule |
| No API key, local rules only | Info note: "Result based on local rules, not full simulation" |

### 4.4 Policy Files

Built-in examples are in `src/policies/`. Use `default-risk-policy.json` as the starting
point. Encourage participants to review and customize the policy file — the choices made there
(which behaviors to warn on, which to block) are themselves a security design decision worth
documenting in their submission.

---

## 5. Activity Safety Boundaries

The following requirements come directly from the official activity rules.
Your submission must satisfy them.

| Requirement | Details |
|------------|---------|
| Testnet first | Use Sepolia or Base Sepolia for all demonstrations |
| No real mnemonic input | Never enter your real mnemonic into any AI tool, demo environment, or public recording |
| Asset isolation | If mainnet is used, use only a small, disposable amount |
| Key material stays local | Mnemonic and private key must never be transmitted to any server in your demo wallet |
| Safety statement in submission | State: whether real assets are involved, how user key data is protected |

### Safety Statement Template for Submission

```
Safety Statement:
- Network used: [Testnet Sepolia / Mainnet (demo only, amount < X)]
- Real assets involved: [No / Yes, demo only, amount < X]
- Key storage: [Browser-side only, never uploaded to any server]
- Environment isolation: [Dedicated demo wallet, separate from personal assets]
```

---

# 钱包安全参考手册

> 本手册为 imToken 十周年 AI 用户共创活动参与者提供安全参考。

---

## 目录

1. [Non-Custodial Wallet 的安全模型](#1-non-custodial-wallet-的安全模型)
2. [共创活动相关核心安全事件](#2-共创活动相关核心安全事件)
3. [开发者安全设计检查清单](#3-开发者安全设计检查清单)
4. [Token Core CLI 安全能力速查](#4-token-core-cli-安全能力速查)
5. [活动安全边界提示](#5-活动安全边界提示)

---

## 1. Non-Custodial Wallet 的安全模型

### 核心原则

**你的钥匙，你的资产。没有钥匙，没有资产。**

Non-custodial 钱包意味着用户完全自主掌控自己的私钥和助记词，没有任何第三方（包括钱包开发者）可以代替用户操作资产。这是它最大的优势，也是最大的安全责任来源。

### 攻击面概览

```
用户 (User)
 │
 ├── 链下攻击面 (Off-Chain)
 │       ├── 社会工程学：假客服、假活动、钓鱼链接
 │       ├── 客户端伪造：假 App、假网站
 │       └── 界面欺骗：误导性签名页、伪造收款码
 │
 └── 链上攻击面 (On-Chain)
         ├── 恶意合约：approve 骗局、Permit 钓鱼
         ├── 数据污染：尾号碰撞地址、假代币空投
         └── Memo 钓鱼：链上备注字段被用作钓鱼投递渠道
```

作为钱包开发者，你的产品需要在**客户端层**——也就是你实际掌控的那一层——保护用户免受以上两类攻击。

---

## 2. 共创活动相关核心安全事件

以下安全事件与本次共创活动的作品范围（EVM 网页钱包、链上交互）高度相关。筛选标准是：钱包 UX 设计能够在这些攻击中发挥实质性的防护作用。每类事件包含：攻击场景、底层机制、以及面向钱包构建者的产品设计层防护要点。

---

### 2.1 恶意合约交互与盲签（Blind Signing）

**攻击场景**

用户在与 DApp 交互时，被诱导签署一笔看起来像"登录验证"或"普通付款"的请求，但实际上是一笔 ERC-20 `approve` 交易，将用户钱包中的代币转账权限授予攻击者的地址。用户签名后，攻击者可以在任意时间调用 `transferFrom` 将代币转走，全程无需用户二次确认。

常见变体：
- **ERC-20 approve**：直接链上授权，金额常为 `uint256 max`（无限额）
- **Permit（EIP-2612）**：链下签名，气费为零，更难被用户察觉
- **Permit2（Uniswap）**：单次链下签名可授权多种代币，攻击面更大

**攻击机制原理**

利用用户无法阅读底层 calldata / ABI 的信息不对称。用户在签名页看到的只是"确认"按钮，而不是"我正在将我所有的 USDC 转账权限永久授予某个合约"。用户对钱包 UI 呈现的内容有完全的信任依赖。

**开发者防护要点**

| 设计原则 | 说明 |
|---------|------|
| 解码后才能确认 | 签名按钮激活前，必须展示：函数名、目标合约地址（附验证状态）、被授权代币、精确金额 |
| 无限额预警 | 检测到 `uint256 max` 时，触发红色 Danger 弹窗，要求用户明确确认 |
| Permit 签名区分 | 将 Permit / Permit2 签名与普通登录签名在 UI 上明确区分，标注"此操作将授权代币转账权限" |
| 可编辑授权额度 | 允许用户在确认前将授权金额改为精确所需额度，而非强制接受合约传入的数值 |

> 💡 **参考工具**：Token Core CLI 的 `analyze` 命令可自动 decode calldata，输出人类可读摘要和 policy 校验结果。详见第 4 节。

---

### 2.2 Permit2 链下签名钓鱼

**攻击场景**

Permit2 是 Uniswap 推出的代币授权标准（EIP-712），允许用户通过链下签名授权代币转移，无需支付 Gas。攻击者伪造签名请求，使其看起来与普通的"连接钱包"登录完全一致。用户一旦签名，攻击者凭此调用 Permit2 合约即可转走资产——受害者不需要再做任何操作。

**攻击机制原理**

- 用户习惯于将"签名连接"视为安全、可逆的操作，类似普通登录
- Permit2 默认授权额度为代币全部余额
- 签名是链下行为，不会立即出现在用户的交易历史中，直到攻击者执行转账
- 资产损失发生在链上，不可撤销

**开发者防护要点**

| 设计原则 | 说明 |
|---------|------|
| 签名类型标注 | 在签名预览页明确标注类型："EIP-712 Permit2 授权"vs"登录/连接签名" |
| 授权详情展示 | 显示：被授权代币、授权额度、有效期、被授权地址 |
| 额度警告 | 当 Permit2 默认全额时，触发与无限额 approve 相同的 Danger 级别警告流程 |
| 来源验证 | 展示发起签名请求的域名，并标注是否为已知可信 DApp |

---

### 2.3 链上视觉欺诈：尾号地址碰撞

**攻击场景**

攻击者用脚本批量生成与用户常用转账对象首尾字符相同（如前 4 位 + 后 4 位一致）的"碰撞地址"，然后向用户钱包发送 0 USDT 或极小额代币，使这条伪造记录出现在用户的交易历史中。用户下次从历史记录复制地址发起转账时，极易误选攻击者地址。

**攻击机制原理**

同时利用了两个习惯：钱包如实渲染所有链上数据，以及用户从交易历史复制地址而非从已保存的地址簿发起转账。当地址在界面上被截断显示时，碰撞无法被肉眼察觉。

**开发者防护要点**

| 设计原则 | 说明 |
|---------|------|
| 过滤粉尘交易 | 在默认历史视图中隐藏 token amount = 0 或极小额（如 ≤ 0.001 USDT）的转账记录 |
| 确认页全地址展示 | 转账确认页必须显示完整收款地址，不截断 |
| 复制验证提示 | 复制地址后展示 toast："已复制，转账前请核对完整地址" |
| 地址簿引导 | 每次转账完成后，引导用户将收款方保存到地址簿；将地址簿设为发起转账的优先入口 |

---

### 2.4 链上数据污染：交易 Memo 钓鱼

**攻击场景**

攻击者向用户地址发送小额资产，在交易备注（memo）字段写入钓鱼话术，诱导用户前往 Telegram 等渠道联系"官方客服"，缴纳所谓"处理费"或泄露凭证。部分用户会误以为 memo 内容是钱包官方发送的通知。

**攻击机制原理**

区块链数据具有开放性——任何人都可以向任意地址发送携带任意 memo 内容的交易。如果钱包如实展示所有 memo 内容，钱包自身的 UI 就会无意间成为攻击者的投递渠道，并为钓鱼信息提供视觉上的可信度加持。

**开发者防护要点**

| 设计原则 | 说明 |
|---------|------|
| Memo 视为不可信输入 | 对所有 memo / input data 字段进行 XSS 过滤后再渲染 |
| 风险内容遮罩 | 含联系方式、URL、社交账号的 memo 默认折叠并加风险标签，需用户主动展开 |
| 明确归属说明 | 在 memo 旁注明："此内容由交易发送方附带，非本钱包官方信息" |
| 独立官方通知渠道 | 在 App 内维护一个独立且有品牌标识的官方通知区域，与链上数据严格隔离 |

---

### 2.5 假代币空投诈骗

**攻击场景**

攻击者向用户钱包空投与知名资产同名的伪造代币（如假 USDC、假 ARB）。用户看到意外的余额后，被诱导前往攻击者控制的 DApp 进行"兑换"或"领取"。该操作实际上是一笔授权交易，骗子获得授权后即可转走用户的真实资产。

**攻击机制原理**

同时利用了两点：用户对空投的侥幸心理，以及仅凭代币名称和余额无法判断合约真实性的信息差。钱包 UI 将陌生代币作为普通余额项展示，无意间为其提供了视觉上的合法性背书。

**开发者防护要点**

| 设计原则 | 说明 |
|---------|------|
| 未验证代币标记 | 未在可信 token registry（如 CoinGecko、官方 token list）中的代币，显示"未验证"标签 |
| 限制未知代币操作入口 | 未验证代币默认不显示 Swap / Send 快捷按钮，需用户手动启用 |
| 交互前风险提示 | 与未验证代币合约交互前，展示全屏风险提示，要求用户确认 |
| 黑名单拦截 | 接入已知恶意合约黑名单，对黑名单地址执行硬拦截，完全阻断交互 |

---

## 3. 开发者安全设计检查清单

在提交共创作品前，建议对照以下清单自查。清单按功能模块分组。

### 3.1 密钥与助记词

- [ ] 助记词和私钥仅在设备端（浏览器内存/本地存储）处理，不传输到任何服务器
- [ ] 助记词展示页包含"截图风险"提示，或建议用户离线记录
- [ ] 私钥/助记词输入框设置 `autocomplete="off"`，避免浏览器缓存
- [ ] 所有演示使用专门创建的测试钱包，不使用持有真实资产的钱包

### 3.2 签名与授权

- [ ] 所有签名请求在确认按钮激活前，已解码并以人类可读格式展示
- [ ] ERC-20 approve 显示：被授权合约地址、代币、精确额度
- [ ] Permit / Permit2 签名与登录签名在 UI 上有明确区分
- [ ] 无限额授权（`uint256 max`）触发 Danger 级别警告弹窗
- [ ] 签名确认页展示合约验证状态（已验证 / 未验证 / 未知）

### 3.3 地址展示与转账

- [ ] 转账确认页显示完整收款地址，不截断
- [ ] 提供一键复制，并附"请核对完整地址"提示
- [ ] 引导用户将常用地址保存到地址簿
- [ ] 交易历史默认过滤 amount = 0 或粉尘金额的记录

### 3.4 DApp 与合约交互

- [ ] 展示发起请求的域名，并标注是否为已知 DApp
- [ ] 合约未验证时，在交互前展示 Warning 级别提示
- [ ] 已接入合约黑名单，黑名单地址执行硬拦截
- [ ] 未验证代币不默认显示 Swap / Send 入口

### 3.5 风险 UI 组件

- [ ] 使用统一的四级风险等级体系（Info / Warning / Danger / Block）
- [ ] Danger 级别操作需要用户主动确认，不可通过点击背景关闭
- [ ] 高风险操作的确认按钮使用具体描述性文案，而非通用的"确认"或"OK"
- [ ] 所有风控组件样式符合 token-ui 的设计规范

---

## 4. Token Core CLI 安全能力速查

Token Core CLI（分支：`demo/token-core-cli`）内置了可以直接集成到你的钱包作品中的安全能力。

### 4.1 交易分析（`analyze`）

```bash
npm run cli -- analyze --chain eth-sepolia \
  --input '{"chainId":11155111,"account":"0x...","to":"0x...","data":"0x...","value":"0"}' \
  --policy ./src/policies/default-risk-policy.json
```

**输出内容：**
- 函数名与调用摘要（繁体中文，AI 生成）
- Policy 校验结果：通过 / 警告 / 阻断
- Tenderly 模拟结果：资产变化预览、是否 revert

**何时调用：** 在用户点击"签名"之前。将结果映射到你的风险等级体系（见第 4.3 节）。

### 4.2 带 Policy 校验的签名（`sign`）与广播（`broadcast`）

`sign` 和 `broadcast` 均需要 `--policy` 参数，违规时自动中止并输出违规规则。将退出状态映射到 UI 的对应风险等级。

### 4.3 CLI 输出 → UI 风险等级映射

| CLI 输出状态 | 建议 UI 处理 |
|------------|------------|
| 合约未在 Etherscan / Sourcify 验证 | Warning 横幅 + 要求用户确认 |
| Function selector 无法识别（4byte 未命中） | Warning 横幅 + 展示原始 calldata |
| Tenderly 模拟失败或 revert | Danger 弹窗 + 强烈建议取消 |
| Policy 规则违规 | Block 硬拦截 + 说明违规规则 |
| 无 API Key，仅使用本地规则 | Info 提示："结果基于本地规则推断，非完整模拟" |

### 4.4 Policy 文件

内置示例位于 `src/policies/`，以 `default-risk-policy.json` 作为通用起点。建议参与者阅读并自定义 policy 文件——对哪些行为发出警告、对哪些行为执行拦截，本身就是钱包安全设计的一部分，值得在提交说明中记录。

---

## 5. 活动安全边界提示

以下内容来自官方活动规则，提交作品时须满足这些要求。

| 要求 | 说明 |
|------|------|
| 优先使用测试网 | 建议在 Sepolia 或 Base Sepolia 完成所有演示 |
| 不输入真实助记词 | 不得将个人真实助记词输入任何 AI 工具、演示环境或公开录屏 |
| 主网仅用小额 | 如演示涉及主网，只使用极小额专用资产 |
| 密钥数据留存本地 | 助记词和私钥不得传输到演示钱包的任何服务器端 |
| 提交安全说明 | 须说明：是否涉及真实资产、如何保护用户密钥数据 |

### 提交安全说明参考模板

```
安全说明：
- 使用网络：[测试网 Sepolia / 主网（仅演示，金额 < X）]
- 是否涉及真实资产：[否 / 是，仅用于演示，金额 < X]
- 助记词 / 私钥存储方式：[仅浏览器端，不上传至任何服务器]
- 演示环境隔离说明：[专用演示钱包，独立于个人资产]
```

---

