---
title: DNS记录详解
date: 2026-10-21 20:09:00
updated: 2026-10-21 20:09:00
tags: ["Network", "DNS", "Cloudflare"]
categories: ["Network", "DNS"]
thumbnail: /post_images/DNS记录详解/DNS.jpg
---

# Cloudflare 域名解析记录完全指南

> 依据 Cloudflare 官方文档整理。核对日期：2026-10。

---

## 0. 一分钟速查表

| 我想做什么                                 | 用哪种记录                        | 关键注意点                                                                 |
| ------------------------------------------ | --------------------------------- | -------------------------------------------------------------------------- |
| 域名指向一个 IPv4 服务器                   | **A**                             | 与 AAAA 一样，直接写 IP                                                    |
| 域名指向一个 IPv6 服务器                   | **AAAA**                          | 与 A 可同名共存                                                            |
| 域名指向另一个域名（如 CDN、GitHub Pages） | **CNAME**                         | 同名不能再有其它记录；根域靠 CNAME flattening 才能与 MX/TXT 共存           |
| 接收邮件                                   | **MX**                            | 目标主机名要有 A 或 AAAA，并且在 Cloudflare 上必须灰云                     |
| 防止别人冒充你域名发邮件                   | **TXT**（SPF / DMARC）+ 空 **MX** | 不发信用 `v=spf1 -all`、DMARC `p=reject`、空 MX。DKIM 只在真有发信服务时配 |
| 限定哪些 CA 能给你签发证书                 | **CAA**                           | 写实际 CA 域名。`cloudflare.com` 不是签发 CA                               |
| 声明某服务的「主机 + 端口」                | **SRV**                           | 客户端必须支持 SRV 才有效                                                  |
| 声明 HTTP/3、ALPN 能力                     | **HTTPS / SVCB**                  | 橙云且开着 Universal SSL 时，Cloudflare 自动生成                           |
| 把子域名交给别家 DNS 托管                  | **NS**                            | 用于子域委派                                                               |
| 所有子域名都指向同一处                     | **A/CNAME + `*`**                 | 精确记录优先于通配符。DNS 通配符是多级的，证书通配符只覆盖一层             |
| 让 `web.example.com` 走 10080 端口         | **A + 灰云**，或反代到 443        | 橙云不支持 10080                                                           |
| 让 `ssh.example.com` 走 22 端口            | **A + 灰云**                      | 橙云不代理 22 端口                                                         |

---

## 1. 先理解 DNS 的解析链路

```
你在浏览器输入 web.example.com
        ↓
① 递归解析器（1.1.1.1 / 运营商 DNS）问根服务器：.com 谁管？
        ↓
② 问 .com 顶级域：example.com 的 NS 是谁？
        ↓  ← 这一步由「你在注册商填的 Nameserver」决定
③ 问 Cloudflare 权威服务器：example.com 有哪些记录？
        ↓  ← 这一步由「Cloudflare DNS 记录表」决定
④ 拿到答案（IP / CNAME / …），浏览器发起连接
        ↓  ← 端口由 URL 或客户端配置决定，DNS 不参与
```

**两条最重要的结论：**

1. **Nameserver 决定「谁来回答」，DNS 记录决定「回答什么」。** 你在 Cloudflare 后台加记录，只有当域名的 NS 确实指向 Cloudflare 时才生效。
2. **DNS 不携带端口信息**（SRV / HTTPS 记录除外）。`A` 记录只回答「这个域名对应哪个 IP」。端口来自 URL（`http://web.example.com:10080`）或客户端默认值（SSH 默认 22、HTTPS 默认 443）。

---

## 2. 一条记录的五个要素

在 Cloudflare 后台 **DNS → Records** 里，每条记录都由这几列定义：

| 字段                 | 含义                                           | 常见取值                                                 |
| -------------------- | ---------------------------------------------- | -------------------------------------------------------- |
| **Type**             | 记录类型，决定「回答什么形式的答案」           | A、AAAA、CNAME、MX、TXT、NS、SRV、CAA…                   |
| **Name**             | 记录挂在哪个名字上                             | `@`（= 根域 `example.com`）、`www`、`ssh`、`*`、`_dmarc` |
| **Content / Target** | 答案本身                                       | IP 地址、另一个域名、一段文本                            |
| **TTL**              | 解析结果被缓存多久                             | `Auto`（= 300 秒）、60 秒 ~ 1 天                         |
| **Proxy status**     | Cloudflare 是否中转流量（**Cloudflare 独有**） | 🟠 Proxied（橙云）/ ⚪ DNS only（灰云）                    |

### Name 的写法约定

| 你填的 Name           | 实际生效的域名                   |
| --------------------- | -------------------------------- |
| `@`                   | `example.com`（zone apex，根域） |
| `www`                 | `www.example.com`                |
| `ssh`                 | `ssh.example.com`                |
| `*.api`               | `*.api.example.com`              |
| `_dmarc`              | `_dmarc.example.com`             |
| `example.com`（写全） | 也可以，Cloudflare 会自动识别    |

**长度限制**（官方）：单个 label ≤ 63 字符，完整 FQDN ≤ 253 字符。下划线 `_` 在 DNS 中合法，SRV / 验证记录常用。但为了兼容主机名和 TLS 证书，建议只用字母、数字、连字符（LDH 规则）。

---

## 3. 记录类型总览

Cloudflare 把记录分成三组：

