#!/bin/bash
set -e

# pandoc 版本
PANDOC_VERSION="3.1.13"
PANDOC_TAR="pandoc-${PANDOC_VERSION}-linux-amd64.tar.gz"
PANDOC_URL="https://github.com/jgm/pandoc/releases/download/${PANDOC_VERSION}/${PANDOC_TAR}"

echo "📥 正在下载 pandoc v${PANDOC_VERSION}..."
curl -L $PANDOC_URL -o $PANDOC_TAR

echo "📦 正在解压 pandoc..."
tar -xzf $PANDOC_TAR

echo "🔧 配置 PATH..."
# 将 pandoc 放到项目本地的 bin 目录
mkdir -p "$PWD/bin"
mv pandoc-${PANDOC_VERSION}/bin/pandoc "$PWD/bin/"

# 确认可执行
chmod +x "$PWD/bin/pandoc"
"$PWD/bin/pandoc" --version

echo "✅ pandoc 安装完成"
