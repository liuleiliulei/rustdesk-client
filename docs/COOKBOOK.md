# svchost 强制覆盖字段 (override-settings) 速查册

> 用法: 把这里的 `key=value` 行**按需选择**复制到 rdgen 编译表单底部的「**强制覆盖字段 (高级, 任意 RustDesk option, 用户改不了)**」textarea 里。
>
> 格式规则:
> - 一行一个 `key=value`
> - 等号两边可有空格,会自动 strip
> - **不要加引号** (`hide-tray=Y` 对,`hide-tray="Y"` 错)
> - 值是 `Y` / `N` / 数字 / 字符串字面量
> - 没等号的行会被静默跳过 (rdgen 已加容错)

---

## 🔒 套餐一: 反绕开锁死 (Tier A · 9 行)

把"客户用命令行/配置文件/UI 暗门绕开 svchost 锁"的所有路径堵死。

| key | 推荐值 | 干什么用 | 不勾的代价 |
|---|---|---|---|
| `disable-change-permanent-password` | `Y` | 锁死永久密码,客户不能改 | 客户在设置里能改你的预设密码 |
| `disable-unlock-pin` | `Y` | 禁 PIN 解锁绕开密码 | PIN 可作为密码的替代登录方式 |
| `disable-clipboard` | `Y` | 强制锁死剪贴板 (system-wide, 比 enable-clipboard 更狠) | 客户能开剪贴板透传 |
| `disable-udp` | `Y` | 禁 UDP,只走 TCP | UDP 打洞可能绕过企业内网防火墙规则 |
| `disable-discovery-panel` | `Y` | 隐藏"发现"面板 (跟 disable-group-panel 配对) | 客户能扫到内网其他设备 |
| `allow-hostname-as-id` | `N` | 禁 hostname 作为 RustDesk ID | 用 hostname 等于暴露 Windows 主机名 |
| `allow-logon-screen-password` | `N` | 禁登录屏密码 | 多一个登录路径多一个攻击面 |
| `allow-insecure-tls-fallback` | `N` | 防 TLS 降级到不安全 | 中间人攻击窗口 |
| `lock-after-session-end` | `Y` | 远控会话结束自动锁屏 | 远控人下机后被控端保持登录态 |

**一键复制 (Tier A 全套):**
```
disable-change-permanent-password=Y
disable-unlock-pin=Y
disable-clipboard=Y
disable-udp=Y
disable-discovery-panel=Y
allow-hostname-as-id=N
allow-logon-screen-password=N
allow-insecure-tls-fallback=N
lock-after-session-end=Y
```

---

## 🎨 套餐二: 画质/编码预设 (Tier B · 7 行)

锁死最佳画质/帧率,客户的网络再差也按你的预设跑。

| key | 推荐值 | 干什么用 | 备注 |
|---|---|---|---|
| `image-quality` | `balanced` | 画质档位 | 选项: `best` / `balanced` / `low` / `custom` |
| `custom-image-quality` | `50` (仅 image-quality=custom 时) | 自定义画质数值 | 1-100,数字越大越清晰但占带宽 |
| `custom-fps` | `30` | 自定义帧率 | 默认 30 已够流畅 |
| `codec-preference` | `auto` | 编码器选择 | 选项: `auto` / `vp8` / `vp9` / `av1` / `h264` / `h265` |
| `enable-abr` | `Y` | 自适应比特率 (网络抖动自动降码率保流畅) | 默认就是 Y |
| `enable-hwcodec` | `Y` | 硬件编码加速 (GPU 编码,降低 CPU) | 默认就是 Y |
| `enable-directx-capture` | `Y` | DirectX 截屏加速 (代替老 GDI 截屏) | Win 高端机推荐 |

**一键复制 (Tier B 全套):**
```
image-quality=balanced
custom-fps=30
codec-preference=auto
enable-abr=Y
enable-hwcodec=Y
enable-directx-capture=Y
```

---

## 🇨🇳 套餐三: UI 锁定 (Tier C · 5 行)

锁中文 + 设备列表样式。

| key | 推荐值 | 干什么用 |
|---|---|---|
| `lang` | `zh-cn` | 强制中文,客户不能切英文 |
| `peer-card-ui-type` | `2` | 设备卡片样式: `0`=大瓦片 / `1`=小瓦片 / `2`=列表 (企业感) |
| `peer-sorting` | `Remote ID` | 设备排序方式 |
| `main-window-always-on-top` | `N` | 主窗口置顶 (一般不开,影响操作) |
| `enable-trusted-devices` | `N` | 可信设备列表 (svchost 场景不需要,N 关掉) |