| 分组            | 类型                                                                    | 能否开橙云（Proxy）      |
| --------------- | ----------------------------------------------------------------------- | ------------------------ |
| **IP 地址解析** | `A`、`AAAA`、`CNAME`                                                    | ✅ **只有这三类可以代理** |
| **邮件认证**    | `MX`、`DKIM`、`SPF`、`DMARC`                                            | ❌                        |
| **专用记录**    | `TXT`、`CAA`、`SRV`、`SVCB`/`HTTPS`、`PTR`、`SOA`、`NS`、`DS`、`DNSKEY` | ❌                        |
| **其他**        | `URI`、`NAPTR`、`SSHFP`、`TLSA`、`SMIMEA`、`CERT`                       | ❌                        |

DKIM、SPF、DMARC 在文档里单独成组，面板里的类型仍然是 **TXT**。没有单独的 SPF / DKIM / DMARC 类型。旧的 SPF 记录类型（类型号 99）已废弃。

> 官方原文：*Only A, AAAA, and CNAME records that serve HTTP or HTTPS traffic can be proxied. Other DNS record types cannot be proxied.*

每个域名**至少要有一条 IP 地址解析记录**（A / AAAA / CNAME），否则 Cloudflare 上的这个 zone 无法正常工作。

---

## 4. 逐类详解

### 4.1 A 记录 —— 域名 → IPv4

最基础、你最常用的一种。

| Type | Name  | Content        | Proxy status |
| ---- | ----- | -------------- | ------------ |
| A    | `@`   | `203.0.113.45` | 🟠 Proxied    |
| A    | `www` | `203.0.113.45` | 🟠 Proxied    |
| A    | `ssh` | `203.0.113.45` | ⚪ DNS only   |

**要点：**

- Content 填**源站 IP**。不能填 Cloudflare 的 anycast 地址，否则解析会异常。只做 HTTP 跳转、没有源站时，可以使用文档地址 `192.0.2.1`，见 4.15。
- **不支持简写 IPv4**：`1.1` 不会被当成 `1.0.0.1`，必须写完整四段。
- **同一个 Name 可以有多条 A 记录**，但橙云和灰云看到的不是同一件事：
  - **灰云**：权威应答返回这一整组 A 记录，顺序轮换。没有健康检查，已经挂掉的 IP 仍会出现在应答里。
  - **橙云**：访客拿到的是 Cloudflare anycast 地址，不是这些源站 IP。多条 A 是边缘回源时的多个源站。
- **同名只要有一条 A 或 AAAA 是橙云，该名字上其余 A/AAAA 也全部按橙云处理。** 不能在同一个主机名上「一条橙云做网站、另一条灰云做 SSH」。SSH 和网站要用两个名字，例如 `ssh` 与 `web`。
- A 和 AAAA 可以同名共存，也可以与 MX、TXT、CAA 共存。双栈站点推荐 A 和 AAAA 都配。

---

### 4.2 AAAA 记录 —— 域名 → IPv6

和 A 完全对称，只是答案是 IPv6。

| Type | Name | Content       |
| ---- | ---- | ------------- |
| AAAA | `@`  | `2001:db8::1` |

**要点：**

- Cloudflare 用 **RFC 5952 规范写法**存储：你填 `fe80::0:0:1`，它保存并返回 `fe80::1`。
- VPS 没有 IPv6 时只配 A 即可。默认开启的 **IPv6 Compatibility** 会向访客发布 Cloudflare 自己的 AAAA，IPv6 用户仍能打开橙云主机名，源站不必有 IPv6。
- **回源用的地址族不跟访客走。** 同名同时有橙云 A 和 AAAA 时，Cloudflare 回源优先 IPv4。只有橙云 AAAA、没有 A 时，IPv4 和 IPv6 访客都会被回源到 IPv6；源站没有在该地址上监听，两边都会 521/522。

---

### 4.3 CNAME 记录 —— 域名 → 另一个域名

用于「这个域名不指向 IP，而是指向另一个域名，跟着它走」。

| Type  | Name   | Content（Target）   | Proxy status                     |
| ----- | ------ | ------------------- | -------------------------------- |
| CNAME | `www`  | `example.com`       | 🟠 Proxied                        |
| CNAME | `blog` | `myblog.github.io`  | ⚪ DNS only                       |
| CNAME | `@`    | `cname.example.net` | 🟠 Proxied（靠 CNAME flattening） |

**CNAME 的三条硬规则：**

1. **排他性（最容易踩的坑）**
   同一个 Name 上，**CNAME 不能与任何其它记录共存**。
   - 已有 `A` 记录 → 无法再加同名 `CNAME`
   - 已有 `CNAME` → 无法再加同名 `A` / `AAAA` / `TXT` / `MX`
   原因来自 RFC 1034：一个名字一旦是 CNAME，就不允许再有其它类型的数据。

   根域是例外：Cloudflare 对 `@` 做 CNAME flattening 之后，根域 CNAME 可以和 MX、TXT、CAA 共存。A 与 AAAA、以及它们和 MX / TXT / CAA，本来就可以同名共存，这不是 CNAME 的例外。

2. **最终必须落到一个有 A/AAAA 的域名上**
   CNAME 可以套娃（`a → b → c`），但链条末端必须有有效的 A 或 AAAA。
   若末端没有 IP（**dangling CNAME**），Cloudflare 返回空响应（NODATA），看起来就像「记录没生效」。

3. **橙云不能跨 Cloudflare 账号 CNAME**
   橙云 CNAME 指向另一个 Cloudflare 账号里的域名 → **Error 1014: CNAME Cross-User Banned**。
   - 同一账号里跨 zone（`example.com` → `example.net`）是允许的。
   - 跨账号要让橙云生效，目标方需要使用 **Cloudflare for SaaS**。
   - 灰云 CNAME 不会在你这边的代理上弹出 1014。目标若本身是别的账号的橙云主机名，访客仍可能在对方边缘看到 1014 或证书错误。

