#!/bin/sh
# ohos-install.sh — 下载、安装并签名 Icarus Verilog (HarmonyOS 版)
#
# 用法:
#   sh ohos-install.sh              # 安装最新版
#   sh ohos-install.sh <version>    # 安装指定版本 (如 v14.0-dev-ohos-1)
#
# 环境变量:
#   INSTALL_DIR  安装目录 (默认: $HOME/.iverilog-ohos)
#   REPO_URL     下载地址 (默认: GitHub release 地址)

set -e

# ── 配置 ──────────────────────────────────────────────────────
VERSION="${1:-latest}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.iverilog-ohos}"
REPO="${REPO_URL:-https://github.com/wotomchen/iverilog/releases/download}"

if [ "$VERSION" = "latest" ]; then
  # 从 GitHub API 获取最新 release 版本号
  echo "⏳ 获取最新版本号..."
  LATEST=$(curl -s --connect-timeout 30 \
    https://api.github.com/repos/wotomchen/iverilog/releases/latest \
    | grep '"tag_name"' | sed 's/.*"tag_name": "\(.*\)",/\1/' 2>/dev/null || echo "")
  if [ -z "$LATEST" ]; then
    echo "❌ 无法获取最新版本，请手动指定版本号"
    echo "   用法: sh ohos-install.sh v14.0-dev-ohos-1"
    exit 1
  fi
  VERSION="$LATEST"
fi

ARCHIVE="iverilog-ohos-${VERSION}.tar.gz"
URL="${REPO}/${VERSION}/${ARCHIVE}"

echo "═══════════════════════════════════════════"
echo " Icarus Verilog HarmonyOS 安装脚本"
echo "═══════════════════════════════════════════"
echo ""
echo "  版本:     $VERSION"
echo "  下载:     $URL"
echo "  安装到:   $INSTALL_DIR"
echo ""

# ── 创建临时目录 ─────────────────────────────────────────────
TMPDIR="${TMPDIR:-$HOME/tmp}"
mkdir -p "$TMPDIR"
TMP_FILE="$TMPDIR/iverilog-ohos-$$.tar.gz"

# ── 下载 ──────────────────────────────────────────────────────
echo "📥 下载 $ARCHIVE ..."
curl -L --connect-timeout 60 -o "$TMP_FILE" "$URL" 2>&1
if [ ! -f "$TMP_FILE" ] || [ ! -s "$TMP_FILE" ]; then
  echo "❌ 下载失败: $URL"
  exit 1
fi
echo "✅ 下载完成 ($(du -h "$TMP_FILE" | cut -f1))"

# ── 创建安装目录 ─────────────────────────────────────────────
mkdir -p "$INSTALL_DIR"

# ── 解压 ──────────────────────────────────────────────────────
echo "📦 解压到 $INSTALL_DIR ..."
tar -xzf "$TMP_FILE" -C "$INSTALL_DIR" --strip-components=1 2>/dev/null || \
tar -xzf "$TMP_FILE" -C "$INSTALL_DIR"
echo "✅ 解压完成"

# ── 清理临时文件 ─────────────────────────────────────────────
rm -f "$TMP_FILE"

# ── 签名 ──────────────────────────────────────────────────────
echo "🔑 签名 ELF 二进制文件..."
SIGN_COUNT=0
find "$INSTALL_DIR" -type f | while read f; do
  if file "$f" 2>/dev/null | grep -q "ELF"; then
    # 检查是否已签名
    if binary-sign-tool sign -inFile "$f" -outFile /dev/null -selfSign "1" 2>/dev/null; then
      :  # 已签名，跳过
    else
      echo "   签名: ${f#$INSTALL_DIR/}"
      mv "$f" "${f}-unsigned" 2>/dev/null || true
      if binary-sign-tool sign -inFile "${f}-unsigned" -outFile "$f" -selfSign "1" 2>/dev/null; then
        chmod +x "$f"
        rm -f "${f}-unsigned"
        SIGN_COUNT=$((SIGN_COUNT + 1))
      else
        echo "   ⚠️  签名失败: ${f#$INSTALL_DIR/}"
        mv "${f}-unsigned" "$f" 2>/dev/null || true
      fi
    fi
  fi
done
echo "✅ 签名完成 (${SIGN_COUNT} 个文件)"

# ── PATH 提示 ─────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════"
echo " ✅ 安装成功!"
echo "═══════════════════════════════════════════"
echo ""
echo "将以下内容添加到 ~/.profile 或 ~/.zshrc:"
echo ""
echo "  export PATH=\"\$PATH:$INSTALL_DIR/bin\""
echo ""
echo "然后执行:"
echo ""
echo "  source ~/.profile"
echo "  iverilog -V"
echo ""
