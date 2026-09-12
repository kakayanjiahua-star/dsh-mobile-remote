# 手机连接 DSH Desktop 操作指南（iPhone 12 Pro Max）

> DSH Desktop 0.7.2 已**内置手机遥控功能（DSH Mobile）**，无需另装 App、无需改代码。
> 用手机浏览器即可：实时观看智能体干活、发消息/派新任务、看任务清单、回答问题、停止生成，
> 还能"添加到主屏幕"当 App 用——体验类似 Codex 的手机端。

- **在家（同一 WiFi）**：走「WiFi连接模式」，即连即用。
- **在外面（4G/5G 或异地 WiFi）**：走「互联网连接模式」，自动建 Cloudflare 安全隧道，
  生成一个 `https://xxx.trycloudflare.com` 公网地址，随时随地远程观察和派活。

---

## 第 1 步：打开电脑上的配对窗口

在 **DSH Desktop 窗口**里，二选一：

- 点击窗口里的手机图标按钮「**连接手机**」；或
- 菜单 → 「**连接手机…**」（快捷键 **Ctrl+Shift+M**）。

会弹出一个「**连接移动设备**」窗口，中间是二维码。

## 第 2 步：选连接模式

在配对窗口顶部有模式开关：

| 模式 | 适用 | 说明 |
|---|---|---|
| **WiFi连接模式**（默认） | 手机与电脑同一 WiFi | 实时性最好，二维码是 `http://电脑IP:端口/pair?token=…` |
| **互联网连接模式** | 4G/5G 或任何异地网络 | 走 Cloudflare 隧道，二维码是 `https://…trycloudflare.com/pair?token=…` |

> 首次切到「互联网连接模式」会自动下载 cloudflared（约几十 MB，需能访问 github.com）。
> 已提前把该程序放好，通常几秒即可建立隧道。

## 第 3 步：iPhone 扫码配对

1. 用 iPhone **相机**扫电脑屏幕上的二维码 → 点顶部弹出的链接（在 Safari 打开）；
   或点「复制」，把链接粘贴到 Safari 打开。
2. 手机会显示「**正在等待批准…**」。
3. 回到电脑上的「连接移动设备」窗口，会弹出「**手机正在等待批准**」→ 点「**允许**」。
4. 手机自动进入「**DSH Mobile**」页面，显示「连接成功，正在打开 DSH…」。

> 二维码 5 分钟自动刷新；配对链接里带一次性 token，只能这台手机用，别发给别人。

## 第 4 步：像 App 一样使用

在 iPhone 的 Safari 里点底部「分享」→「**添加到主屏幕**」→ 命名后点「添加」，
主屏会出现 DSH Mobile 图标，点开就是全屏 App 体验。

手机页面能做什么：

- **最近会话**列表 + 当前工作区切换 + 新建会话
- **实时对话流**：思考过程、工具调用、逐字输出，与电脑同步刷新
- **派任务**：底部输入框「给智能体发消息」，或「新会话」直接下新任务
- **任务清单**：输入框上方显示 To-dos 的「进行中/已完成/待处理」进度
- **回答问题**：智能体中途向你提问时，手机上直接选选项/填答案
- **停止生成**、会话设置（模型 / Preset / 思考强度）

## 第 5 步：换模式 / 断开

- 换 WiFi↔互联网模式前，需先在配对窗口点「**断开连接**」（有手机连着时模式开关会禁用）。
- 手机端想重连：再次打开之前那个链接，会自动进入「**重新连接 DSH**」页，
  点「重新连接」后到电脑端点「允许」。

---

## 常见问题

- **一直转圈 / 打不开**：确认手机与电脑连**同一 WiFi**；电脑防火墙放行了 DSH Desktop
  （通常首次启动已自动放行，无需手动操作）。
- **互联网连接模式「隧道建立失败」**：多为电脑无法访问 github.com 下载 cloudflared，
  或网络屏蔽了 trycloudflare.com；可先保证电脑能正常上外网再试。
- **二维码总在刷新**：5 分钟有效期，属正常；扫码后尽快点「允许」。
- **手机提示"本次连接申请已过期"**：回电脑重新点「连接手机」生成新二维码再扫。

## 安全提示

- WiFi 模式只在同一局域网内可用；互联网模式走 HTTPS 公网隧道 + 一次性配对 token，
  并由电脑端手动「允许」，不设明文口令也基本安全。
- 若手机丢失，在电脑「连接移动设备」窗口点「**断开连接**」即可立刻踢掉该手机。

---

## 增强：任务完成时手机推送（Bark）

不必一直盯着手机页面——智能体**跑完本轮**、或**向你提问需要回答**时，会自动推一条通知到 iPhone。

### 一次配置（1 分钟，二选一，均免费）

**方案 A：Bark（推荐）**
1. iPhone 上 App Store 搜索安装 **Bark**（免费），打开后复制首页那串 **Key**（形如 `AbCdEfGh...`）。
2. 用记事本打开 `D:\dsh\ds-phone-notify.json`，把 Key 填进 `barkKey`。

**方案 B：ntfy.sh（免装 App 也可）**
1. 打开 `D:\dsh\ds-phone-notify.json`，把 `ntfyTopic` 改成一段只有你知道的随机串（例如 `wo-de-dsh-9f3k2x`）。
2. 手机上装 ntfy App（免费）或用 Safari 订阅 `https://ntfy.sh/<你填的主题>`。