**橙云 CNAME 的额外行为：** 查询这个名字上的其它类型（例如 TXT）不会跟到目标域。目标域上的 TXT 不会从你的名字返回。

**CNAME flattening（Cloudflare 特有机制）**

DNS 标准禁止根域（`example.com`）使用 CNAME。Cloudflare 用 *CNAME flattening* 绕过：它在权威服务器上先把 CNAME 一路解析到最终 IP，然后**直接返回 A/AAAA 而不是 CNAME**。

实际有三层，不要混成一个开关：

| 范围                          | 谁能用                                         | 能不能关           |
| ----------------------------- | ---------------------------------------------- | ------------------ |
| 根域 `@`                      | 所有套餐，默认开启                             | **不能关**         |
| 橙云 CNAME                    | 所有套餐。橙云本来就返回 anycast 地址          | 不能单独关掉扁平化 |
| 「Flatten all CNAME records」 | 付费套餐的 zone 级开关，主要影响**灰云** CNAME | 可以关             |
| 单条记录的 Flatten            | 付费套餐，只对灰云、非根域的 CNAME             | 可以关             |

这带来两个实用效果：

- 你可以在根域 `@` 上放 CNAME（Cloudflare Pages 的根域名就是这么工作的），并同时放 MX / TXT。
- 解析更快，少一次往返。

副作用：

- 第三方若靠「查你的 CNAME 记录」验证域名归属，扁平化后应答里没有 CNAME，验证会失败。根域验证改用 TXT。子域名验证失败时，在付费套餐里关掉 zone 级 **Flatten all**，或关掉这一条的 **Flatten**。
- **不能代理的 CNAME 目标**：Cloudflare 主动禁止一批 CNAME 开橙云（多为别家 CDN / DKIM 主机），例如 `dkim.amazonses.com`、`*.onmicrosoft.com`、`zmverify.zoho.com`、`dkim.intercom.io`、`acm-validations.aws` 等。这类记录必须灰云。

---

### 4.4 MX 记录 —— 邮件投递

决定「发往 `you@example.com` 的邮件该送到哪台邮件服务器」。

| Type | Name | Content                | Priority |
| ---- | ---- | ---------------------- | -------- |
| MX   | `@`  | `mx1.mailprovider.com` | `10`     |
| MX   | `@`  | `mx2.mailprovider.com` | `20`     |

**要点：**

- **Priority（优先级）数字越小越优先。** 发送方应先试数字更小的 MX；是不是立刻切到备机会取决于对方的重试策略。相同优先级可以并列，用来分担。
- MX 指向的主机名**必须有 A 或 AAAA 记录**。
- 这个主机名如果在 Cloudflare 上，**必须灰云**。SMTP、IMAP、POP3 不走普通 HTTP 代理。橙云会让邮件客户端连到 Cloudflare 地址，投递失败。
- MX 指向的名字若和某个橙云网站是同一个主机名，Cloudflare 会在 MX 应答里加上 `_dc-mx` 前缀，让邮件绕过代理、直接打到源站。`dig` 看到 `_dc-mx` 是这个改写，不是多出来的一条你要手删的记录。更干净的做法仍是单独用灰云的 `mail` 主机名。
- **MX 记录本身不能开橙云。**
- 根域可以靠 CNAME flattening 同时放 CNAME 和 MX。没有 flattening 时，根域 CNAME 与 MX 不能共存。
- 开启 **Email Routing** 后，MX（以及配套 SPF）由 Cloudflare 托管。它和自建邮件、空 MX 冲突。不用 Email Routing 时把它关掉。
- 域名不接收邮件时，配一条空 MX（RFC 7505），避免没有 MX 时邮件退回到根域的 A/AAAA：

| Type | Name | Content | Priority |
| ---- | ---- | ------- | -------- |
| MX   | `@`  | `.`     | `0`      |

  Content 是单个句点，优先级必须是 `0`。不要加空格，也不要加引号。

---

### 4.5 SPF / DKIM / DMARC —— 邮件反伪造（都是 TXT 形态）

不发信、也不收信时，配这三条：

| 记录 | Name     | Content              |
| ---- | -------- | -------------------- |
| TXT  | `@`      | `v=spf1 -all`        |
| TXT  | `_dmarc` | `v=DMARC1; p=reject` |
| MX   | `@`      | `.`（优先级 `0`）    |

`-all` 表示没有任何服务器被授权发信。`p=reject` 让收信方直接拒绝未通过验证的邮件。不发信的域名可以直接用 `reject`，不必先观察。

DKIM 只在你真的用某个服务发信、并且对方给了 selector 和公钥时再加。没有私钥的 DKIM 挡不住伪造。

**SPF**（谁能替你发信）

| Type | Name | Content       |
| ---- | ---- | ------------- |
| TXT  | `@`  | `v=spf1 -all` |

若确实用某个服务发信，例如 SendGrid：`v=spf1 include:sendgrid.net ~all`。

- 同一个 Name 上只能有**一条**以 `v=spf1` 开头的 TXT。多条会直接 PermError，收信方当成没有 SPF。
- `include`、`a`、`mx`、`redirect` 等机制合计最多 **10 次** DNS 查询。超过后 SPF 失败。

**DKIM**（给邮件加密码学签名）

| Type | Name            | Content                         |
| ---- | --------------- | ------------------------------- |
| TXT  | `s1._domainkey` | `v=DKIM1; k=rsa; p=MIGfMA0GCS…` |

