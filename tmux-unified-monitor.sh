#!/bin/bash

# ==============================================================================
# Tmux 统一监控系统 - 避免冲突和乱码
# ==============================================================================
# 设计原则：
# 1. SSH/CD 由函数包装处理（立即响应）
# 2. 其他程序由后台监控处理（定期检测）
# 3. 避免终端控制序列查询
# 4. 使用标记避免重复重命名
# ==============================================================================

# 配置
MONITOR_CONFIG_DIR="$HOME/.tmux-monitor"
MONITOR_PID_FILE="$MONITOR_CONFIG_DIR/monitor.pid"
MONITOR_LOG_FILE="$MONITOR_CONFIG_DIR/monitor.log"
MONITOR_ENABLED_FILE="$MONITOR_CONFIG_DIR/enabled"

# 创建配置目录
[[ ! -d "$MONITOR_CONFIG_DIR" ]] && mkdir -p "$MONITOR_CONFIG_DIR"

# ==============================================================================
# Part 1: 即时响应的函数包装（SSH/CD）
# ==============================================================================

# 只在 tmux 环境中定义这些函数
if [[ -n "$TMUX" ]]; then
    
    # SSH 命令包装 - 立即重命名
    ssh() {
        local hostname=""
        
        # 解析主机名
        for arg in "$@"; do
            if [[ "$arg" =~ ^[^-].+@.+ ]]; then
                hostname="${arg##*@}"
                break
            elif [[ "$arg" =~ ^[^-@]+$ ]] && [[ ! "$arg" =~ ^- ]]; then
                hostname="$arg"
                break
            fi
        done
        
        # 设置窗口名并添加标记，告诉 monitor 不要覆盖
        if [[ -n "$hostname" ]]; then
            tmux rename-window "ssh:$hostname" 2>/dev/null
            tmux set-window-option -q @monitor_skip 1 2>/dev/null
        fi
        
        # 执行 SSH
        command ssh "$@"
        local ssh_result=$?
        
        # SSH 结束后移除标记，允许 monitor 接管
        tmux set-window-option -q -u @monitor_skip 2>/dev/null
        
        return $ssh_result
    }
    
    # CD 命令包装 - 立即更新目录名
    cd() {
        builtin cd "$@"
        local result=$?
        
        # 成功切换目录后，如果没有特殊程序运行，更新窗口名
        if [[ $result -eq 0 ]]; then
            # 检查是否应该跳过（有 monitor 在管理特殊程序）
            local skip=$(tmux show-window-option -qv @monitor_skip 2>/dev/null)
            if [[ "$skip" != "1" ]]; then
                local dir_name=$(basename "$(pwd)")
                tmux rename-window "$dir_name" 2>/dev/null
            fi
        fi
        
        return $result
    }
fi

# ==============================================================================
# Part 2: 后台监控守护进程（其他程序检测）
# ==============================================================================

