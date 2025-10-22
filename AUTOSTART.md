# TMux 监控自动启动指南

## 推荐方案：跟随 tmux 自动启动

监控器会在 tmux 启动时自动运行，配置已添加到 `~/.tmux.conf.local`：

```bash
# 自动启动配置（已添加）
if-shell '[ ! -f ~/.claude-monitor/enhanced_monitor.pid ] || ! kill -0 $(cat ~/.claude-monitor/enhanced_monitor.pid 2>/dev/null) 2>/dev/null' \
    'run-shell "~/personal-projects/productivity-tools/tmux-monitoring/tmux-monitor start >/dev/null 2>&1 &"'
```

### 特点
- ✅ **智能检测**：只在监控未运行时启动
- ✅ **避免重复**：检查 PID 文件防止多个实例
- ✅ **静默启动**：后台运行，不干扰 tmux 使用
- ✅ **兼容 Oh My Tmux**：配置添加到 `.tmux.conf.local`

## 手动管理命令

```bash
# 查看监控状态
./tmux-monitor status

# 重启监控
./tmux-monitor restart

# 停止监控
./tmux-monitor stop

# 测试检测功能
./tmux-monitor test
```

## 功能说明

监控器会自动：
- 🤖 检测和重命名 Claude 窗口（包括 proj-tui 启动的）
- 💬 检测和重命名 Amazon Q 窗口
- 📚 检测和重命名 SMTH BBS 窗口
- 📱 Claude 完成任务时发送通知

## 故障排除

### 如果发现多个监控进程
```bash
./tmux-monitor restart  # 会自动清理并重启
```

### 手动清理所有监控进程
```bash
./tmux-monitor stop     # 停止所有监控
./tmux-monitor start    # 重新启动
```

### 检查当前状态
```bash
# 查看监控状态
./tmux-monitor status

# 查看系统中的监控进程
ps aux | grep monitor | grep -v grep

# 查看 tmux 窗口
tmux list-windows
```

### 临时禁用自动启动
如果需要临时禁用自动启动，可以编辑 `~/.tmux.conf.local`，注释掉自动启动部分：
```bash
# if-shell '[ ! -f ~/.claude-monitor/enhanced_monitor.pid ] ...
```

## 文件说明

- `tmux-monitor` - 统一管理脚本（推荐使用）
- `enhanced_process_monitor.sh` - 增强版监控器（支持所有功能）
- `process_based_monitor.sh` - 基础版监控器（已弃用）
- `start-monitor-safe.sh` - 安全启动脚本

## 总结

- 🎯 **推荐做法**：使用 tmux 自动启动（已配置）
- 🔧 **手动管理**：使用 `tmux-monitor` 命令
- ✅ **保证**：只有一个增强版监控运行