Name 里的 `s1` 是 selector，由邮件服务商给出。公钥也用对方提供的原文，不要自己编。

**DMARC**（收信方遇到验证失败时该怎么办 + 收报告）

| Type | Name     | Content                                                  |
| ---- | -------- | -------------------------------------------------------- |
| TXT  | `_dmarc` | `v=DMARC1; p=none; rua=mailto:dmarc@reports.example.net` |

`p=` 取值：`none`（只观察）→ `quarantine`（进垃圾箱）→ `reject`（直接拒收）。**会发信的域名**先用 `none` 看几周报告，再收紧。

`rua` 必须是一个真能收信的邮箱。空 MX 的域名收不到报告，所以 `rua` 不要写回这个域自己。`rua` 的邮箱域和 DMARC 所在域不同时，邮箱域还要有一条 `_report._dmarc` TXT 授权接收（RFC 7489）。

> Cloudflare 提供 **Email Security Wizard**，比手写 TXT 更省事。开了 Email Routing 或 Email Sending 时，用它生成的 SPF，不要再留着 `v=spf1 -all`。

---

### 4.6 TXT 记录 —— 万能文本

用途：域名所有权验证、SPF/DMARC、站点归属证明、各种第三方服务校验。

| Type | Name              | Content                                |
| ---- | ----------------- | -------------------------------------- |
| TXT  | `@`               | `google-site-verification=xxxxxxxxxxx` |
| TXT  | `_acme-challenge` | `xxxxxxxxxxxxxxxx`（证书 DNS 验证）    |

**要点：**

- TXT 内容本质是「被双引号包裹的字符串」。Cloudflare 会在你没写引号时自动补上；**引号不成对**（如 `"this` 或 `"these" ones"`）会触发校验错误。抄进面板时不要自己再套一层引号。
- 在 Cloudflare 上 TXT 最常见的用途是 **SSL 证书域名验证（DCV）**。
- 单个 Name 下可以有多条 TXT（一条 SPF、若干条验证记录）。DMARC 在 `_dmarc` 下，不和根域 TXT 抢名字。SPF 仍然只能有一条。

---

### 4.7 CAA 记录 —— 限定谁能给你签证书

防止未被列出的 CA 给你的域名签发证书。

| Type | Name | Tag         | Value             |
| ---- | ---- | ----------- | ----------------- |
| CAA  | `@`  | `issue`     | `letsencrypt.org` |
| CAA  | `@`  | `issuewild` | `letsencrypt.org` |

**要点：**

- `issue` 管普通证书，`issuewild` 管通配符证书。存在 `issuewild` 时，通配符只看 `issuewild`，不再沿用 `issue`。没写 `issuewild` 时，`issue` 同时适用于通配符。
- **`cloudflare.com` 不是签发 CA，写进 CAA 不会授权 Universal SSL。** 边缘证书来自合作 CA。2026-10 官方示例里能 `dig` 到的是：
  - `letsencrypt.org`
  - `pki.goog`（常带参数 `cansignhttpexchanges=yes`）
  - `ssl.com`
  - `sectigo.com`
  这份名单官方写明并不完整，会随运营调整增减。
- **Universal SSL 开着时**，你只要添加任意 CAA，Cloudflare 会自动补上当前合作 CA 的 `issue` 和 `issuewild`。这些自动记录**不出现在面板里**，`dig CAA` 能看到。因此在 Cloudflare DNS 上，不必为了 Universal SSL 去手写 `cloudflare.com`。
- **Advanced Certificate 不会自动补 CAA。** 用了哪种 CA，就要显式允许哪种 CA，`issue` 和 `issuewild` 都要写到。
- 自动补上的记录只存在于 Cloudflare 的权威应答里。把同一份 CAA 抄到别的 DNS 服务商时，必须自己写上当时的合作 CA，否则边缘证书会签不出来。
- 常见 tag 还有 `iodef`（违规签发时向某邮箱报告）。
- CAA 会沿 CNAME 链生效。你的主机名 CNAME 到一个 CAA 更严的域时，以目标域的 CAA 为准。

---

### 4.8 SRV 记录 —— 唯一「带端口」的常见记录

SRV 是**少数能在 DNS 里携带端口**的记录类型，用于 VoIP、即时通讯、Minecraft 服务器等客户端主动查询 SRV 的场景。

| Type | Name              | Priority | Weight | Port    | Target               |
| ---- | ----------------- | -------- | ------ | ------- | -------------------- |
| SRV  | `_xmpp._tcp`      | `10`     | `5`    | `5223`  | `server.example.com` |
| SRV  | `_minecraft._tcp` | `5`      | `50`   | `25565` | `mc.example.com`     |

**要点：**

- Name 必须写成 `_服务._协议` 形式（`_sip._tcp`、`_minecraft._udp`…），下划线是必需的。
- `Priority` 越小越优先；`Weight` 在同优先级内做加权分配。
- **关键限制：SRV 只在客户端主动查询 SRV 时才起作用。** 浏览器不会查 SRV，SSH 不会查 SRV。所以 **SRV 不能用来实现「域名 → 10080 端口」的网页访问**，也不能用来改 SSH 端口。
- SRV 不能开橙云。

---

### 4.9 HTTPS / SVCB 记录 —— 提前告诉客户端怎么连

较新的记录类型（RFC 9460），让客户端在第一次 HTTP 请求前就知道「该用 HTTP/3、该用哪个 ALPN、该连哪个端口」。