# 监控守护进程脚本内容
create_monitor_daemon() {
    cat << 'DAEMON_SCRIPT' > "$MONITOR_CONFIG_DIR/daemon.sh"
#!/bin/bash

# 配置
LOG_FILE="$HOME/.tmux-monitor/monitor.log"
CHECK_INTERVAL=3

# 简单日志（只在调试模式）
log() {
    [[ "$DEBUG" == "1" ]] && echo "[$(date '+%H:%M:%S')] $*" >> "$LOG_FILE"
}

# 获取进程树（不使用终端控制序列）
get_process_info() {
    local pane_pid="$1"
    local all_commands=""

    # 主进程
    local main_process=$(ps -p "$pane_pid" -o command= 2>/dev/null)
    all_commands+="$main_process "

    # 递归查找子进程（使用 ps 和 awk，更可靠）
    find_children_recursive() {
        local parent_pid="$1"
        local depth="$2"

        [[ "$depth" -gt 4 ]] && return

        # 使用 ps 和 awk 查找所有子进程
        local children=$(ps -o pid,ppid,command | awk -v parent="$parent_pid" '$2 == parent {print $1}')

        for child_pid in $children; do
            if [[ -n "$child_pid" ]] && [[ "$child_pid" != "PID" ]]; then
                local child_cmd=$(ps -p "$child_pid" -o command= 2>/dev/null)
                all_commands+="$child_cmd "
                find_children_recursive "$child_pid" $((depth + 1))
            fi
        done
    }

    find_children_recursive "$pane_pid" 1

    echo "$all_commands"
}

# 获取 Claude/Q 进程的 CPU 使用率
get_claude_cpu() {
    local pane_pid="$1"

    # 递归查找所有子进程
    find_all_pids() {
        local parent_pid="$1"
        local depth="$2"

        [[ "$depth" -gt 4 ]] && return

        local children=$(ps -o pid,ppid | awk -v parent="$parent_pid" '$2 == parent {print $1}')

        for child_pid in $children; do
            if [[ -n "$child_pid" ]] && [[ "$child_pid" != "PID" ]]; then
                echo "$child_pid"
                find_all_pids "$child_pid" $((depth + 1))
            fi
        done
    }

    # 查找 Claude 或 Q 进程
    for pid in $pane_pid $(find_all_pids "$pane_pid" 1); do
        cmd=$(ps -p "$pid" -o command= 2>/dev/null)
        if echo "$cmd" | grep -qi "claude.*--verbose\|claude.*--permission-mode\|/q.*chat\|Amazon.*Q"; then
            # 获取 CPU 使用率
            cpu=$(ps -p "$pid" -o %cpu= 2>/dev/null | awk '{print int($1)}')
            echo "$cpu"
            return
        fi
    done

    echo "0"
}

# 检测程序类型
detect_program() {
    local process_info="$1"
    
    # Claude（使用与旧脚本相同的模式）
    if echo "$process_info" | grep -qi "claude.*chat\|claude --verbose\|claude.*--permission-mode\|^claude "; then
        echo "claude"
    # Amazon Q
    elif echo "$process_info" | grep -qi "Amazon.*Q.*chat\|/q.*chat"; then
        echo "amazon-q"
    # SMTH BBS
    elif echo "$process_info" | grep -qi "smth.*tcl\|smth-robust"; then
        echo "smth"
    # Vim
    elif echo "$process_info" | grep -qE "(^|/)n?vim?\s"; then
        echo "vim"
    # Python
    elif echo "$process_info" | grep -qE "(^|/)python[0-9]*\s"; then
        echo "python"
    # Docker
    elif echo "$process_info" | grep -qi "docker"; then
        echo "docker"
    # Git
    elif echo "$process_info" | grep -qE "(^|/)git\s"; then
        echo "git"
    else
        echo ""
    fi
}

# 主循环
log "Monitor daemon started (PID: $$)"

while true; do
    # 检查是否应该继续运行
    [[ ! -f "$HOME/.tmux-monitor/enabled" ]] && break
    [[ -z "$TMUX" ]] && break
    
    # 获取所有窗口
    windows=$(tmux list-windows -F "#{window_id}:#{pane_pid}" 2>/dev/null)
    
    for window_info in $windows; do
        IFS=':' read -r window_id pane_pid <<< "$window_info"

        # 检查是否应该跳过这个窗口（SSH 等正在处理）
        skip=$(tmux show-window-option -t "$window_id" -qv @monitor_skip 2>/dev/null)
        [[ "$skip" == "1" ]] && continue

        # 获取进程信息
        process_info=$(get_process_info "$pane_pid")

        # 检测程序类型
        program=$(detect_program "$process_info")

        # 设置窗口名
        case "$program" in
            claude)
                # 获取 CPU 使用率来判断是否在工作
                cpu=$(get_claude_cpu "$pane_pid")
                if [[ $cpu -gt 5 ]]; then
                    # CPU > 5%，正在思考
                    tmux rename-window -t "$window_id" "💭c" 2>/dev/null
                else
                    # CPU <= 5%，等待输入
                    tmux rename-window -t "$window_id" "🤖c" 2>/dev/null
                fi
                tmux set-window-option -t "$window_id" -q @monitor_skip 1 2>/dev/null
                ;;
            amazon-q)
                # Q 也检测 CPU
                cpu=$(get_claude_cpu "$pane_pid")
                if [[ $cpu -gt 5 ]]; then
                    tmux rename-window -t "$window_id" "💭q" 2>/dev/null
                else
                    tmux rename-window -t "$window_id" "🤖q" 2>/dev/null
                fi
                tmux set-window-option -t "$window_id" -q @monitor_skip 1 2>/dev/null
                ;;
            smth)
                tmux rename-window -t "$window_id" "📡s" 2>/dev/null
                tmux set-window-option -t "$window_id" -q @monitor_skip 1 2>/dev/null
                ;;
            vim)
                tmux rename-window -t "$window_id" "✏️v" 2>/dev/null
                ;;
            python)
                tmux rename-window -t "$window_id" "🐍p" 2>/dev/null
                ;;
            docker)
                tmux rename-window -t "$window_id" "🐋d" 2>/dev/null
                ;;
            git)
                tmux rename-window -t "$window_id" "📝g" 2>/dev/null
                ;;
            *)
                # 如果没有特殊程序，移除跳过标记
                tmux set-window-option -t "$window_id" -q -u @monitor_skip 2>/dev/null
                ;;
        esac
    done
    
    sleep $CHECK_INTERVAL
