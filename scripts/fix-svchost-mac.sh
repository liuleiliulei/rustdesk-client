#!/bin/bash
# fix-svchost.sh — 一键修 svchost.app 在 Mac 上的签名 + 隔离问题
# 用法:
#   fix-svchost.sh                              # 默认修 /Applications/svchost.app
#   fix-svchost.sh ~/Downloads/svchost.app      # 修指定路径
#   fix-svchost.sh ~/Downloads/svchost-aarch64.dmg  # 同时挂 dmg + 修 app

set -e

# === 配置 ===
APP_DEFAULT="/Applications/svchost.app"
APP="${1:-$APP_DEFAULT}"

# === 如果传的是 dmg, 先挂载并复制出来 ===
if [[ "$APP" == *.dmg ]]; then
    echo "[1/5] 检测到 .dmg, 先去 quarantine + 挂载..."
    xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true
    MOUNT=$(hdiutil attach "$APP" -nobrowse | grep -oE "/Volumes/[^ ]+" | head -1)
    [ -z "$MOUNT" ] && { echo "[x] dmg 挂载失败"; exit 1; }
    SRC_APP=$(find "$MOUNT" -maxdepth 2 -name "svchost.app" | head -1)
    [ -z "$SRC_APP" ] && { echo "[x] 挂载点里没找到 svchost.app"; exit 1; }
    echo "[1/5] 复制 $SRC_APP → /Applications/"
    sudo rm -rf /Applications/svchost.app 2>/dev/null
    sudo cp -R "$SRC_APP" /Applications/
    hdiutil detach "$MOUNT" -quiet
    APP="/Applications/svchost.app"
fi

# === 校验路径 ===
[ ! -d "$APP" ] && { echo "[x] 找不到 .app: $APP"; exit 1; }

echo "[2/5] 去 quarantine 属性..."
sudo xattr -dr com.apple.quarantine "$APP"

echo "[3/5] 重签所有 framework + dylib..."
if [ -d "$APP/Contents/Frameworks" ]; then
    for fw in "$APP/Contents/Frameworks"/*.framework; do
        [ -d "$fw" ] && sudo codesign --remove-signature "$fw" 2>/dev/null
        [ -d "$fw" ] && sudo codesign --force --sign - "$fw" 2>/dev/null
    done
    for dylib in "$APP/Contents/Frameworks"/*.dylib; do
        [ -f "$dylib" ] && sudo codesign --force --sign - "$dylib" 2>/dev/null
    done
fi

echo "[4/5] 重签 MacOS 主二进制..."
for bin in "$APP/Contents/MacOS"/*; do
    [ -f "$bin" ] && sudo codesign --force --sign - "$bin" 2>/dev/null
done

echo "[5/5] 重签 .app 整体..."
sudo codesign --force --sign - "$APP"

echo ""
echo "[验证] codesign --verify ..."
codesign --verify --verbose "$APP" 2>&1 | head -5

echo ""
echo "✅ 完成! 现在双击 $APP 应该能打开"
echo "   或命令行: open '$APP'"