**一键复制 (Tier C 全套):**
```
lang=zh-cn
peer-card-ui-type=2
peer-sorting=Remote ID
```

---

## 🌐 套餐四: 网络高级 (rdgen 表单已有,这里补遗 · 3 行)

rdgen 表单的「网络与安全加固」已经覆盖大部分,这里是补充。

| key | 推荐值 | 干什么用 |
|---|---|---|
| `enable-udp-punch` | `Y` (默认) | UDP 打洞 (P2P 直连) |
| `enable-ipv6-punch` | `N` 或 `Y` | IPv6 打洞 (有 IPv6 才开) |
| `direct-server` | `Y` | 允许直连模式 (跟 enableDirectIP 表单字段一样) |

---

## 📋 套餐五: 审计录制 (Tier D · 3 行)

合规场景需要把所有远控会话录像保存。

| key | 推荐值 | 干什么用 |
|---|---|---|
| `allow-auto-record-incoming` | `Y` | 自动录制所有入会 (被控端) |
| `allow-auto-record-outgoing` | `Y` | 自动录制所有出会 (主控端) |
| `video-save-directory` | `C:\\svchost-recordings` | 录像保存路径 (注意反斜杠双写) |

**一键复制 (Tier D 全套):**
```
allow-auto-record-incoming=Y
allow-auto-record-outgoing=Y
video-save-directory=C:\\svchost-recordings
```

---

## 🚫 不要写在这里的 key (会出怪 bug)

| key 类型 | 为什么 | 该走哪 |
|---|---|---|
| `enable-keyboard/clipboard/file-transfer/audio/...` | rdgen 表单的「权限」分类已经显式处理 | 用表单复选框 |
| `verification-method` / `approve-mode` / `password` | rdgen 表单有显式字段 | 用表单 |
| `hide-tray` / `hide-stop-service` / `hide-*-settings` | rdgen 表单的「高级 UI 锁死」分类已显式处理 | 用表单 |
| `relay-server` / `whitelist` / `proxy-*` | rdgen 表单的「网络与安全加固」已显式处理 | 用表单 |
| per-session 控制端工具栏类 (`view-only`/`show-remote-cursor`/...) | 不是 build 时锁的,是远控连入时控制端的状态 | 不要 build 时配 |
| `preset-address-book-*` / `preset-device-*` / `preset-user-name` | 大客户管理后台用,svchost 单机部署用不上 | 不要配 |
| Mobile/Android 专属 (`floating-window-*` / `touch-mode` / `keep-screen-on`) | 你只 Windows | 不要配 |

---

## 🧪 svchost-v9 终极推荐套餐 (一键全贴)

把 Tier A + B + C 精选 13 行打包,贴这一坨就是 svchost "终极形态":

```
# === 反绕开锁死 (Tier A 精选 5) ===
disable-change-permanent-password=Y
disable-unlock-pin=Y
disable-discovery-panel=Y
lock-after-session-end=Y
allow-insecure-tls-fallback=N

# === 画质预设 (Tier B 精选 4) ===
enable-abr=Y
enable-hwcodec=Y
enable-directx-capture=Y
codec-preference=auto

# === UI 中国化 (Tier C 精选 3) ===
lang=zh-cn
peer-card-ui-type=2
peer-sorting=Remote ID
```

注: rdgen 表单的「强制覆盖字段」目前 split 是按行处理,**`#` 开头的行会因为没 `=` 被 rdgen 静默跳过**——所以注释行可以保留作为可读性,不会影响功能。

---

## 📚 参考

- 官方 137 个 advanced settings 完整列表: https://rustdesk.com/docs/en/self-host/client-configuration/advanced-settings/
- 优先级规则: Override (你这个) > Strategy (Web Console) > User (toml) > Default (出厂)
- 改 toml 文件能验证 override 是不是真锁死了: 改完保存重启 svchost,如果重启后值被强制改回来,说明 override 生效

## 📝 版本管理建议

你以后改 svchost 客户端就两件事:
1. 复制本文件相关段落 → 贴 rdgen 强制覆盖字段
2. 编完拿 svchost.exe / svchost.msi

把每次贴的内容存 `svchost-v9-overrides.txt` / `svchost-v10-overrides.txt`,后面回溯版本很方便。
