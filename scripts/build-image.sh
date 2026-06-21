#!/bin/bash
# build-image.sh — 一键 buildx amd64 + save tar.gz
# 用法: ./scripts/build-image.sh [TAG]
#   默认 TAG = v1
#   输出 rdgen-svchost-<TAG>.tar.gz 在仓库根目录

set -e

TAG="${1:-v1}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_TAR="$REPO_ROOT/rdgen-svchost-$TAG.tar.gz"

cd "$REPO_ROOT"

echo "[1/3] Python 语法检查..."
python3 -c "
import ast
for f in ['rdgenerator/forms.py', 'rdgenerator/views.py', 'rdgenerator/middleware.py', 'rdgen/settings.py', 'rdgen/urls.py']:
    try:
        ast.parse(open(f).read())
        print(f'  ✓ {f}')
    except SyntaxError as e:
        print(f'  ✗ {f}: {e}'); exit(1)
"

echo "[2/3] buildx 跨架构构建 amd64..."
docker buildx build --platform linux/amd64 -t rdgen-svchost:$TAG --load .

echo "[3/3] 打包 tar.gz..."
docker save rdgen-svchost:$TAG | gzip > "$OUT_TAR"

SIZE=$(du -h "$OUT_TAR" | cut -f1)
echo ""
echo "============================================"
echo "  ✅ 构建完成"
echo "  镜像: rdgen-svchost:$TAG"
echo "  文件: $OUT_TAR ($SIZE)"
echo "============================================"
echo ""
echo "下一步:"
echo "  scp $OUT_TAR liulei@10.10.10.10:/vol1/1000/Docker/rdgen-svchost/"
