#!/bin/bash
# OpenCode 离线模式启用脚本 (Linux/macOS)
# 此脚本用于在 Linux/macOS 上设置离线模式环境变量

echo "============================================"
echo "OpenCode 离线模式配置"
echo "============================================"
echo ""
echo "此脚本将设置以下环境变量："
echo "  OPENCODE_DISABLE_MODELS_FETCH=1"
echo ""
echo "这样 OpenCode 就不会尝试从 models.dev 获取数据"
echo ""

# 检测 shell 类型
if [ -n "$ZSH_VERSION" ]; then
    PROFILE="$HOME/.zshrc"
elif [ -n "$BASH_VERSION" ]; then
    PROFILE="$HOME/.bashrc"
else
    PROFILE="$HOME/.profile"
fi

# 检查是否已经设置
if grep -q "OPENCODE_DISABLE_MODELS_FETCH" "$PROFILE" 2>/dev/null; then
    echo "✓ 离线模式已经在 $PROFILE 中配置"
    echo ""
    echo "如需立即生效，请运行:"
    echo "  source $PROFILE"
    echo ""
    echo "或者重新打开终端"
    echo ""
else
    # 添加到配置文件
    echo "" >> "$PROFILE"
    echo "# OpenCode 离线模式" >> "$PROFILE"
    echo "export OPENCODE_DISABLE_MODELS_FETCH=1" >> "$PROFILE"

    echo "✓ 已添加到 $PROFILE"
    echo ""
    echo "请运行以下命令使更改立即生效:"
    echo "  source $PROFILE"
    echo ""
    echo "或者重新打开终端"
    echo ""
fi

echo "然后运行: opencode auth login"
echo ""
