# 部署 SOP — 任意 Linux + Docker 机器

> 适用:NAS / VPS / 云服务器 / 物理机 等任何 Linux + Docker 环境。
>
> 演示以飞牛 NAS 为例,通用步骤标 ⭐,飞牛特有标 🟠。

## 0. 前置检查

| 项 | 要求 | 验证命令 |
|---|---|---|
| 操作系统 | Linux x86_64 (amd64) | `uname -m` 看到 `x86_64` |
| Docker | 20.10+ 含 compose v2 | `docker compose version` |
| 出站网络 | 能访问 `api.github.com` + `cloudflare.com` | `curl -sI https://api.github.com/` |
| 磁盘空间 | ≥ 500MB | `df -h /vol1` |
| 内存 | ≥ 512MB 可用 | `free -h` |

如果你的机器是 **ARM64** (Apple Silicon Mac / Raspberry Pi / 部分国产 NAS):
- 把 `scripts/build-image.sh` 里 `--platform linux/amd64` 改成 `--platform linux/arm64`
- 镜像在 Mac 上重 build

## 1. 准备一次性资料 ⭐

```
A. GitHub Fine-grained PAT (Personal Access Token)
B. ZIP_PASSWORD (随机字符串)
C. SH_SECRET (随机字符串)
D. SECRET_KEY (Django, 随机)
E. Cloudflare Zero Trust 账号 + 你的域名 (域名 DNS 必须在 Cloudflare)
F. Basic Auth 用户名 + 密码 (建议随机生成 32 字节)
```

生成命令:

```bash
# ZIP_PASSWORD / SH_SECRET / Basic Auth 密码
python3 -c "import secrets; print(secrets.token_urlsafe(24))"

# Django SECRET_KEY
python3 -c "import secrets; print(secrets.token_hex(50))"
```

GitHub PAT 申请: https://github.com/settings/tokens?type=beta
- Repository access: Only select repositories → 你的 fork
- Permissions: Actions(R/W) + Contents(R/W) + Workflows(R/W) + Metadata(R)
- Expiration: 90 天或更长

## 2. Fork RustDesk client 仓库 ⭐

1. 打开 https://github.com/wztx/rustdesk-client → Fork
2. **重要**: 保持 fork 为 **public**(0 配额免费 macOS 编译)
3. 进 fork 仓库 → Actions → "I understand my workflows, enable them"

## 3. 配 Cloudflare Tunnel ⭐

1. 进 https://one.dash.cloudflare.com/ (Zero Trust)
2. 左侧菜单 → **Networks → Tunnels** → **Create a tunnel**
3. 类型选 **Cloudflared**
4. Name: `rdgen-svchost`
5. Install 步骤选 **Docker**, **复制 token**(形如 `eyJhIjoi...`)
6. **Next** 进 Public Hostnames:

| 字段 | 填啥 |
|---|---|
| Subdomain | `rdgen` |
| Domain | 你域名 (下拉里选) |
| Path | (留空) |
| Service Type | `HTTP` |
| URL | `rdgen:8000` ⚠️ 注意是 service 名不是 localhost/IP |

7. 保存 → Cloudflare 自动加 CNAME 到你 DNS

## 4. 准备部署包 ⭐

如果你**已经有 deploy-bundle.tar.gz**,跳到 Step 5。

如果你要**从源码现 build**(Mac/Linux 都行):

```bash
git clone https://github.com/liuleiliulei/rustdesk-client.git
cd rustdesk-client
./scripts/build-image.sh           # buildx amd64 → save 60MB tar.gz
./scripts/bundle-deploy.sh         # 打包 deploy-bundle.tar.gz
```

完成后会得到 `deploy-bundle.tar.gz` 在仓库根目录。

## 5. 传到目标机器 ⭐

```bash
# 在你本地机器
scp deploy-bundle.tar.gz user@TARGET_HOST:/path/to/

# SSH 进目标机
ssh user@TARGET_HOST
cd /path/to/
tar xzf deploy-bundle.tar.gz
cd deploy-bundle/
```

### 飞牛 NAS 路径建议 🟠

```bash
# 飞牛默认 Docker 项目根
TARGET_DIR=/vol1/1000/Docker/rdgen-svchost/
mkdir -p $TARGET_DIR
scp deploy-bundle.tar.gz liulei@10.10.10.10:$TARGET_DIR/
ssh liulei@10.10.10.10
cd /vol1/1000/Docker/rdgen-svchost/
tar xzf deploy-bundle.tar.gz --strip-components=1
```

## 6. 改 docker-compose 填密钥 ⭐

```bash
nano docker-compose.yml
# 或者用 vi / 飞牛网页编辑器
```

改 **6 个值**:

```yaml
environment:
  SECRET_KEY: "<改我: 上面 D 步生成的 hex>"
  GHUSER: "<改我: 你 GitHub 用户名>"
  GHBEARER: "<改我: A 步的 PAT>"
  GENURL: "https://rdgen.<改我: 你域名>"
  ZIP_PASSWORD: "<改我: B 步生成>"
  REPONAME: "rustdesk-client"
  SH_SECRET: "<改我: C 步生成>"
  BASIC_AUTH_USERNAME: "admin"
  BASIC_AUTH_PASSWORD: "<改我: F 步生成>"

# 同时改 cloudflared 那块:
command: tunnel --no-autoupdate run --token <改我: 第 3 步复制的 cloudflared token>
```

