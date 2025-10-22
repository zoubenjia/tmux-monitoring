#!/bin/bash

# SMTH BBS 防掉线脚本
# 支持自动重连、心跳保持、会话恢复

CONFIG_DIR="$HOME/.smth-keepalive"
LOG_FILE="$CONFIG_DIR/keepalive.log"
PID_FILE="$CONFIG_DIR/keepalive.pid"
SESSION_FILE="$CONFIG_DIR/session_info"

mkdir -p "$CONFIG_DIR"

# 配置参数
SMTH_HOST="bbs.smth.edu.cn"
SMTH_PORT="23"
CHECK_INTERVAL=30
HEARTBEAT_INTERVAL=120
MAX_RECONNECT_ATTEMPTS=5
RECONNECT_DELAY=10

# 日志函数
log() {
    echo "$(date '+%H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# 检测 tmux 窗口中的 SMTH BBS 连接状态
detect_smth_windows() {
    local smth_windows=()
    
    # 获取所有窗口信息
    local window_info=$(tmux list-windows -F '#{window_index}:#{window_id}:#{pane_pid}:#{window_name}' 2>/dev/null)
    
    if [ -z "$window_info" ]; then
        return 1
    fi
    
    local IFS=$'\n'
    local windows=($window_info)
    
    for line in "${windows[@]}"; do
        local window_index=${line%%:*}
        local remainder=${line#*:}
        local window_id=${remainder%%:*}
        remainder=${remainder#*:}
        local pane_pid=${remainder%%:*}
        local window_name=${remainder#*:}
        
        # 检查是否是 SMTH 相关窗口
        if echo "$window_name" | grep -q "smth\|📚\|🔐\|⏳\|❌\|📱"; then
            smth_windows+=("$window_index:$window_id:$pane_pid:$window_name")
        fi
    done
    
    if [ ${#smth_windows[@]} -gt 0 ]; then
        printf '%s\n' "${smth_windows[@]}"
        return 0
    else
        return 1
    fi
}

# 检测连接状态
check_connection_status() {
    local window_id="$1"
    local content=$(tmux capture-pane -t "$window_id" -p -S -20 2>/dev/null)
    
    if [ -z "$content" ]; then
        echo "error"
        return
    fi
    
    # 检测各种状态
    if echo "$content" | grep -qi "connection.*closed\|连接.*中断\|connection.*lost\|网络.*断开"; then
        echo "disconnected"
    elif echo "$content" | grep -qi "connection.*timed.*out\|连接.*超时\|timeout"; then
        echo "timeout"
    elif echo "$content" | grep -qi "connection.*refused\|连接.*拒绝\|refused"; then
        echo "refused"
    elif echo "$content" | grep -qi "login.*incorrect\|密码.*错误\|invalid.*password"; then
        echo "login_failed"
    elif echo "$content" | grep -qi "欢迎光临.*水木社区\|Welcome.*SMTH\|用户代号.*[:：]"; then
        echo "connected"
    elif echo "$content" | grep -qi "请输入用户名\|login\|username\|Password"; then
        echo "login_prompt"
    elif echo "$content" | grep -qi "正在连接\|connecting\|trying"; then
        echo "connecting"
    elif echo "$content" | tail -3 | grep -q "^$"; then
        # 连续空行可能表示掉线
        echo "possible_disconnect"
    else
        echo "unknown"
    fi
}

# 执行重连操作
reconnect_smth() {
    local window_index="$1"
    local window_id="$2"
    local attempt="$3"
    
    log "🔄 窗口 $window_index 尝试重连 (第 $attempt 次)"
    
    # 发送 Ctrl+C 中断当前操作
    tmux send-keys -t "$window_id" "C-c" Enter
    sleep 2
    
    # 发送重连命令
    tmux send-keys -t "$window_id" "telnet $SMTH_HOST $SMTH_PORT" Enter
    
    # 等待连接建立
    sleep 5
    
    # 检查重连是否成功
    local status=$(check_connection_status "$window_id")
    if [[ "$status" == "connected" || "$status" == "login_prompt" ]]; then
        log "✅ 窗口 $window_index 重连成功"
        return 0
    else
        log "❌ 窗口 $window_index 重连失败，状态: $status"
        return 1
    fi
}

# 发送心跳保持连接
send_heartbeat() {
    local window_id="$1"
    local window_index="$2"
    
    # 发送空格然后退格，不影响界面但保持连接活跃
    tmux send-keys -t "$window_id" " " "C-h"
    log "💗 窗口 $window_index 发送心跳"
}

# 主监控循环
monitor_connections() {
    log "🚀 SMTH BBS 防掉线监控启动"
    
    local heartbeat_counter=0
    
    while true; do
        # 检测 SMTH 窗口
        local smth_windows_info
        if smth_windows_info=$(detect_smth_windows); then
            local IFS=$'\n'
            local windows=($smth_windows_info)
            
            for window_line in "${windows[@]}"; do
                local window_index=${window_line%%:*}
                local remainder=${window_line#*:}
                local window_id=${remainder%%:*}
                remainder=${remainder#*:}
                local pane_pid=${remainder%%:*}
                local window_name=${remainder#*:}
                
                # 检查连接状态
                local status=$(check_connection_status "@$window_id")
                
                case "$status" in
                    "disconnected"|"timeout"|"refused"|"possible_disconnect")
                        log "⚠️ 窗口 $window_index ($window_name) 检测到掉线: $status"
                        
                        # 尝试重连
                        local attempt=1
                        local reconnected=false
                        
                        while [ $attempt -le $MAX_RECONNECT_ATTEMPTS ]; do
                            if reconnect_smth "$window_index" "@$window_id" "$attempt"; then
                                reconnected=true
                                break
                            fi
                            
                            attempt=$((attempt + 1))
                            if [ $attempt -le $MAX_RECONNECT_ATTEMPTS ]; then
                                log "⏱️ 等待 $RECONNECT_DELAY 秒后重试..."
                                sleep $RECONNECT_DELAY
                            fi
                        done
                        
                        if [ "$reconnected" = false ]; then
                            log "💀 窗口 $window_index 重连失败，已达到最大尝试次数"
                            # 发送通知
                            osascript -e "display notification \"SMTH BBS 窗口 $window_index 重连失败\" with title \"连接监控\" sound name \"Sosumi\"" 2>/dev/null || true
                        fi
                        ;;
                    "connected")
                        # 连接正常，发送心跳（如果需要）
                        if [ $((heartbeat_counter % (HEARTBEAT_INTERVAL / CHECK_INTERVAL))) -eq 0 ]; then
                            send_heartbeat "@$window_id" "$window_index"
                        fi
                        ;;
                    "login_prompt"|"connecting")
                        log "📝 窗口 $window_index 状态: $status"
                        ;;
                    "error")
                        log "❌ 窗口 $window_index 检测错误"
                        ;;
                esac
            done
        else
            log "📭 未发现 SMTH BBS 窗口"
        fi
        
        heartbeat_counter=$((heartbeat_counter + 1))
        sleep $CHECK_INTERVAL
    done
}

# 启动守护进程
start() {
    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "⚠️ SMTH 防掉线监控已在运行"
        exit 1
    fi
    
    echo "🚀 启动 SMTH BBS 防掉线监控..."
    monitor_connections &
    echo $! > "$PID_FILE"
    echo "✅ 监控已启动 (PID: $!)"
    echo ""
    echo "配置参数:"
    echo "  检查间隔: ${CHECK_INTERVAL}秒"
    echo "  心跳间隔: ${HEARTBEAT_INTERVAL}秒"
    echo "  最大重连次数: ${MAX_RECONNECT_ATTEMPTS}次"
    echo "  重连延迟: ${RECONNECT_DELAY}秒"
}

# 停止守护进程
stop() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            rm -f "$PID_FILE"
            log "🛑 SMTH 防掉线监控已停止"
            echo "✅ 监控已停止"
        else
            rm -f "$PID_FILE"
            echo "❌ 监控未在运行"
        fi
    else
        echo "❌ 监控未在运行"
    fi
}

# 显示状态
status() {
    echo "📊 SMTH BBS 防掉线监控状态"
    echo "========================="
    
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "🟢 状态: 运行中 (PID: $pid)"
        else
            echo "🔴 状态: 已停止"
            rm -f "$PID_FILE"
        fi
    else
        echo "🔴 状态: 未启动"
    fi
    
    echo ""
    echo "当前 SMTH 窗口:"
    if smth_windows=$(detect_smth_windows); then
        local IFS=$'\n'
        local windows=($smth_windows)
        for window_line in "${windows[@]}"; do
            local window_index=${window_line%%:*}
            local remainder=${window_line#*:}
            local window_id=${remainder%%:*}
            remainder=${remainder#*:}
            local pane_pid=${remainder%%:*}
            local window_name=${remainder#*:}
            
            local status=$(check_connection_status "@$window_id")
            echo "  窗口 $window_index: $window_name (状态: $status)"
        done
    else
        echo "  未发现 SMTH BBS 窗口"
    fi
}

# 测试连接检测
test() {
    echo "🧪 测试 SMTH BBS 连接检测"
    echo "======================="
    
    if smth_windows=$(detect_smth_windows); then
        local IFS=$'\n'
        local windows=($smth_windows)
        
        for window_line in "${windows[@]}"; do
            local window_index=${window_line%%:*}
            local remainder=${window_line#*:}
            local window_id=${remainder%%:*}
            remainder=${remainder#*:}
            local pane_pid=${remainder%%:*}
            local window_name=${remainder#*:}
            
            echo ""
            echo "窗口 $window_index ($window_name):"
            echo "  PID: $pane_pid"
            
            local status=$(check_connection_status "@$window_id")
            echo "  连接状态: $status"
            
            # 显示最后几行内容用于调试
            echo "  最近内容:"
            tmux capture-pane -t "@$window_id" -p -S -5 2>/dev/null | sed 's/^/    /'
        done
    else
        echo "未发现 SMTH BBS 窗口"
    fi
}

# 主函数
case "${1:-help}" in
    "start")
        start
        ;;
    "stop")
        stop
        ;;
    "status")
        status
        ;;
    "test")
        test
        ;;
    *)
        echo "SMTH BBS 防掉线监控"
        echo "=================="
        echo "Usage: $0 {start|stop|status|test}"
        echo ""
        echo "Commands:"
        echo "  start   - 启动防掉线监控"
        echo "  stop    - 停止监控"
        echo "  status  - 查看状态"
        echo "  test    - 测试连接检测"
        echo ""
        echo "功能特性:"
        echo "  🔄 自动重连掉线的连接"
        echo "  💗 定期发送心跳保持活跃"
        echo "  📱 掉线和重连通知"
        echo "  🎯 支持多个 SMTH 窗口监控"
        echo "  📊 详细的状态日志"
        ;;
esac