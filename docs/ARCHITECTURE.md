# 架构说明

## 系统组成

```
┌─────────────────────────────────────────────────────────────────────┐
│                  你的浏览器 (Basic Auth)                              │
│                            │                                         │
│              https://rdgen.aliu.eu.org                              │
│                            │                                         │
└────────────────────────────┼────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                  Cloudflare Edge (CDN + TLS)                         │
│                            │                                         │
│        Public Hostname → 隧道 ID.cfargotunnel.com                    │
└────────────────────────────┼────────────────────────────────────────┘
                             │ 反向连接 (出站发起)
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│   飞牛 NAS  10.10.10.10                                              │
│  ┌─────────────────────────┐   ┌──────────────────────────────┐    │
│  │  cloudflared container  │◀──│  rdgen container             │    │
│  │  (cloudflare/cloudflared)│   │  (rdgen-svchost:v1)          │    │
│  │                          │   │  Django + Gunicorn + SQLite  │    │
│  └─────────────────────────┘   └──────────────────────────────┘    │
│                                            │                         │
│                                            │ 出站 HTTPS              │
└────────────────────────────────────────────┼─────────────────────────┘
                                             │
                                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│        GitHub Actions (公网, 你的 fork)                               │
│   liuleiliulei/rustdesk-client                                      │
│                                                                       │
│  Workflows:                                                          │
│    generator-windows.yml ─┐                                          │
│    generator-macos.yml    ├─→ workflow_dispatch (rdgen 触发)        │
│    generator-linux.yml    │   inputs: version + zip_url             │
│    generator-android.yml ─┘                                          │
│                                                                       │
│  Runner 干啥:                                                        │
│    1. Load Secrets: 从 GENURL/temp_zips/xxx.zip 下载加密 secrets    │
│    2. 用 ZIP_PASSWORD 解密拿 svchost 配置 JSON                       │
│    3. sed/patch 源码 (品牌/服务器/UI 锁等)                            │
│    4. Build Rust + Flutter (~30 分钟)                                │
│    5. upload-artifact: 把产物存 GitHub artifact (svchost patch)      │
│    6. (失败但无害) send_file_to_rdgen: 试图传产物回 rdgen           │
└─────────────────────────────────────────────────────────────────────┘
                                             ▲
                                             │ /download_artifact view
                                             │ GH API 拉 artifact zip
                                             │ 流式回传给浏览器
                                             │
┌─────────────────────────────────────────────────────────────────────┐
│                  你的浏览器点"⬇️ 下载产物 zip"                          │
│                  解压 → 装 svchost.exe / .msi / .dmg                  │
└─────────────────────────────────────────────────────────────────────┘
```

## 数据流 (一次完整编译)