配置示例：

```json
{ "barkKey": "在这里粘贴你的 Bark Key（用方案A时）", "ntfyTopic": "或用方案B填这里" }
```

3. 重启一次 **DSH Desktop**（让挂钩生效），之后每次任务结束/提问都会收到推送。

### 触发时机与行为

| 时点 | 通知 |
|---|---|
| 智能体一轮任务结束（`Stop`） | 「DSH 本轮完成」 |
| 智能体调用提问工具（`ask_user_question`） | 「DSH 需要你回答」 |

> 机制：DSH Desktop 内置的 Codex hooks 桥在任务结束时调用
> `D:\dsh\ds-phone-notify.ps1` → 推送到 Bark。Key 为空时静默跳过，不影响智能体。
> 想关闭：删除 `C:\Users\<你的用户名>\AppData\Roaming\dsh-desktop\harness\profiles\web\cordis.patch.yml`
> 里的 `hooks-codex` 块并重启。

---

## 附：旧的 3080 端口进程（已停）

早前为手机访问另起过一个**无鉴权**的命令行版 `dsh web`（监听 `0.0.0.0:3080`），
现已**停用**，本机只保留 DSH Desktop 一套。若它又出现了（比如再次运行过
`Start-DeepSeek-Harness.cmd`），可在管理员 PowerShell 查停：

```powershell
Get-NetTCPConnection -LocalPort 3080 -State Listen   # 拿到 OwningProcess 后：
Stop-Process -Id <PID> -Force
```

---

## 增强二：电脑重启后隧道自动恢复 + 新链接自动推送到手机

已部署常驻监视器 `D:\dsh\ds-mobile-bridge.ps1`（已加入开机自启）：

- DSH Desktop / 电脑重启后，若之前开过隧道，**自动重新开启**互联网连接模式；
- 新隧道链接一生成，**自动推一条 Bark 通知**（「DSH 访问链接已更新」），点通知即可重连；
- 持续把当前最优访问地址写入 `D:\dsh\ds-mobile-url.txt`。

> 生效时机：**下次重启 DSH Desktop 时**验证。平时手动切 WiFi/互联网模式不受影响。
> 卸载：删除启动文件夹里的「DSH Mobile 自动隧道.cmd」，并结束 powershell 中
> `ds-mobile-bridge.ps1` 进程即可。

## 增强三：通知带直达链接（点一下直达会话）

任务完成 / 提问通知现在带一个**可点击链接**（Bark url 字段）——点通知直接打开 DSH Mobile，
并自动进入最近更新的会话（通常就是刚跑完的那个任务）。

## 增强四：固定网址方案（Tailscale）

✅ **电脑端已完成**：Tailscale 已安装、服务运行、已登录（账号 `<你的Tailscale账号>`）。
**固定地址 = `<你的Tailscale地址>`**（`tailscale ip -4` 确认），DSH 监视器已自动优先使用它。

只差手机端（一次性，约 2 分钟）：
1. iPhone：App Store 装 **Tailscale** → 登录**同一账号**（<你的Tailscale账号>）→ 保持连接（VPN 图标亮）。
2. 手机 Safari 打开 **`http://<你的Tailscale地址>:43127`** → 点「重新连接」→ 电脑上批准一次。
3. 之后**这个地址永久不变**，家外 5G 直接用，不再受隧道链接变动影响。

> 若想同时保持「自动公网隧道」（供未装 Tailscale 的设备用），重启 DSH Desktop 后监视器会
> 自动开隧道并推送新链接（见增强二）。两者可共存：通知链接优先用隧道地址，其次 Tailscale。

### ⚠️ 重要：Tailscale 网段需要一次补丁 + 重启（已处理）

DSH Desktop 的网关只放行经典内网段（10.x / 172.16-31.x / 192.168.x），**默认会拒绝
Tailscale 的 100.64/10 网段**（返回 403「Private network only」）。已在本机打好补丁：

- 改动：`…\DSH Desktop\resources\app\out\main\index.js` 网关守卫放行 `100.64.0.0/10`
  （仅入口守卫，不影响局域网配对地址）；语法已校验，原文件备份为 `index.js.bak-cgnat`。
- **该补丁在 DSH Desktop 重启后生效**——正好和增强 A 一起验证。
- 若以后 DSH Desktop 升级覆盖了该文件，重新运行一次：`powershell -File D:\dsh\ds-patch-cgnat.ps1`

---

## 相关文件一览

| 文件 | 作用 |
|---|---|
| `D:\dsh\手机访问指南.md` | 本指南 |
| `D:\dsh\ds-phone-notify.ps1` / `.json` | 任务完成/提问推送（Bark/ntfy）+ 直达链接 |
| `D:\dsh\ds-mobile-bridge.ps1` + 启动文件夹 `.cmd` | 重启后自动开隧道 + 推新链接（常驻） |
| `D:\dsh\ds-mobile-url.txt` | 当前手机访问地址缓存（通知附链接用） |
| `D:\dsh\ds-hooks.json` | hooks 触发点（任务结束 / 提问） |
| `…\Roaming\dsh-desktop\harness\profiles\web\cordis.patch.yml` | 挂载 hooks 桥 |