| Type  | Name | Content         |
| ----- | ---- | --------------- |
| HTTPS | `@`  | `1 . alpn="h3"` |

**Cloudflare 的行为（容易困惑，重点）：**

- **橙云 Name**：只要开了 Universal SSL，并且启用了 HTTP/2 或 HTTP/3，Cloudflare **自动动态生成** HTTPS 记录。你手动加的 HTTPS 记录在橙云 Name 上**不会被返回**，Cloudflare 用自己的。
- **关掉 Universal SSL 后**，橙云 Name 上不再自动生成 HTTPS 记录，即使你有自定义证书或 Advanced Certificate。要恢复自动生成，重新打开 Universal SSL；真正用于连接的证书仍按证书优先级，自定义证书可以盖过 Universal SSL。
- **灰云 Name**：你可以手动加 HTTPS 记录，Cloudflare 会正常返回 —— **但前提是同名下的所有记录都必须是灰云**。

  | 情况                            | 结果                   |
  | ------------------------------- | ---------------------- |
  | `A`（灰云）+ `HTTPS`（同名）    | ✅ HTTPS 记录会被返回   |
  | `AAAA`（橙云）+ `HTTPS`（同名） | ❌ HTTPS 记录不会被返回 |

---

### 4.10 NS 记录 —— 子域委派

告诉解析器：「这个子域名的 DNS 由别家的服务器回答」。

| Type | Name   | Content            |
| ---- | ------ | ------------------ |
| NS   | `blog` | `ns1.otherdns.com` |
| NS   | `blog` | `ns2.otherdns.com` |

**要点：**

- **绝大多数情况你不需要手动加 NS。** 你域名在 Cloudflare 的权威 NS（`xxx.ns.cloudflare.com`）由后台 **Nameservers** 专区管理，不在记录表里。
- 只有两种场景需要手动加 NS：① **子域委派**（把 `blog.example.com` 交给别家托管）；② **子域 setup**（subdomain setup）。
- 数量限制：Cloudflare 每个委派名最多 **10 条 NS**，超过会被拒绝；最佳实践是 **≤ 7 条**（RFC 1912）。
- 一旦某子域被 NS 委派出去，**该子域下所有记录都由别家决定**，你在 Cloudflare 里给它加 A 记录是不生效的。

---

### 4.11 SOA 记录 —— 区域权威信息

存管理员邮箱、序列号、刷新/重试/过期时间等。

- **你不需要创建它。** 用 Cloudflare 权威 DNS 时，SOA 自动生成。
- Enterprise 用户可覆盖 SOA 参数（`MNAME`、`RNAME`、`Serial`、`Refresh`、`Retry`、`Expire`、`Record TTL`、`Minimum TTL`）。
- 查询 SOA 时返回的 TTL 是 `Record TTL` 与 `Minimum TTL` 中**较小**的那个。`Minimum TTL` 本身是负缓存时间（RFC 2308）。

---

### 4.12 PTR 记录 —— 反向解析（IP → 域名）

「这个 IP 对应的域名是什么」，邮件服务器几乎必需（很多收件方会做 PTR 校验，没有 PTR 的邮件容易进垃圾箱）。

- PTR **不属于正向 zone**，它挂在反解 zone（`in-addr.arpa`）里。
- Cloudflare 支持 **Reverse Zones**，但实践中 **PTR 通常由你的 VPS 服务商在其控制台设置**（在 Vultr / Linode / 阿里云后台填 "Reverse DNS / rDNS" 即可），而不是在 Cloudflare 里配。
- 你的 VPS 要发邮件的话，把 PTR 设成 `mail.example.com` 并与 HELO 一致，是提升送达率的关键一步。

---

### 4.13 DS / DNSKEY —— DNSSEC

给 DNS 回答加密码学签名，防止 DNS 应答被篡改。

- **不要手动加这两条。** Cloudflare 的做法是：在 **DNS → DNSSEC** 里点一下 Enable，Cloudflare 自己生成 KSK/ZSK，你只需把它给出的 **DS 记录**填到**注册商**那里。
- 子域已经用 NS 委派出去、并且子域自己做了 DNSSEC 时，才在 Cloudflare 里给这个子域加 **DS**。
- 手动添加 DNSKEY 只出现在多签名者（multi-signer）等专门方案里。普通「Cloudflare 做权威并签名」不要手写 DNSKEY。

---

### 4.14 其他类型

Cloudflare 还支持较少用到的：`URI`、`NAPTR`、`SSHFP`、`TLSA`、`SMIMEA`、`CERT`。

- **TLSA**：配合 DANE 使用，绑定「DNS 里声明的证书」与 TLS 连接，用于邮件/HTTPS 的额外校验。
- **SSHFP**：声明 SSH 主机密钥指纹，`ssh` 客户端开启 `VerifyHostKeyDNS` 时可自动校验。
- 一般个人 VPS 场景用不到，知道存在即可。

---

### 4.15 容易混淆的两个「不是标准记录」的概念

**① ALIAS / ANAME**

很多 DNS 服务商（AWS Route 53、DNSMadeEasy 等）提供 ALIAS/ANAME，用来在根域实现「像 CNAME 一样指向域名，但又能和 MX 共存」。
**Cloudflare 不提供 ALIAS 类型** —— 它用 **CNAME flattening** 达到同样效果，所以你在 Cloudflare 里直接在 `@` 上放 CNAME 就行。

**② URL 转发**

Cloudflare 的 DNS 记录类型里**没有 Redirect**，也**不做域名伪装**（地址栏继续显示你的域名、页面内容来自别处）。官方提供的是 HTTP 跳转，浏览器地址会变成目标 URL。

