# rdgen-svchost — RustDesk 自定义客户端 Web Builder

> Fork 自 [wztx/rustdesk-client](https://github.com/wztx/rustdesk-client) (rdgen.crayoneater.org 源码),做了 svchost 专属定制 + 中文化 + Basic Auth + 私有 NAS 部署。
>
> 上游英文 README 见 [README_upstream.md](README_upstream.md)。

## 🎯 这个项目是干什么的

一个**自托管的 RustDesk 客户端 Web 编译器**。打开网页填表单,30-45 分钟自动出一个定制好品牌/服务器/密码/UI锁定的 RustDesk 客户端(Windows/macOS/Linux/Android 任选)。

**使用闭环**:浏览器 → 填表 → 编译 → 下载 → 装机。

## 🏗 核心架构 (3 板斧)

```
[浏览器(Basic Auth 保护)]
        │
        ▼
[rdgen (Django, Docker, NAS 10.10.10.10)] ◀───┐
        │                                      │
        │ workflow_dispatch                    │ artifact zip
        ▼                                      │
[GitHub Actions (你的 fork: liuleiliulei/rustdesk-client)]
        │
        ▼
[编出 svchost.exe / .msi / .dmg / .deb / .apk]
```

详见 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)。

## 📐 跟原始 rdgen 比 多了什么

| 类别 | 改进 |
|---|---|
| UI 中文化 | forms.py + 5 个 HTML 模板全中文 |
| 表单字段 +29 | "高级 UI 锁死" + "网络与安全加固" 两大新分类,共 29 个新 RustDesk option 直接做成 UI 控件 |
| 网页下载按钮 | rdgen 后端代理 GitHub artifact (绕开失败的 cloudflared 大文件回传) |
| upload-artifact 路径 | Win/Mac workflow 加 `actions/upload-artifact@v4` 步骤 |
| Mac ad-hoc 签名 | Apple Silicon Mac 装 .dmg 体验从 8 行 codesign 降到 1 行 xattr |
| Basic Auth | 浏览器访问要密码, runner 走 4 个 exempt 路径无感 |
| 持久化 db.sqlite3 | NAS compose 挂卷, 不再 docker rebuild 就丢编译记录 |
| 中文部署文档 | docs/DEPLOY.md + docs/MAINTENANCE.md + docs/ARCHITECTURE.md |
| svchost 配置速查册 | docs/COOKBOOK.md 5 套预设直接复制粘贴 |

## 🚀 快速开始 (本机开发)

```bash
git clone https://github.com/liuleiliulei/rustdesk-client.git
cd rustdesk-client
# 编辑 docker-compose.yml: 填 GHBEARER (你的 GitHub PAT) + GENURL (用 cloudflared 起一个 quick tunnel)
docker compose up -d --build
open http://localhost:8000
```

详细 [docs/DEPLOY.md](docs/DEPLOY.md)。

## 🌐 生产部署 (任意 Linux + Cloudflare)

```bash
# Mac 上一键打包部署包
./scripts/build-image.sh           # buildx amd64 镜像 + save tar.gz
./scripts/bundle-deploy.sh         # 打 deploy-bundle.tar.gz 含镜像 + compose 模板 + 文档

# scp 到新机器
scp deploy-bundle.tar.gz user@newhost:/path/

# 新机器上
tar xzf deploy-bundle.tar.gz && cd deploy-bundle/
# 跟着 README.md 填 4 个密钥 + 启动 cloudflared tunnel + docker compose up
```

完整 SOP 见 [docs/DEPLOY.md](docs/DEPLOY.md)。

## 🛠️ 维护 (高频场景)

| 改动 | 操作摘要 |
|---|---|
| **改 GitHub workflow YAML** (`.github/workflows/*.yml`) | `git push` 即可,NAS **零操作** |
| **改 rdgen Python 代码 / 模板** | Mac 重 build → scp 镜像 → NAS load + restart (4 命令) |
| **改 docker-compose.yml 的 env** | SSH NAS 改 yml + `docker compose up -d` (无需重 build) |
| **改 Basic Auth 密码** | 改 compose env + `docker compose restart rdgen` |
| **Cloudflare token 过期** | Zero Trust 重发 token + 改 compose command + `docker compose restart cloudflared` |
| **当一个新 svchost 客户端** | 浏览器开 rdgen → 加载配置 → 改平台 → 编译 → 下载 |

详见 [docs/MAINTENANCE.md](docs/MAINTENANCE.md)。

## 📚 文档导航

| 文档 | 用途 |
|---|---|
| [docs/DEPLOY.md](docs/DEPLOY.md) | 新机器从零部署 (任意 Linux + Cloudflare 或反代) |
| [docs/MAINTENANCE.md](docs/MAINTENANCE.md) | 日常运维 + 排错手册 |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | 架构说明 + 数据流 + 关键决策记录 |
| [docs/COOKBOOK.md](docs/COOKBOOK.md) | svchost override-settings 速查册 (5 套预设) |
| [scripts/](scripts/) | 一键 build / bundle / Mac 签名修复 |

## 🔐 安全模型

- **网页层**: Basic Auth (用户名 `admin` + 随机生成的 32 字节密码)
- **API 路径**: runner 调的 4 个端点 (`/cleanzip` `/save_custom_client` `/get_png` `/temp_zips/*`) 走白名单
  - 安全靠 **uuid 不可猜 (uuid4 = 122 bit 熵) + ZIP_PASSWORD 加密**
- **隧道**: Cloudflare Tunnel (纯出站连接, NAS 不开任何入站端口, 抗扫描)
- **GitHub Token**: Fine-grained PAT, 仅给 fork 仓库 Actions/Contents 读写权限
- **fork 仓库 public**: 让 GitHub Actions **0 minute 配额**,所有平台编译完全免费

## 📞 上游与来源

- 直接 fork 源: [wztx/rustdesk-client](https://github.com/wztx/rustdesk-client) (rdgen.crayoneater.org)
- 客户端源: [rustdesk/rustdesk](https://github.com/rustdesk/rustdesk)
- 本 fork: [liuleiliulei/rustdesk-client](https://github.com/liuleiliulei/rustdesk-client)
- 当前部署: https://rdgen.aliu.eu.org (Basic Auth 保护)

## 📜 License

继承上游 license。本项目所有 svchost 定制改动按本地内部使用,**不对外分发**。
