#!/bin/bash

# SMTH BBS 启动器 - 选择原版或增强版

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORIGINAL_SCRIPT="/Users/zoubenjia/scripts/smth.tcl"
ROBUST_SCRIPT="$SCRIPT_DIR/smth-robust.tcl"

echo "🚀 SMTH BBS 连接启动器"
echo "====================="

# 检查参数
if [[ "$1" == "--robust" || "$1" == "-r" ]]; then
    USE_ROBUST=true
    shift
elif [[ "$1" == "--original" || "$1" == "-o" ]]; then
    USE_ROBUST=false
    shift
else
    # 默认选择
    echo "选择连接模式:"
    echo "  1) 🛡️ 增强版 (防掉线、自动重连)"
    echo "  2) 📱 原版 (简单连接)"
    echo ""
    read -p "请选择 [1]: " choice
    case $choice in
        2) USE_ROBUST=false ;;
        *) USE_ROBUST=true ;;
    esac
fi

# 准备参数
ARGS="$@"

if [ "$USE_ROBUST" = true ]; then
    echo "🛡️ 使用增强版 SMTH 脚本"
    echo "功能特性:"
    echo "  • 自动检测掉线并重连"
    echo "  • 每2分钟心跳保持连接"
    echo "  • 最多5次重连尝试"
    echo "  • Ctrl+R 手动重连"
    echo ""
    
    if [ ! -f "$ROBUST_SCRIPT" ]; then
        echo "❌ 增强版脚本不存在: $ROBUST_SCRIPT"
        exit 1
    fi
    
    exec "$ROBUST_SCRIPT" $ARGS
else
    echo "📱 使用原版 SMTH 脚本"
    echo ""
    
    if [ ! -f "$ORIGINAL_SCRIPT" ]; then
        echo "❌ 原版脚本不存在: $ORIGINAL_SCRIPT"
        exit 1
    fi
    
    exec "$ORIGINAL_SCRIPT" $ARGS
fi