做法：

1. 给主机名一条橙云 A 或 CNAME。没有真实源站、只做跳转时，A 记录填文档地址 `192.0.2.1`（IPv6 用 `100::`），并保持橙云。这是占位地址，流量由跳转规则处理，不会回源。它不是 Cloudflare 的 anycast 地址。
2. 在 **Rules → Redirect Rules**（Single Redirects 或 Bulk Redirects）里配置 301/302。

跳转只作用于 HTTP/HTTPS，不能用于 SSH 或非标端口。主机名不是橙云时，Redirect Rule 不会生效。

---

## 5. Cloudflare 独有维度：Proxy status（橙云 / 灰云）

这是 Cloudflare 区别于普通 DNS 服务商的关键开关，也决定了非标端口能不能走代理。

|                                      | 🟠 **Proxied（橙云）**            | ⚪ **DNS only（灰云）**                  |
| ------------------------------------ | -------------------------------- | --------------------------------------- |
| 解析返回的 IP                        | Cloudflare 的 anycast IP         | 你 VPS 的真实 IP                        |
| 这条记录是否暴露源站 IP              | 当前应答不暴露                   | 暴露                                    |
| DDoS 防护 / WAF / CDN 缓存           | ✅                                | ❌                                       |
| Cloudflare 边缘证书（Universal SSL） | ✅ 自动                           | ❌ 不生效                                |
| TTL                                  | 固定 `Auto` = 300 秒，**不可改** | 可自定义                                |
| 支持端口                             | 仅下表列出的 HTTP/HTTPS 端口     | **任意端口**                            |
| 适用                                 | 网站、API、反代                  | SSH、游戏服、数据库、Plex、任意非标端口 |

橙云只隐藏**这一条主机名当前的 DNS 应答**。同 zone 里其它灰云记录、旧缓存、邮件头，仍可能把同一台机器的 IP 公开。

### 官方支持的代理端口

**HTTP 端口**

```
80, 8080, 8880, 2052, 2082, 2086, 2095
```

**HTTPS 端口**

```
443, 2053, 2083, 2087, 2096, 8443
```

**默认会缓存的端口：** `80`、`8080`、`443`。

**默认关闭缓存的端口**（能代理，但 Cloudflare 不缓存内容；Enterprise 可用 Cache Rule 打开缓存）

```
2052, 2053, 2082, 2083, 2086, 2087, 2095, 2096, 8880, 8443
```

### 非标端口（如 10080）怎么办

官方给出两条路：

1. **把该 Name 改成灰云**，绕过 Cloudflare 直连源站 → 访问 `http://web.example.com:10080`。
2. **配置 Spectrum 应用**，Spectrum 支持任意 TCP/UDP 端口 —— 但 **Spectrum 全端口仅 Enterprise 套餐提供**。

另外注意：Cloudflare 付费套餐的 WAF 有一条「Anomaly:Port - Non Standard Port (not 80 or 443)」规则，默认关闭；开启后会拦截 80/443 之外的 HTTP 请求。

Free / Pro / Business 上，边缘大约 **100 秒**没有从源站读到新数据就会返回 **524**。源站 Nginx 的 `proxy_read_timeout` 改不了这个上限。更长的 Proxy Read Timeout 是 Enterprise 的设置。

### 其它代理限制

- **只有承载 HTTP/HTTPS 流量的 A / AAAA / CNAME 可以代理**，其它类型一律不行。
- **同名 A/AAAA 混用橙云和灰云时，整组都按橙云处理。**
- **NTLM / Kerberos / Microsoft Integrated Windows Authentication 与橙云不兼容**（它们在 TCP 连接层认证，而 Cloudflare 不保证同一客户端复用同一条回源 TCP 连接），会造成反复弹认证框。
- **新加入 Cloudflare 的域名处于 pending 状态（最长 24 小时）**，这期间**所有记录都是灰云**，返回的是源站真实 IP。激活后才可能变橙云。官方建议激活后**在主机商处更换一次源站 IP**，避免 onboarding 期间 IP 泄露。
- 开通了 **Cloudflare China Network** 的域名，在中国数据中心里只代理 **80 和 443**。这是该产品的限制，不是「国内访客访问普通 Cloudflare 站点只能用这两个端口」。

---

## 6. 记录之间的冲突与优先级规则

| 规则                                       | 说明                                                                                                                                                  |
| ------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| **CNAME 排他**                             | 同名 CNAME 不能与任何其它记录共存，加不上会报记录同名冲突。根域靠 flattening 可以与 MX、TXT、CAA 共存。                                               |
| **A / AAAA / MX / TXT / CAA 可以同名共存** | 多条 A、A+AAAA、A+MX+TXT 都合法。                                                                                                                     |
| **同名 A/AAAA 的橙云是整组生效的**         | 有一条是橙云，其余 A/AAAA 也按橙云处理。                                                                                                              |
| **多条同名灰云 A = 一组地址、顺序轮换**    | 没有健康检查。橙云多条 A 是多个回源地址，访客看不到这些 IP。                                                                                          |
| **精确记录优先于通配符**                   | 存在精确记录或委派时，`*` 不对该名字及其下级生效。                                                                                                    |
| **NS 委派覆盖子域**                        | 被委派的子域下，Cloudflare 里的记录不再被查询。                                                                                                       |
| **同名混合橙云/灰云会影响 HTTPS 记录**     | 手动 HTTPS 记录要求同名所有记录都是灰云。                                                                                                             |
| **MX 依赖灰云的 A/AAAA**                   | MX 目标主机必须有地址记录；在 Cloudflare 上该主机名要灰云。                                                                                           |
| **根域放 CNAME 靠 flattening**             | 根域 flattening 始终开启，因此根域可以同时有 CNAME 和 MX。                                                                                            |
| **记录体积上限**                           | 单条记录 wire format ≤ 4096 字节；同名同类型记录内容总长 ≤ 8192 字符。                                                                                |
| **记录条数上限**                           | 2024-09-01 之后创建的 Free zone 为 200 条；更早的 Free zone 为 1000 条。Pro / Business / Enterprise 为 3500 条。Enterprise 需要更多时可联系客户团队。 |

