#!/bin/bash

# 增强版 SMTH 连接脚本 - 内置防掉线和自动重连

USERNAME=${1:-"guest"}
SESSION_NAME="smth-${USERNAME}"
CURRENT_SESSION=$(tmux display-message -p '#S' 2>/dev/null)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔗 连接到 SMTH BBS (用户: $USERNAME)"
echo "================================="

# 检查是否在 tmux 会话中
if [ -n "$TMUX" ]; then
    echo "📱 在现有 tmux 会话中: $CURRENT_SESSION"
    echo "🏷️ 重命名为: $SESSION_NAME"
    tmux rename-session "$SESSION_NAME"
    NEW_WINDOW=false
else
    echo "🆕 创建新的 tmux 会话: $SESSION_NAME"
    if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        echo "📋 会话已存在，连接中..."
        tmux attach-session -t "$SESSION_NAME"
        exit 0
    else
        tmux new-session -d -s "$SESSION_NAME" -c "$HOME"
        tmux attach-session -t "$SESSION_NAME" &
        NEW_WINDOW=true
    fi
fi

# 等待一下确保窗口创建完成
sleep 2

echo "🚀 启动防掉线监控..."
if ! pgrep -f "smth-keepalive.sh" > /dev/null; then
    $SCRIPT_DIR/smth-keepalive.sh start
    if [ $? -eq 0 ]; then
        echo "✅ 防掉线监控已启动"
    else
        echo "⚠️ 防掉线监控启动失败，但继续连接"
    fi
else
    echo "✅ 防掉线监控已在运行"
fi

echo "🌐 正在连接到 SMTH BBS..."

# 使用 expect 脚本进行智能连接（如果存在）
if [ -f "$HOME/scripts/smth.tcl" ]; then
    echo "📋 使用现有的 expect 脚本连接"
    expect -f "$HOME/scripts/smth.tcl"
else
    # 直接使用 telnet 连接
    echo "🔌 使用 telnet 直接连接"
    echo ""
    echo "💡 提示："
    echo "  - 连接后会自动检测掉线并重连"
    echo "  - 每2分钟发送一次心跳保持连接"
    echo "  - 窗口会自动重命名显示登录状态"
    echo ""
    
    # 连接到 SMTH BBS
    telnet bbs.smth.edu.cn
fi

echo ""
echo "👋 SMTH BBS 会话结束"