# 维护手册 — 改东西 + 排错

## 🎯 改动场景速查表

| 改了什么 | 走哪条流程 |
|---|---|
| GitHub workflow YAML (`.github/workflows/*.yml`) | [A 流程: 只 push GitHub](#a-流程-改-workflow-yaml) |
| rdgen Python 代码 (views.py / forms.py / middleware.py 等) | [B 流程: 重 build 镜像](#b-流程-改-rdgen-python-代码) |
| Django 模板 (`*.html`) | [B 流程](#b-流程-改-rdgen-python-代码) |
| `docker-compose.yml` 的 env (改密码 / 改 URL 等) | [C 流程: 改 yml + restart](#c-流程-改-docker-compose-env) |
| Cloudflare token 过期 | [D 流程: rotate token](#d-流程-cloudflare-token-rotate) |
| Basic Auth 密码 rotate | [E 流程: 改 env + restart](#e-流程-改-basic-auth-密码) |
| GitHub PAT 过期 | [F 流程: 换 PAT](#f-流程-github-pat-过期) |
| svchost 表单/逻辑改动 | [B 流程](#b-流程-改-rdgen-python-代码) |

---

## A 流程: 改 workflow YAML

**适用**: 改 `.github/workflows/generator-*.yml`(给 runner 加新步骤、改 sed 命令、加新 if 分支等)。

```bash
# 1. 在 Mac 上改代码
cd /Users/liulei/Downloads/rustdesk-builder
nano .github/workflows/generator-windows.yml

# 2. commit + push 到 fork 的 master
git add .github/workflows/
git commit -m "patch: workflow xxx"
git push origin svchost-cn:master   # 注意 push 到 master, 因为 rdgen 触发的是 master
```

**NAS 零操作**——下次任何编译会自动用新 workflow。

### 验证

```bash
# 验证 master 上 commit 是不是最新的
gh api repos/liuleiliulei/rustdesk-client/branches/master --jq '.commit.commit.message'
```

---

## B 流程: 改 rdgen Python 代码

**适用**: 改 `rdgenerator/*.py` 或 `rdgenerator/templates/*.html` 或 `rdgen/settings.py`。

### B.1 在 Mac 上改 + 重 build

```bash
cd /Users/liulei/Downloads/rustdesk-builder

# 1. 改代码
nano rdgenerator/views.py

# 2. 语法检查
python3 -c "import ast; ast.parse(open('rdgenerator/views.py').read()); print('OK')"

# 3. buildx amd64 (跟 NAS 架构对齐)
docker buildx build --platform linux/amd64 -t rdgen-svchost:v1 --load .

# 4. 打包 tar.gz
docker save rdgen-svchost:v1 | gzip > /Users/liulei/Downloads/rdgen-svchost-v1.tar.gz
```

### B.2 传 NAS + 重启

```bash
# scp 新镜像 (60MB, ~10 秒)
scp /Users/liulei/Downloads/rdgen-svchost-v1.tar.gz liulei@10.10.10.10:/vol1/1000/Docker/rdgen-svchost/

# SSH 进 NAS
ssh liulei@10.10.10.10
cd /vol1/1000/Docker/rdgen-svchost/

# 停旧容器
sudo docker stop rustdesk-builder-nas
sudo docker rm rustdesk-builder-nas
sudo docker rmi rdgen-svchost:v1

# 加载新镜像
sudo docker load -i rdgen-svchost-v1.tar.gz

# 启动 (cloudflared 不动)
sudo docker compose -f docker-compose.nas-cloudflared.yml up -d
sudo docker logs rustdesk-builder-nas | tail -10
```

### B.3 验证

```bash
# 浏览器隐身窗口访问 https://rdgen.aliu.eu.org/
# 1. Basic Auth 弹窗仍出现
# 2. 输入用户名/密码进入
# 3. 看你改的新功能 (新表单字段 / 新按钮等) 是否生效
```

⚠️ **不要用 `docker compose up --build`**——这会让 Docker 把 `db.sqlite3` 当目录创建,容器起不来。务必走 `docker load -i tar.gz` 路径。

---

## C 流程: 改 docker-compose env

**适用**: 改 GHBEARER / GENURL / 端口 / 加新 env 变量等(不动镜像本身)。

### C.1 NAS 上改

```bash
ssh liulei@10.10.10.10
cd /vol1/1000/Docker/rdgen-svchost/

# 备份 (rotate 前万一改坏)
cp docker-compose.nas-cloudflared.yml docker-compose.nas-cloudflared.yml.bak

# 改
nano docker-compose.nas-cloudflared.yml
```

### C.2 重启 (无需重 build)

```bash
# 推荐用 up -d (会自动 recreate 配置变了的容器)
sudo docker compose -f docker-compose.nas-cloudflared.yml up -d

# 或仅 restart 不重建 (env 变化不会生效,慎用)
# sudo docker compose -f docker-compose.nas-cloudflared.yml restart

# 看新 env 是否生效
sudo docker exec rustdesk-builder-nas env | grep -E "GHBEARER|GENURL|BASIC_AUTH"
```

---

## D 流程: Cloudflare token rotate

**触发场景**: token 泄露 / Zero Trust 后台手动 rotate / token 自然过期。

### D.1 Cloudflare 后台

1. 进 Zero Trust → Networks → Tunnels
2. 点 `rdgen-svchost` → 顶部 **Configure**
3. 找到 **Connectors** 标签 → 右上 **Refresh Token** 或重新 install
4. 复制新 token

### D.2 NAS 上改 compose

```bash
ssh liulei@10.10.10.10
cd /vol1/1000/Docker/rdgen-svchost/

# 改 command 行的 token
nano docker-compose.nas-cloudflared.yml
# 找 command: tunnel --no-autoupdate run --token <旧>
# 改成        command: tunnel --no-autoupdate run --token <新>

# 重启 cloudflared
sudo docker compose -f docker-compose.nas-cloudflared.yml up -d cloudflared

# 验证连接
sudo docker logs cloudflared-rdgen 2>&1 | tail -10
# 看到 "Registered tunnel connection" = 成功
```

---

## E 流程: 改 Basic Auth 密码

```bash
# Mac 上生成新密码
NEW_PWD=$(python3 -c "import secrets; print(secrets.token_urlsafe(24))")
echo "新密码: $NEW_PWD"  # 记到密码管理器

# SSH 进 NAS
ssh liulei@10.10.10.10
cd /vol1/1000/Docker/rdgen-svchost/

# 改 compose
sudo sed -i 's|^      BASIC_AUTH_PASSWORD: ".*"|      BASIC_AUTH_PASSWORD: "新密码贴这"|' docker-compose.nas-cloudflared.yml

# 重启 rdgen (cloudflared 不动)
sudo docker compose -f docker-compose.nas-cloudflared.yml up -d rdgen

# 验证 (浏览器隐身窗口, 输新密码能进, 旧密码 401)
curl -sI -u "admin:$NEW_PWD" https://rdgen.aliu.eu.org/
# 期望 HTTP/2 200
```

---

## F 流程: GitHub PAT 过期

```bash
# 1. https://github.com/settings/tokens?type=beta 重新申请 fine-grained PAT
#    权限同原来: Actions(R/W), Contents(R/W), Workflows(R/W), Metadata(R)
#    给 fork 仓库 liuleiliulei/rustdesk-client 单独授权

# 2. 走 C 流程改 docker-compose.nas-cloudflared.yml 里的 GHBEARER
#    然后 sudo docker compose -f xxx up -d
```

---

## 🔍 排错速查

### 浏览器报 401 但密码对的

```bash
# 1. 看 rdgen 内存里的 env (容器里)
sudo docker exec rustdesk-builder-nas env | grep BASIC_AUTH
# 应看到 BASIC_AUTH_USERNAME=admin + BASIC_AUTH_PASSWORD=xxx

# 2. 如果 env 是空, 说明 compose 改了 yml 但没 up -d 触发 recreate
sudo docker compose -f docker-compose.nas-cloudflared.yml up -d --force-recreate rdgen
```

### 编译触发后 rdgen 报 SSL EOF

```python
# 已经加 SSL retry helper 在 views.py:_gh_post / _gh_get
# 8 次重试都失败 = 网络真断, 不是代码 bug
# 看日志
sudo docker logs rustdesk-builder-nas 2>&1 | grep -i retry
```

### 编译完没绿按钮 (waiting 页一直转)

```bash
# 1. 看 rdgen 轮询的 GithubRun 记录
sudo docker exec rustdesk-builder-nas python3 -c "
import django, os
os.environ['DJANGO_SETTINGS_MODULE']='rdgen.settings'
django.setup()
from rdgenerator.models import GithubRun
for r in GithubRun.objects.all():
    print(r.id, r.uuid, r.github_run_id, r.status)
"

# 2. 状态 != success/artifact_ok = 还没识别 artifact
# 手动看 GitHub run 状态
gh run view <run_id> --repo liuleiliulei/rustdesk-client
```

### docker compose up --build 之后 db 丢了

**症状**: 编译过的历史都没了, waiting 页 404。

**根因**: `--build` 重建容器, 之前没挂卷 db.sqlite3 就丢了。

**预防**: NAS 上的 compose 一定要有 `./db.sqlite3:/opt/rdgen/db.sqlite3` 挂卷。

**恢复**: 没法恢复 (除非有 db.sqlite3 备份)。建议每周 cron 备份:

```bash
# 每周一凌晨 3 点备份 db
echo "0 3 * * 1 cp /vol1/1000/Docker/rdgen-svchost/db.sqlite3 /vol1/backup/rdgen-db-\$(date +\%Y\%m\%d).sqlite3" | crontab -
```

### Cloudflare 隧道断了

```bash
# 看 cloudflared 是否在跑
sudo docker compose -f docker-compose.nas-cloudflared.yml ps cloudflared

# 看连接错误
sudo docker logs cloudflared-rdgen 2>&1 | tail -30

# 重启 cloudflared
sudo docker compose -f docker-compose.nas-cloudflared.yml restart cloudflared

# 等 30 秒, 浏览器测
curl -sI https://rdgen.aliu.eu.org/
# 期望 HTTP/2 401 = 通了
```

### 编译用了 30 分钟还没完?

正常 Win 编译 30-45 分钟,**第一次没 cache 可能 50 分钟**。看进度:

```bash
gh run view <run_id> --repo liuleiliulei/rustdesk-client | head -20

# 看具体步骤
gh run view --job <job_id> --repo liuleiliulei/rustdesk-client | grep -E "^  [✓X*-]" | tail -20
```

---

## 🔄 升级 rdgen 到上游新版本

如果上游 wztx/rustdesk-client 有重要更新想合进来:

```bash
cd /Users/liulei/Downloads/rustdesk-builder

# 拉上游
git remote add upstream https://github.com/wztx/rustdesk-client.git
git fetch upstream

# 看新 commit
git log upstream/master..master --oneline

# merge (可能有冲突, 重点看 forms.py / views.py / templates)
git merge upstream/master

# 解决冲突, 测试本机能跑
docker compose up -d --build
# 开 http://localhost:8000 验证

# 走 B 流程 push + 部署到 NAS
```

---

## 📦 备份/恢复

### 关键文件备份清单

| 文件 | 频率 | 位置 |
|---|---|---|
| `db.sqlite3` | 每周 | 备份到 `/vol1/backup/` |
| `docker-compose.nas-cloudflared.yml` | 每次改 | git 一份在 fork 仓库 (脱敏) |
| Cloudflare token + GHBEARER + Basic Auth 密码 | 一次性 | 密码管理器 (1Password/Bitwarden) |

### 全量备份命令

```bash
ssh liulei@10.10.10.10 'sudo tar czf - /vol1/1000/Docker/rdgen-svchost/' > rdgen-backup-$(date +%Y%m%d).tar.gz
```

### 全量恢复

```bash
# 解压到新位置
sudo tar xzf rdgen-backup-xxxxxx.tar.gz -C /
# 改路径
mv /vol1/1000/Docker/rdgen-svchost/ /your/new/path/
# 走 DEPLOY.md Step 8 启动
```

---

## 📊 健康度自检 (每月跑一次)

```bash
# 1. Cloudflare 隧道仍活跃
curl -sI https://rdgen.aliu.eu.org/ | head -1
# 期望: HTTP/2 401

# 2. 容器在跑
sudo docker compose -f docker-compose.nas-cloudflared.yml ps
# 期望: rdgen + cloudflared 都 Up

# 3. db.sqlite3 还在挂卷
ls -lh /vol1/1000/Docker/rdgen-svchost/db.sqlite3
# 期望: -rw- 开头, 不是 d 开头

# 4. GitHub PAT 没过期 (用一个非破坏性 API 调)
curl -sH "Authorization: Bearer $YOUR_PAT" https://api.github.com/user | jq .login
# 期望: 你的 GitHub 用户名

# 5. 触发一次小测试编译, 看绿按钮能出现
```