done

log "Monitor daemon stopped"
DAEMON_SCRIPT
    
    chmod +x "$MONITOR_CONFIG_DIR/daemon.sh"
}

# ==============================================================================
# Part 3: 控制命令
# ==============================================================================

monitor_start() {
    # 检查是否已运行
    if [[ -f "$MONITOR_PID_FILE" ]]; then
        local old_pid=$(cat "$MONITOR_PID_FILE")
        if ps -p "$old_pid" > /dev/null 2>&1; then
            echo "✅ Monitor already running (PID: $old_pid)"
            return 0
        fi
        rm -f "$MONITOR_PID_FILE"
    fi
    
    # 创建守护进程脚本
    create_monitor_daemon

    # 标记为启用
    touch "$MONITOR_ENABLED_FILE"

    # 启动守护进程（使用 nohup 避免终端控制序列问题）
    nohup bash "$MONITOR_CONFIG_DIR/daemon.sh" </dev/null >/dev/null 2>&1 &
    local pid=$!
    echo "$pid" > "$MONITOR_PID_FILE"

    echo "✅ Monitor started (PID: $pid)"
}

monitor_stop() {
    # 移除启用标记
    rm -f "$MONITOR_ENABLED_FILE"
    
    # 停止进程
    if [[ -f "$MONITOR_PID_FILE" ]]; then
        local pid=$(cat "$MONITOR_PID_FILE")
        if kill "$pid" 2>/dev/null; then
            echo "✅ Monitor stopped (PID: $pid)"
        fi
        rm -f "$MONITOR_PID_FILE"
    else
        echo "❌ Monitor not running"
    fi
    
    # 清理所有窗口的跳过标记
    tmux list-windows -F "#{window_id}" 2>/dev/null | while read window_id; do
        tmux set-window-option -t "$window_id" -q -u @monitor_skip 2>/dev/null
    done
}

monitor_status() {
    if [[ -f "$MONITOR_PID_FILE" ]]; then
        local pid=$(cat "$MONITOR_PID_FILE")
        if ps -p "$pid" > /dev/null 2>&1; then
            echo "✅ Monitor running (PID: $pid)"
        else
            echo "❌ Monitor not running (stale PID)"
            rm -f "$MONITOR_PID_FILE"
        fi
    else
        echo "❌ Monitor not running"
    fi
}

# ==============================================================================
# Part 4: 初始化和别名
# ==============================================================================

# 自动启动监控（如果在 tmux 中）
if [[ -n "$TMUX" ]] && [[ -n "$PS1" ]]; then
    # 检查是否已运行
    if [[ -f "$MONITOR_PID_FILE" ]]; then
        pid=$(cat "$MONITOR_PID_FILE")
        if ! ps -p "$pid" > /dev/null 2>&1; then
            monitor_start >/dev/null 2>&1
        fi
    else
        monitor_start >/dev/null 2>&1
    fi
fi

# 提供简化的控制命令（只保留必要的）
alias monitor='monitor_status'  # 默认显示状态
alias monitor-restart='monitor_stop; sleep 1; monitor_start'