#!/bin/bash

# smth BBS tmux 管理函数集合
# 添加到 ~/.bashrc 或 ~/.zshrc

# 连接 smth 并自动重命名会话
smth() {
    local username=${1:-$(whoami)}
    local session_name="smth-${username}"
    
    if [ -n "$TMUX" ]; then
        # 在 tmux 会话中，重命名当前会话
        tmux rename-session "$session_name"
        echo "会话已重命名为: $session_name"
    else
        # 不在 tmux 中，创建新会话
        if tmux has-session -t "$session_name" 2>/dev/null; then
            echo "会话 $session_name 已存在，连接中..."
            tmux attach-session -t "$session_name"
        else
            echo "创建新会话: $session_name"
            tmux new-session -d -s "$session_name" -c "$HOME"
            tmux attach-session -t "$session_name"
        fi
    fi
    
    # 连接到 smth BBS
    telnet bbs.smth.edu.cn
}

# 列出所有 smth 相关的会话
smth-sessions() {
    echo "SMTH BBS 相关会话:"
    tmux list-sessions 2>/dev/null | grep "smth" || echo "未找到 smth 会话"
}

# 杀死所有 smth 会话
smth-cleanup() {
    local sessions=$(tmux list-sessions -F "#{session_name}" 2>/dev/null | grep "smth")
    if [ -n "$sessions" ]; then
        echo "清理 smth 会话:"
        echo "$sessions" | while read session; do
            echo "  杀死会话: $session"
            tmux kill-session -t "$session"
        done
    else
        echo "没有找到 smth 会话"
    fi
}

# 重命名当前会话为 smth 格式
rename-to-smth() {
    if [ -n "$TMUX" ]; then
        local username=${1:-$(whoami)}
        local new_name="smth-${username}"
        tmux rename-session "$new_name"
        echo "当前会话已重命名为: $new_name"
    else
        echo "错误: 不在 tmux 会话中"
        return 1
    fi
}