锁敏感文件:

```bash
chmod 600 docker-compose.yml
```

## 7. 准备 db.sqlite3 ⭐

⚠️ **重要**: 直接 `docker compose up` 会让 Docker 自动创建 db.sqlite3 **目录**(不是文件),容器启动报错。必须先准备好真文件:

```bash
# 加载镜像
sudo docker load -i rdgen-svchost-v1.tar.gz

# 从镜像里抽 db.sqlite3 出来
sudo docker create --name dbextract rdgen-svchost:v1
sudo docker cp dbextract:/opt/rdgen/db.sqlite3 ./db.sqlite3
sudo docker rm dbextract

# 验证
ls -lh db.sqlite3   # 应该 132K, -rw- 开头
```

## 8. 启动 ⭐

```bash
mkdir -p exe png temp_zips

# 启动两个容器
sudo docker compose -f docker-compose.yml up -d

# 看状态
sudo docker compose -f docker-compose.yml ps
# 期望: rdgen + cloudflared 都 Up

# 看 rdgen 日志
sudo docker logs rustdesk-builder-nas | tail -10
# 期望: Starting gunicorn 26.0.0 + Listening at 0.0.0.0:8000
```

## 9. 同步 GitHub Actions Secrets ⭐

GitHub runner 解密 secrets.zip 用 `ZIP_PASSWORD`,触发回调用 `GENURL`。必须跟你 compose 里填的一致:

```bash
# 在你本地机器 (Mac/Linux, 有 gh CLI)
echo -n 'https://rdgen.<你的域名>' | gh secret set GENURL --repo <你 GitHub 用户名>/rustdesk-client
echo -n '<你 compose 里的 ZIP_PASSWORD>' | gh secret set ZIP_PASSWORD --repo <你 GitHub 用户名>/rustdesk-client

# 验证
gh secret list --repo <你 GitHub 用户名>/rustdesk-client
# 应该看到 GENURL + ZIP_PASSWORD
```

## 10. 验证全链路 ⭐

```bash
# 隧道连通: 从外网 curl
curl -sI https://rdgen.<你的域名>/
# 期望: HTTP/2 401 (Basic Auth 拦截, 隧道通)

# 带 auth 访问
curl -sI -u 'admin:<你的密码>' https://rdgen.<你的域名>/
# 期望: HTTP/2 200

# Runner exempt path
curl -s -o /dev/null -w "HTTP %{http_code}\n" -X POST https://rdgen.<你的域名>/save_custom_client
# 期望: HTTP 500 (业务错, 不是 401, 说明白名单生效)
```

浏览器开 `https://rdgen.<你的域名>/`:
1. 看到原生用户名密码弹窗
2. 输 admin + 密码
3. 进入中文 rdgen 表单

## 11. 端到端编译测试 ⭐

1. 浏览器开 rdgen
2. 填一份测试配置 (用任意 server IP, key, password)
3. 平台选 Windows 64
4. 点 **开始编译**
5. 跳到 waiting 页
6. 等 30-45 分钟
7. 自动跳 generated 页,看到绿色 ⬇️ 下载产物 zip 按钮
8. 点按钮 → 下载 47MB zip
9. 解压看到 svchost.exe + svchost.msi

## 12. (可选) 配置自动启动 ⭐

Docker compose 已经设置 `restart: unless-stopped`,容器死了会自动重启,**机器重启也会自启**(只要 dockerd 自启,大多数 NAS 默认配置如此)。

验证:
```bash
sudo systemctl status docker
# 期望: enabled
```

## 🆘 排错速查

### Q: docker compose up 报 `db.sqlite3 mount` 错
A: 跑 Step 7 准备 db.sqlite3 文件。如果已经被 Docker 自动创建成目录:
```bash
sudo rm -rf db.sqlite3
# 然后重做 Step 7 + 8
```

### Q: cloudflared 容器一直 restarting
A: token 错误。回 Cloudflare Zero Trust 重新复制 token,改 compose 里 `command:` 行。

### Q: 浏览器开域名报 530 / 1033 / 1016
A: cloudflared 没连上 Cloudflare 边缘节点。
```bash
sudo docker logs cloudflared-rdgen | tail -20
# 看具体错误
```

### Q: 502 Bad Gateway
A: cloudflared 连上了但找不到 rdgen 容器。检查 Cloudflare Zero Trust → Public Hostname URL 是不是 `rdgen:8000`(service 名,不是 localhost / IP)。

### Q: 触发编译报 GHBEARER 错
A: GitHub PAT 权限不全。回 GitHub 重新生成 token,确保 Actions + Contents + Workflows 都是 R/W。

### Q: 编译完了 30 分钟没绿按钮
A: 看 GitHub Actions 那条 run:
```bash
gh run list --repo <你的用户名>/rustdesk-client --limit 3
```
如果 conclusion=failure,看 Build Windows 那个 job 是不是过了 Upload artifacts 步骤(过了就有产物,只是 send_to_rdgen 那步挂)。

更多见 [MAINTENANCE.md](MAINTENANCE.md)。