1. **浏览器填表 → POST /**:rdgen 生成 uuid + 把 28 表单字段 + 28 svchost patch 字段写到 `custom.txt` JSON,加密成 `secrets_<uuid>.zip` 存 `temp_zips/`
2. **rdgen 调 GitHub API**:`POST /repos/.../workflows/generator-windows.yml/dispatches`,inputs: `version`, `zip_url=<rdgen_url>/temp_zips/secrets_xxx.zip`
3. **GitHub runner 启动**:从 `${{ secrets.GENURL }}/temp_zips/secrets_xxx.zip` 下载加密 zip,用 `${{ secrets.ZIP_PASSWORD }}` 解密
4. **runner 跑 workflow**:Checkout → sed patch → cargo build --release → Flutter build → MSI/DMG 打包
5. **upload-artifact 步骤** (svchost 加的):产物上传到 GitHub artifact storage,命名 `rustdesk-<platform>-<filename>`
6. **rdgen 轮询**:`/check_for_file` 每 30 秒调 GitHub API 查 run status,**conclusion=failure 也认**(因为 send_file_to_rdgen 总挂),只要 artifact 存在 → status='artifact_ok'
7. **用户点绿按钮 → /download_artifact?run_id=xxx**:rdgen 后端流式从 GitHub API 拉 artifact zip 转发给浏览器

## 关键组件

### rdgen (Django)
- 入口: `rdgen/urls.py`
- 表单定义: `rdgenerator/forms.py` (78 个字段)
- 业务逻辑: `rdgenerator/views.py` (1000+ 行,核心 `generator_view` + `check_for_file` + `download_artifact`)
- 模板: `rdgenerator/templates/` (generator.html / waiting.html / generated.html / failure.html / maintenance.html)
- Basic Auth: `rdgenerator/middleware.py` (76 行)
- DB: SQLite,只存 `GithubRun` 表 (uuid + github_run_id + status)
- 端口: 0.0.0.0:8000 (容器内)

### GitHub Workflows
- 5 个平台各 1 个: windows/windows-x86/macos/linux/android
- 触发: workflow_dispatch (rdgen 调 GitHub API)
- 公共步骤: setup/download-zip (拿 secrets.zip) → 平台特定 build → upload-artifact
- 私有 actions: `.github/actions/decrypt-secrets/` (解密 secrets.zip)

### cloudflared 隧道
- 镜像: `docker.1ms.run/cloudflare/cloudflared:latest` (国内镜像源,直拉 Docker Hub 60MB 要 10+ 分钟)
- 模式: named tunnel (不是 quick),URL 固定 `rdgen.aliu.eu.org`
- token 在 docker-compose `command` 字段,文件 `chmod 600`
- 反向连接 (出站),NAS 不开任何入站端口

### Basic Auth middleware
- 鉴权:浏览器请求 `Authorization: Basic <base64(user:pass)>` header
- 白名单 (runner 路径): `/save_custom_client` `/get_png` `/cleanzip` `/temp_zips/` `/startgh` `/creategh` `/updategh`
- 触发 401 时返回 `WWW-Authenticate: Basic realm="rdgen-svchost"`,浏览器弹原生密码框
- 配置: 环境变量 `BASIC_AUTH_USERNAME` + `BASIC_AUTH_PASSWORD`,空值=禁用 (向后兼容)

## 关键决策记录 (ADR)

### ADR 1: 为什么走 upload-artifact 而不是修 rdgen 回传

**问题**: rdgen 原设计是 runner POST 产物回 `rdgen/save_custom_client`,通过 cloudflared 隧道传 80MB+,60 秒必超时。

**选项**:
- A. 改 workflow 用 chunked upload(复杂,要改 nick-fields/retry 行为)
- B. 加 cloudflared --max-edge-grace-time(治标不治本)
- C. **加 actions/upload-artifact 步骤,产物存 GitHub 自家 storage,rdgen 后端代理下载**

**选 C**。改动 5 行 YAML,绕开 cloudflared 大文件路径,永远稳定。

### ADR 2: 为什么用 Basic Auth 不用 Cloudflare Access

**选项**:
- A. Cloudflare Access (邮箱 OTP 或第三方 IdP)
- B. **app 内 Basic Auth (Django middleware)**

**选 B**。理由:
- 用户场景是一个人用,不是企业团队
- Cloudflare Access 需要改 workflow 加 Service Token header (改动量更大)
- Basic Auth 浏览器原生支持,密码管理器自动填,体验更平滑

### ADR 3: 为什么 fork 仓库保持 public

GitHub Free 套餐:
- 私有仓库 macOS runner 10× minute multiplier (一次 30 分钟编译扣 300 min)
- **公开仓库 0 配额**(所有平台免费)

ADR: **永远不 archive 不改 private**,白嫖到底。

### ADR 4: 为什么 cloudflared 用国内 docker 镜像源

**问题**: NAS 国内,拉 `cloudflare/cloudflared:latest` 524 秒只下到 14MB。

**解**: 在 compose 里加 `docker.1ms.run/` 前缀,**精准只换这一个镜像**,不动 daemon mirror 避免影响 rdgen 镜像。

### ADR 5: 为什么 NAS 用 cloudflared named tunnel 不用反代

| 方案 | 优势 | 劣势 |
|---|---|---|
| Cloudflare named tunnel (✅选) | NAS 零入站端口 + URL 固定 + 天然 HTTPS + CF 边缘加速 | 依赖 CF 服务可用性 |
| Nginx 反代 + 公网域名 | 自主可控 | NAS 开 443 入站 + 自己续证书 |
| quick tunnel | 免配置 | URL 每次重启变,要更新 GH secret |

NAS 不开入站、URL 稳定、HTTPS 免费续——综合 cloudflared named tunnel 最优。

## 数据持久化点

| 路径 | 用途 | 必须挂卷? |
|---|---|---|
| `/opt/rdgen/db.sqlite3` | GithubRun 编译记录 | ✅ 必须 (不挂卷重建容器就丢) |
| `/opt/rdgen/exe/` | (废弃) 旧版本产物缓存 | 可选 |
| `/opt/rdgen/png/` | 用户上传的 icon/logo PNG | 可选 |
| `/opt/rdgen/temp_zips/` | secrets.zip 临时 (runner 拉走后会清) | 可选 |

## 性能数据 (实测)

| 项 | 数值 |
|---|---|
| 镜像大小 | 60MB tar.gz / 146MB 解压 |
| 容器启动 | 3-5 秒 |
| 编译耗时 (Win) | 30-50 分钟 (含缓存) |
| 编译耗时 (Mac) | 30-50 分钟 |
| Artifact zip 大小 (Win) | 47MB |
| Artifact zip 大小 (Mac) | 35MB |
| GitHub API minute 消耗 (public fork) | **0** |
