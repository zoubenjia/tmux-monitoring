#!/bin/bash

# 设置监控脚本自动启动

PLIST_FILE="$HOME/Library/LaunchAgents/com.personal.tmux-monitor.plist"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔧 设置 TMux 监控自动启动"
echo "========================="

# 检查 LaunchAgent 文件是否存在
if [ -f "$PLIST_FILE" ]; then
    echo "✅ LaunchAgent 配置文件已存在"
else
    echo "❌ LaunchAgent 配置文件不存在，请先运行脚本创建"
    exit 1
fi

# 卸载可能存在的服务
echo "🛑 卸载已存在的服务..."
launchctl unload "$PLIST_FILE" 2>/dev/null || true

# 加载服务
echo "🚀 加载自动启动服务..."
launchctl load "$PLIST_FILE"

# 检查服务状态
echo "📊 检查服务状态..."
if launchctl list | grep -q "com.personal.tmux-monitor"; then
    echo "✅ 服务已成功加载"
else
    echo "❌ 服务加载失败"
    exit 1
fi

echo ""
echo "🎉 自动启动设置完成！"
echo ""
echo "特性:"
echo "  • 系统启动时自动运行"
echo "  • 每5分钟检查一次监控状态"
echo "  • 自动清理冲突的监控进程"
echo "  • 确保只有增强版监控运行"
echo ""
echo "管理命令:"
echo "  查看状态: launchctl list | grep tmux-monitor"
echo "  停用服务: launchctl unload $PLIST_FILE"
echo "  启用服务: launchctl load $PLIST_FILE"
echo "  查看日志: tail -f ~/.claude-monitor/launchagent.log"