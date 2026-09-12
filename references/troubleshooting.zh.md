# DSH 手机连接 · 维护手册（一页看懂）

> 更新：2026-09-12 深夜，手机端已在 5G 下跑通。

## 一、平时怎么用（就一件事）

**手机点通知里的链接** → 直接进 DSH Mobile。

- 家里、外面 5G 都能用；**不需要和电脑同一个 WiFi**，**一般也不用开 VPN**
- 觉得慢/打不开时，再试着**打开代理/VPN**刷新（连的是境外服务器，有代理可能更快）
- 当前链接：`<你的隧道链接（每次重启会变，监视器会自动推送）>`（**电脑重启后会变**）

## 二、打不开时的 3 步自查（按顺序）

1. **看手机通知**：有没有一条「DSH 访问链接已更新」→ 点**最新**那条
2. **看电脑**：DSH Desktop 有没有开着？没开就打开它，等 30 秒
3. **还不行**：手机开关一下代理/VPN 再刷新；再不行就用 Safari（别用 Chrome）

## 三、电脑重启后会发生什么（全自动）

重启电脑后，下面这些会**自己起来**，不用你操作：

| 组件 | 自启方式 |
|---|---|
| DSH Desktop（提供手机网关） | 注册表 Run 键 `DSHDesktop` |
| 隧道监视器（自动开隧道 + 推链接） | 注册表 Run 键 `DSHMobileBridge` + 启动文件夹 |
| Tailscale（备用固定地址通道） | Windows 服务，自动启动 |

监视器做的事：检测到 DSH Desktop 重启 → **自动重开隧道** → 把**新链接推送**到你手机 Bark。

## 四、几个关键事实（省得再猜）

- **手机网关端口固定**：`43127`（局域网 `http://电脑IP:43127`，公网走隧道）
- **局域网地址会变**（你这台电脑常在两个路由器间跳），所以**别用局域网地址做主入口**；监视器变了会推给你
- **Tailscale 固定地址** `http://<你的Tailscale地址>:43127`：电脑端已装好可用，但**手机端没有真正的 Tailscale VPN**（中国区 App Store 没有；Termius 里那个内置客户端只能它自己用，帮不了 Safari）→ 所以目前**外网主通道 = 公网隧道链接**
- **Termius 是 SSH 客户端**，和这套方案无关，可以不管

## 五、相关文件（都在 D:\dsh\）

| 文件 | 作用 |
|---|---|
| `ds-mobile-bridge.ps1` | 隧道/地址监视器（自动开隧道、变化时推链接） |
| `ds-mobile-bridge.log` | 监视器日志（排查时看这个） |
| `ds-mobile-url.txt` | 当前手机访问地址（通知里带的链接取自这里） |
| `ds-phone-notify.ps1` / `.json` | 任务完成/提问推送（Bark）+ 直达链接 |
| `ds-hooks.json` | 挂钩触发点（任务结束 / 提问） |
| `手机访问指南.md` | 更完整的图文步骤 |
| `ds-patch-cgnat.ps1` | DSH Desktop 升级后重打"放行 Tailscale 网段"补丁 |

## 六、万一彻底不行了

在电脑上跑一次（会重新拉起隧道并推新链接给你）：

```powershell
Stop-Process -Name cloudflared -Force -ErrorAction SilentlyContinue
& "C:\Program Files\PowerShell\7\pwsh.exe" -NoProfile -File "D:\dsh\ds-mobile-bridge.ps1"
```

或直接重新打开一次 DSH Desktop，等 1 分钟，手机会收到新链接。