---

## 7. TTL 详解

| 记录状态                    | 可选 TTL 范围           | Auto 的值 |
| --------------------------- | ----------------------- | --------- |
| 🟠 Proxied                   | **不可修改**，固定 Auto | 300 秒    |
| ⚪ DNS only（非 Enterprise） | 60 秒 ~ 1 天            | 300 秒    |
| ⚪ DNS only（Enterprise）    | 30 秒 ~ 1 天            | 300 秒    |

**为什么橙云不能改 TTL？** 因为橙云返回的是 Cloudflare anycast IP，可能随时变化，300 秒上限保证变更快速生效。

**实操建议：**

- 平时：`Auto`（300 秒）就够。
- **准备换 VPS / 换 IP 之前**：提前几小时把灰云记录的 TTL 降到 60 秒，切换后旧缓存很快过期，迁移窗口短。
- 稳定不变的记录（如 DKIM、SPF）：可以设长 TTL 减少查询。
- 注意：改完记录后，**你本机 DNS 缓存可能比 TTL 更久**才刷新。Windows 用 `ipconfig /flushdns`。macOS 用 `sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder`。Linux 若使用 systemd-resolved，用 `resolvectl flush-caches`。

> **Nameserver TTL 是另一个独立设置**，只影响 Cloudflare 分配的 NS / 自定义 NS，不在记录表里调。

---

## 8. 通配符记录（Wildcard）

适合「几百个子域名都指向同一台机器」的多租户场景。

| Type  | Name    | Content        | Proxy status |
| ----- | ------- | -------------- | ------------ |
| A     | `*`     | `203.0.113.45` | 🟠 Proxied    |
| CNAME | `*.www` | `example.com`  | 🟠 Proxied    |

**四条规则：**

1. **只有第一个 label 的 `*` 才是通配符。** `subdomain.*.example.com` 里的 `*` 被当作字面字符。`*.*.example.com` 也只有第一个 `*` 是通配符。
2. **通配符默认是多级的。** `*.example.com` 同时覆盖 `abc.example.com` 和 `123.abc.example.com`。
3. **精确记录优先。** 若 `abc.example.com` 有自己的记录或委派，通配符对它无效，对它下面的层级也无效。
4. 通配符可橙云可灰云，**所有套餐都支持**。

**隐式父名和 NS 类型有关。** 只在 `123.abc` 上有记录、`abc` 本身没有任何记录时：标准 NS 仍用 `*.example.com` 回答 `abc.example.com`；Advanced nameservers 按 RFC 4592，不再用这条通配符回答 `abc.example.com`。

**证书只覆盖一层。** Universal SSL 的通配符是 `*.example.com`，只匹配一个 label。DNS 能把 `123.abc.example.com` 解析到 Cloudflare，边缘证书却不包含这个名字，HTTPS 会失败。更深的名字要单独放进证书，或为那一层另做 `*.abc`。

**CNAME setup（partial）的签发方式**：这种接入下 Cloudflare 不会自动为通配符签发证书。Universal 证书要用 TXT DCV；Advanced 证书优先用 Delegated DCV，否则**证书里每个 hostname 都要单独放一个 DCV token**（`example.com` + `*.example.com` = 2 个 token）。

---

## 9. 记录注释与标签（Comments / Tags）

不影响解析，纯粹给你自己看的元数据，记录多了时非常好用（可按标签过滤）。

|                     | Free | Pro / Business | Enterprise |
| ------------------- | ---- | -------------- | ---------- |
| Comment 字数        | 100  | 500            | 500        |
| 每条记录 Comment 数 | 1    | 1              | 1          |
| Tags 是否可用       | ❌    | ✅              | ✅          |
| 每记录 Tag 数       | —    | 20             | 20         |
| Tag 名 / 值字数     | —    | 32 / 100       | 32 / 100   |

Tag 格式是 `name:value`，name 不区分大小写、只能含字母数字 `-` `_`。值可以是注释允许的字符，但不能换行。导入导出时 `cf-` 开头的保留 tag 可控制 Cloudflare 配置。Comment 同样不能包含换行。

---

## 10. 排错速查表

