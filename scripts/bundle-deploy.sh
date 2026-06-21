#!/bin/bash
# bundle-deploy.sh — 一键打包部署 bundle
# 用法: ./scripts/bundle-deploy.sh [TAG]
#
# 生成 deploy-bundle.tar.gz, 含:
#   - rdgen-svchost-<TAG>.tar.gz (Docker 镜像)
#   - docker-compose.yml.template (脱敏 compose 模板)
#   - db.sqlite3 (空 DB 种子)
#   - 完整 docs/ 目录
#   - README.md
#
# scp 到新机器解压即可参照 docs/DEPLOY.md 部署

set -e

TAG="${1:-v1}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE_DIR="$REPO_ROOT/build/deploy-bundle"
OUT_BUNDLE="$REPO_ROOT/deploy-bundle.tar.gz"

cd "$REPO_ROOT"

# 0. 必备文件检查
[ ! -f "rdgen-svchost-$TAG.tar.gz" ] && {
    echo "[!] 找不到镜像 rdgen-svchost-$TAG.tar.gz"
    echo "    先跑 ./scripts/build-image.sh $TAG"
    exit 1
}

echo "[1/5] 清空旧 bundle 工作区..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/docs" "$BUNDLE_DIR/scripts"

echo "[2/5] 复制核心文件..."
cp "rdgen-svchost-$TAG.tar.gz" "$BUNDLE_DIR/"
cp README.md "$BUNDLE_DIR/"
cp docs/{DEPLOY,MAINTENANCE,ARCHITECTURE,COOKBOOK}.md "$BUNDLE_DIR/docs/"
cp scripts/fix-svchost-mac.sh "$BUNDLE_DIR/scripts/"

echo "[3/5] 生成 db.sqlite3 种子 (从镜像里抽)..."
TMPC=$(docker create rdgen-svchost:$TAG)
docker cp "$TMPC":/opt/rdgen/db.sqlite3 "$BUNDLE_DIR/db.sqlite3"
docker rm "$TMPC" > /dev/null

echo "[4/5] 生成脱敏 docker-compose 模板..."
cat > "$BUNDLE_DIR/docker-compose.yml.template" <<'EOF'
# docker-compose.yml.template
# 复制此文件为 docker-compose.yml, 填好 10 个 <CHANGE_ME> 后再 docker compose up -d
#
# 必填: GHBEARER / GHUSER / GENURL / SECRET_KEY / ZIP_PASSWORD / SH_SECRET /
#       BASIC_AUTH_PASSWORD / cloudflared TOKEN
# 可选: 改 cloudflared 镜像源 (国内拉 Docker Hub 慢就加 docker.1ms.run/ 前缀)

services:
  rdgen:
    image: rdgen-svchost:v1
    restart: unless-stopped
    container_name: rustdesk-builder-nas
    environment:
      DEBUG: "True"
      SECRET_KEY: "<CHANGE_ME: python3 -c 'import secrets; print(secrets.token_hex(50))' 生成>"
      GHUSER: "<CHANGE_ME: 你的 GitHub 用户名>"
      GHBEARER: "<CHANGE_ME: GitHub fine-grained PAT>"
      GENURL: "https://rdgen.<CHANGE_ME: 你的域名>"
      PROTOCOL: "https"
      ZIP_PASSWORD: "<CHANGE_ME: token_urlsafe(24)>"
      REPONAME: "rustdesk-client"
      GHBRANCH: "master"
      SH_SECRET: "<CHANGE_ME: token_urlsafe(24)>"
      BASIC_AUTH_USERNAME: "admin"
      BASIC_AUTH_PASSWORD: "<CHANGE_ME: token_urlsafe(24)>"
    dns:
      - 8.8.8.8
      - 1.1.1.1
    volumes:
      - ./exe:/opt/rdgen/exe
      - ./png:/opt/rdgen/png
      - ./temp_zips:/opt/rdgen/temp_zips
      - ./db.sqlite3:/opt/rdgen/db.sqlite3
    healthcheck:
      test: ["CMD", "wget", "--spider", "0.0.0.0:8000"]
      interval: 30s
      timeout: 5s
      retries: 3

  cloudflared:
    # 国内拉 Docker Hub 慢, 可换成 docker.1ms.run/cloudflare/cloudflared:latest
    image: docker.1ms.run/cloudflare/cloudflared:latest
    restart: unless-stopped
    container_name: cloudflared-rdgen
    depends_on:
      - rdgen
    command: tunnel --no-autoupdate run --token <CHANGE_ME: Cloudflare Zero Trust 复制的 token>
EOF

echo "[5/5] 打包 deploy-bundle.tar.gz..."
cd "$REPO_ROOT/build"
tar czf "$OUT_BUNDLE" deploy-bundle/

SIZE=$(du -h "$OUT_BUNDLE" | cut -f1)
echo ""
echo "============================================"
echo "  ✅ Bundle 完成"
echo "  文件: $OUT_BUNDLE ($SIZE)"
echo "  内容:"
ls -la "$BUNDLE_DIR" | tail -n +4 | awk '{print "    "$NF" ("$5" bytes)"}'
echo "============================================"
echo ""
echo "下一步:"
echo "  scp $OUT_BUNDLE TARGET_USER@TARGET_HOST:/path/"
echo "  然后照 docs/DEPLOY.md 走"
