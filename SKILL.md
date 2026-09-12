---
name: dsh-mobile-remote
description: Turn a phone (iPhone/Android) into a remote console for DeepSeek Harness Desktop on Windows — watch agent tasks live, dispatch new tasks, answer agent questions, and receive push notifications when a task finishes — over home Wi-Fi, 5G, or a Cloudflare/Tailscale tunnel. Use when the user wants to observe and command their desktop agent harness from a phone, wants a "Codex mobile"-like experience, needs phone push notifications for long-running agent tasks, or is troubleshooting phone access (page won't open, address keeps changing, remote access outside home).
whenToUse: 用户想让手机远程观察与指挥电脑上的 DSH / 智能体：实时看任务进度、下任务、回答提问、任务完成推到手机；或要求"类似 Codex 手机版"的体验；或手机端打不开、访问地址老变、需要外网（5G）访问、需要固定网址时使用。
---

# DSH 手机远程（dsh-mobile-remote）

把 Windows 上的 **DeepSeek Harness Desktop** 变成可用手机遥控的 agent：
**实时看进度 → 下任务 → 收完成通知**，家里 WiFi、外出 5G、换网络都能用。

> 本技能来自一次真实落地（iPhone 12 Pro Max + Windows 11 + DSH Desktop 0.7.2 → 0.8.0），
> 文中所有"陷阱"都是实际踩过的坑。

## 0. 先理解三层架构

| 层 | 是什么 | 位置/端口 |
|---|---|---|
| **手机网关** | DSH Desktop **内置**能力（`LanMobileBridge`）：配对鉴权 + 手机专用页面（DSH Mobile）+ 会话实时流（SSE）+ 受限 RPC | Electron 主进程，固定 `0.0.0.0:43127` |
| **接入路径** | ①局域网 ②公网隧道（内置 cloudflared）③Tailscale 固定地址 | 见下 |
| **通知层** | DSH 的 Codex hooks 桥触发脚本 → Bark / ntfy 推送到手机 | `@deepseek-ai/dsh-hooks-codex` |

三条接入路径的取舍：

| 路径 | 地址形态 | 手机要装 App？ | 换网络/5G | 稳定度 |
|---|---|---|---|---|
| 局域网 | `http://<电脑IP>:43127` | 否 | ❌ 必须同一 WiFi；**IP 会变** | 低（IP 漂移） |
| **公网隧道**（推荐） | `https://xxx.trycloudflare.com` | **否** | ✅ 任意网络 | 中（链接每次重启变，但可自动推送） |
| Tailscale | `http://100.x.y.z:43127` | **要**（中国区 App Store 无此 App） | ✅ 任意网络 | 高（地址永久） |

**结论**：面向国内用户，**公网隧道 + 链接自动推送**是性价比最高的方案；Tailscale 仅适合能装到 App 的用户。

## 1. 部署（15 分钟）

### 1.1 打开手机配对窗口
电脑 DSH Desktop：点侧边「**连接手机**」按钮，或按 **Ctrl+Shift+M** → 弹出「连接移动设备」二维码窗口。

### 1.2 选模式
- **WiFi连接模式**（默认）：二维码为 `http://<电脑IP>:43127/pair?token=…`
- **互联网连接模式**：切到该模式建立 cloudflared 快速隧道，二维码为 `https://xxx.trycloudflare.com/pair?token=…`
  （首次会自动下载 cloudflared；可**预置** `%APPDATA%\dsh-desktop\bin\cloudflared.exe` 免下载）

### 1.3 手机配对
iPhone：**相机扫码**（或 Safari 手打地址）→ 页面「重新连接」→ **电脑上点「允许」** → 进入 DSH Mobile。
> iOS 必须用 **Safari**；地址若手打必须带 `http://`（写成 https 必失败）。

### 1.4 手机端能力
会话列表 / 工作区切换 / 新会话 / **实时流**（思考、工具调用、逐字输出）/ 任务清单进度 /
回答 agent 提问 / 停止生成 / 会话设置（模型、Preset、思考强度）。
Safari「分享 → 添加到主屏幕」可当 App 用。

### 1.5 装通知（可选但强烈建议）
```powershell
# 1) 复制脚本到固定目录（示例：D:\dsh）
# 2) 配置推送 key
notepad scripts\ds-phone-notify.example.json   # 填 barkKey（或 ntfyTopic）
# 3) 把 hooks.json 的路径改成实际路径，然后挂到 profile：
#    <DSH_HOME>\profiles\web\cordis.patch.yml 追加：
#    - insert:
#        - id: hooks-codex
#          name: '@deepseek-ai/dsh-hooks-codex'
#          config:
#            configPath: <绝对路径>/ds-hooks.json
```
Bark：iPhone 装免费 Bark → 首页「Key」一栏那串 ~22 位字符即 key（**不是** URL 里的域名，也不是 64 位哈希）。

### 1.6 装监视器（解决"地址老是变"）
`scripts/ds-mobile-bridge.ps1` 常驻做四件事：
1. 检测 DSH Desktop 重启 → **自动重开隧道**（最多重试 4 次）
2. 隧道链接变化 → **推送新链接到手机**
3. **局域网 IP 变化 → 也推送**（这是"突然打不开"的头号原因）
4. 维护 `ds-mobile-url.txt`（通知里的直达链接取自它）

自启（二选一，建议都做）：
- 注册表：`HKCU\Software\Microsoft\Windows\CurrentVersion\Run` 加 `DSHMobileBridge`
- 启动文件夹放一个隐藏启动的 `.cmd`

### 1.7 Tailscale（可选，能给固定地址时）
```powershell
# 电脑端（管理员）
& "C:\Program Files\Tailscale\tailscale.exe" up
& "C:\Program Files\Tailscale\tailscale.exe" ip -4     # 得到 100.x.y.z
# 让网关放行 100.64/10（否则手机被 403 —— 见陷阱）
powershell -File scripts\ds-patch-cgnat.ps1
```
手机端必须装**真正的** Tailscale 客户端并登录同一账号；**中国区 App Store 没有该 App**。
> 注意：某些 App（如 Termius）会内置 Tailscale 客户端并在 tailnet 里注册一个节点
> （版本号带 `-dev`、主机名形如 `<vendor>-node-<hex>`），但**它只能自己用，不能给 Safari 提供全机通道**。

## 2. 排错手册（按出现频率排序）

| 症状 | 真正原因 | 处理 |
|---|---|---|
| 手机"网页无法显示"、`ERR_CONNECTION_CLOSED` | 用了 `https://` 或 Chrome；或网关守卫 403 | **Safari + 手打 `http://`**；Tailscale 场景检查 CGNAT 补丁 |
| 昨天还好、今天打不开 | **电脑局域网 IP 变了**（换 WiFi/网段/DHCP） | 用监视器推送的新地址；或改用隧道/Tailscale |
| 打开后长时间转圈/骨架屏 | 隧道延迟高（实测 1.2–4s/请求） | 耐心等；或让手机走代理；或改用 Tailscale |
| 局域网地址"也打不开"了 | **隧道开着时局域网地址会 302 跳到公网地址** | 要么关隧道用局域网，要么统一用公网地址 |
| 手机节点在 tailnet 显示 offline | **iOS 挂起 VPN / 切网后未重连** | 打开 Tailscale App 唤醒；开启"按需连接" |
| 隧道建立失败 | 电脑连不上 Cloudflare（国内常见） | 用 `--protocol http2` 试；或让电脑走代理；或改 Tailscale |
| 配对窗口不弹 | 手机侧触发的 `onReconnectRequested` 未生效 | 电脑上按 **Ctrl+Shift+M** 手动打开再「允许」 |
| 改了 `cordis.patch.yml` 不生效 | 路径/格式错 | profile 的 `patchReload: live` 会热重载；查 `ds-mobile-bridge.log` 与 harness 日志 |

### 陷阱清单（务必遵守）

1. **PowerShell 5.1 不支持 `-NoProxy`** → 监视器所有 HTTP 调用静默失败。**统一用 `curl.exe --noproxy "*"`**。
2. **`.ps1` 必须 UTF-8 with BOM**，否则 5.1 按 GBK 解码，中文直接语法报错。
3. 网关入口守卫 **只放行 RFC1918**；Tailscale `100.64/10` 会被 403，必须打补丁（**应用升级会覆盖 → 重打 + 重启**）。
4. 监视器选地址**必须只取"有默认网关"的网卡**，否则会选中 WSL/Hyper-V/Wi-Fi Direct 的 `172.x/169.254` 假地址。
5. 手机配对授权在**内存**中，DSH Desktop 重启后要重新「重新连接 + 允许」。
6. 切模式（WiFi↔互联网）前**必须先断开已连手机**，否则接口返回 409。
7. 通知脚本要**保证失败也不影响 agent**：任何异常都 `exit 0`、不阻塞、不输出决策 JSON。

## 3. 验证清单（部署完逐条打勾）

```powershell
# 网关在监听
Get-NetTCPConnection -LocalPort 43127 -State Listen
# 未配对时返回重连页
curl.exe -s -o NUL -w "%{http_code}" --noproxy "*" http://127.0.0.1:43127/
# 已授权设备数
curl.exe -s --noproxy "*" http://127.0.0.1:43127/desktop/status      # {"connected":true}
# 待批准请求
curl.exe -s --noproxy "*" http://127.0.0.1:43127/desktop/pending     # {} 表示没有卡住
# 隧道状态
curl.exe -s --noproxy "*" http://127.0.0.1:43127/desktop/tunnel/status
# 监视器日志
Get-Content <路径>\ds-mobile-bridge.log -Tail 20
```

## 4. 文件一览

| 文件 | 作用 |
|---|---|
| `scripts/ds-mobile-bridge.ps1` | 常驻监视器：自动开隧道、地址变化推送、URL 缓存 |
| `scripts/ds-phone-notify.ps1` | 通知脚本：Bark/ntfy 推送 + 直达链接 + 本地日志 |
| `scripts/ds-hooks.json` | Codex hooks 配置（Stop / PostToolUse[ask_user_question]） |
| `scripts/ds-phone-notify.example.json` | 推送凭据模板（barkKey / ntfyTopic） |
| `scripts/ds-patch-cgnat.ps1` | 让网关放行 Tailscale 100.64/10 网段（应用升级后需重打） |
| `references/setup-guide.zh.md` | 面向用户的图文步骤（配对、模式切换、通知、固定地址） |
| `references/troubleshooting.zh.md` | 一页维护手册（打不开时照做） |

## 5. 安全提示

- 网关拥有**文件读写 + 命令执行**能力，务必只在可信网络暴露；公网隧道 URL 含一次性配对 token（5 分钟有效）+ 电脑端人工「允许」。
- 不要把 `ds-phone-notify.json`（含推送 key）提交到公开仓库；`.gitignore` 已排除。
- **开源/分享前务必自查**：示例配置里绝不能带真实推送 key；个人地址（Tailscale IP、隧道链接、局域网 IP）、
  Windows 用户名、账号名、私有目录路径都要替换成占位符。**一旦推错，仅提交一个"修复"是不够的**——
  密钥仍留在 git 历史里，必须 `git commit --amend`（或 filter-repo）后强推，并考虑轮换该密钥。
- 曾用于收尾的一个隐患：早期版本另起过**无鉴权的 `dsh web`（0.0.0.0:3080）**，同一 WiFi 任何设备可直接控制电脑——发现后应立即停止。