| 现象                                    | 最可能原因                                                 | 处理                                                                                   |
| --------------------------------------- | ---------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| 加了记录但 `ping` 不通                  | 域名 NS 没指向 Cloudflare                                  | 去注册商改 NS 为后台给出的 `xxx.ns.cloudflare.com`                                     |
| 记录显示橙云但 `dig` 返回源站 IP        | zone 还在 pending（最长 24h）                              | 等激活；期间全部按灰云处理                                                             |
| 加同名记录报同名冲突                    | CNAME 排他性                                               | 删掉同名的另一条记录。根域 CNAME 与 MX/TXT 可以共存                                    |
| 想让同名一条橙云、一条灰云              | 同名 A/AAAA 整组按橙云处理                                 | 拆成两个主机名                                                                         |
| SSH 连不上                              | `ssh` 记录被设成橙云                                       | 改成 **DNS only**                                                                      |
| 网页 521 / 522                          | 橙云 + 非标端口，源站端口没开，或只有 AAAA 且源站没有 IPv6 | 改灰云 / 反代到 443 / 检查安全组 / 补上可用的 A 记录                                   |
| 524                                     | 源站超过约 100 秒没有返回新数据（Free / Pro / Business）   | 缩短源站处理时间；更长超时只在 Enterprise 可调                                         |
| 525 SSL handshake failed                | Cloudflare 与源站的 TLS 握手失败                           | 确认 443 在听、证书文件可读、Cloudflare IP 没被防火墙丢掉                              |
| 526 Invalid SSL certificate             | Full (strict) 不接受源站证书                               | 换 Origin CA 或公共 CA，模式保持 Full (strict)                                         |
| Too many redirects 重定向循环           | Flexible 模式 + 源站强制 HTTPS                             | 模式改 Full (strict)，源站装 Cloudflare 信任的证书                                     |
| 网页能开但 WebSocket 断，或普通请求异常 | `Connection` 被写成固定的 `upgrade`                        | 用 `map`，只在 `$http_upgrade` 非空时设为 `upgrade`                                    |
| 日志里的客户端 IP 全是 Cloudflare       | 用了 `$remote_addr`，且没配 `real_ip`                      | 读 `CF-Connecting-IP`，或按 Cloudflare IP 段配置 `real_ip`                             |
| CNAME 指向别的 Cloudflare 账号报 1014   | 橙云跨账号 CNAME                                           | 同账号跨 zone 可以。跨账号用 Cloudflare for SaaS，或改为灰云 / 直接写对方源站的 A 记录 |
| CNAME 加了但完全解析不出                | dangling CNAME（末端无 A/AAAA）                            | 确认目标域名有有效 IP 记录                                                             |
| 第三方域名验证失败                      | CNAME 被扁平化，应答里没有 CNAME                           | 付费套餐关掉 Flatten all，或关掉这一条的 Flatten。根域 flattening 关不掉，验证改用 TXT |
| 子域记录改了没反应                      | 该子域被 NS 委派出去了                                     | 到实际托管方改，或在 Cloudflare 删掉 NS                                                |
| `dig MX` 出现 `_dc-mx`                  | MX 指向了橙云主机名                                        | 这是让邮件绕过代理的改写。邮件主机名应单独使用灰云 A/AAAA                              |
| 改了记录但本机还是旧 IP                 | 本地 DNS 缓存                                              | `ipconfig /flushdns`；macOS 再执行 `sudo killall -HUP mDNSResponder`                   |
| 邮件进垃圾箱                            | 缺 SPF/DKIM/DMARC，或 VPS 无 PTR                           | 发信用服务商给出的三件套；在主机商设 rDNS，并与 HELO 一致                              |
| 不发信仍被伪造                          | 只有空 SPF 或假 DKIM，没有 DMARC `reject`                  | `v=spf1 -all` + DMARC `p=reject` + 空 MX                                               |

---

## 11. 常用验证命令

```powershell
# Windows PowerShell
Resolve-DnsName example.com -Type A
Resolve-DnsName ssh.example.com -Type A
Resolve-DnsName example.com -Type MX
Resolve-DnsName _dmarc.example.com -Type TXT
Resolve-DnsName example.com -Type CAA
ipconfig /flushdns
```

```bash
# Linux / macOS
dig +short example.com A
dig +short ssh.example.com A
dig +short example.com MX
dig +short TXT _dmarc.example.com
dig +short CAA example.com

# 问该 zone 的权威 NS。名字在 Cloudflare 后台 Nameservers 卡片里，下面只是例子
dig example.com A @ada.ns.cloudflare.com

# 1.1.1.1 是递归解析器，应答可能来自它自己的缓存
dig example.com A @1.1.1.1

dig +trace example.com            # 从根开始追踪委派

nc -vz ssh.example.com 22
nc -vz web.example.com 10080
curl -I https://web.example.com
```

macOS 清缓存：

```bash
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

**判断橙云还是灰云**：解析结果落在 Cloudflare 地址段 → 橙云；返回你的 VPS IP → 灰云。`104.16.0.0/12`、`172.64.0.0/13` 只是常见例子，以 <https://www.cloudflare.com/ips/> 的完整名单为准。

---

## 12. 一页速记（可直接抄的记录模板）

面板里的 TXT 不要自己加引号，Cloudflare 会补。MX 的内容就是一个点。

```
# 主站
A      @              203.0.113.45   🟠 Proxied    Auto
A      www            203.0.113.45   🟠 Proxied    Auto

# 管理 / 非标服务（必须灰云）
A      ssh            203.0.113.45   ⚪ DNS only   Auto
A      panel          203.0.113.45   ⚪ DNS only   Auto

# 不发信、不收信
TXT    @              v=spf1 -all                                        Auto
TXT    _dmarc         v=DMARC1; p=reject                                 Auto
MX     @              .                              priority 0           Auto

# 源站若用 Let's Encrypt。Universal SSL 开着时，Cloudflare 会自动补合作 CA
# （letsencrypt.org / pki.goog / ssl.com / sectigo.com 等），面板里看不到。
# 不要写 cloudflare.com。Advanced Certificate 不会自动补，须按实际 CA 写全 issue 与 issuewild。
CAA    @              issue      letsencrypt.org                         Auto
```

会发信时：删掉 `v=spf1 -all` 和空 MX，改成服务商给出的 SPF、DKIM、MX，DMARC 先用 `p=none`。`rua` 放到一个能收信的其它域。
