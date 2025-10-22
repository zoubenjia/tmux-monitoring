#!/bin/bash

# 恢复被误删的重要配置

echo "🔧 恢复重要配置..."

# 创建临时文件存储需要恢复的配置
cat >> ~/.bashrc.restored << 'EOF'

# =============================================================================
# 恢复的重要配置
# =============================================================================

# Q CLI 相关
alias q-original='/Users/zoubenjia/.local/bin/q'
alias qstatus='echo "🤖 Q CLI 状态:"; ps aux | grep -E "q chat|qchat" | grep -v grep'

# SSH 脚本
alias sshy='~/scripts/ssh.sh'

# 加载自定义别名
[[ -f ~/awsq/configs/shell/aliases.sh ]] && source ~/awsq/configs/shell/aliases.sh

# Home Assistant
export HOMEASSISTANT_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiIyMTg5NjU0OGRiYjU0NTYyYTc5NDQwMTFiZWI4YzNkYiIsImlhdCI6MTc1NDExMTA1MywiZXhwIjoyMDY5NDcxMDUzfQ.uXfLbAyf-8WZvMmkg46ZrbEouP1btZd2jahn5BShnm8"

# 禁用 AWS 遥测
export AWS_CODEWHISPERER_TELEMETRY_ENABLED=false
export Q_TELEMETRY_ENABLED=false
export AWS_TELEMETRY_ENABLED=false
export CODEWHISPERER_TELEMETRY_ENABLED=false
export Q_CLI_TELEMETRY_ENABLED=false
export AWS_CLI_TELEMETRY_ENABLED=false
export AWS_Q_DISABLE_TELEMETRY=true
export AWS_CLI_DISABLE_TELEMETRY=true
export AWS_DISABLE_TELEMETRY=true

# Q Chat 别名（无遥测）
alias qchat="AWS_Q_DISABLE_TELEMETRY=true AWS_CLI_DISABLE_TELEMETRY=true AWS_DISABLE_TELEMETRY=true q chat"

# Home Assistant 和 Tuya
export TUYA_CLIENT_ID="kfsekwgnkq48k789pq4k"
export TUYA_CLIENT_SECRET="82416d370b5b4a609183188c8417e9c6"
export HOMEASSISTANT_URL="http://192.168.4.53:8123"

# 配置同步服务（可选启用）
check_and_start_config_sync() {
    local pid_file="$HOME/configs/frequency_sync.pid"
    
    # 检查服务是否已运行
    if [[ -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            return 0  # 服务已运行
        else
            rm -f "$pid_file"  # 清理无效的PID文件
        fi
    fi
    
    # 启动服务
    if [[ -x "$HOME/configs/frequency_sync.sh" ]]; then
        nohup "$HOME/configs/frequency_sync.sh" start > /dev/null 2>&1 &
        sleep 1
    fi
}

# 自动启动配置同步（如需禁用，注释下面这行）
if [[ -n "$PS1" ]]; then
    check_and_start_config_sync 2>/dev/null
fi

EOF

echo "✅ 配置已保存到 ~/.bashrc.restored"
echo ""
echo "请查看内容，确认后执行："
echo "cat ~/.bashrc.restored >> ~/.bashrc"
echo "source ~/.bashrc"