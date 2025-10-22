#!/bin/bash

# smth BBS 连接脚本，支持 tmux 会话重命名
# 使用方法: ./smth-connect.sh [用户名]

USERNAME=${1:-"anonymous"}
SESSION_NAME="smth-${USERNAME}"
CURRENT_SESSION=$(tmux display-message -p '#S' 2>/dev/null)

# 检查是否在 tmux 会话中
if [ -n "$TMUX" ]; then
    echo "检测到当前在 tmux 会话中: $CURRENT_SESSION"
    echo "重命名会话为: $SESSION_NAME"
    tmux rename-session "$SESSION_NAME"
else
    echo "创建新的 tmux 会话: $SESSION_NAME"
    tmux new-session -d -s "$SESSION_NAME"
    tmux attach-session -t "$SESSION_NAME"
fi

# 连接到 smth BBS
echo "正在连接到 smth BBS..."
telnet bbs.smth.edu.cn