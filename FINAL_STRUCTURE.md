# Tmux 监控系统 - 最终结构

## ✅ 已完成的清理

### 1. 统一的重命名机制
- **SSH/CD**: 由函数包装立即处理
- **其他程序**: 由后台守护进程定期检测
- **协调机制**: 使用 `@monitor_skip` 标记避免冲突

### 2. 清理的文件结构
```
tmux-monitoring/
├── tmux-unified-monitor.sh   # 唯一的监控脚本
├── smth-robust.tcl           # SMTH BBS 连接脚本
├── README.md                 # 用户文档
└── old_files/                # 历史备份
```

### 3. 简化的命令
监控相关：
- `monitor_start` - 启动监控
- `monitor_stop` - 停止监控  
- `monitor_status` - 查看状态
- `monitor` - 状态别名
- `monitor-restart` - 重启监控

SMTH BBS：
- `smth` - 连接 BBS

## 📝 配置入口

### .bashrc
```bash
# 唯一需要的 source 命令
source ~/personal-projects/productivity-tools/tmux-monitoring/tmux-unified-monitor.sh
```

### unified_aliases.sh
- 已清理重复的 tmux 相关 alias
- 保留 smth 别名指向 smth-robust.tcl
- config-sync-* 用于配置同步（与 tmux 监控无关）

## 🔧 工作原理

1. **加载时**：
   - source tmux-unified-monitor.sh
   - 定义 ssh/cd 函数包装
   - 自动启动后台监控（如果在 tmux 中）

2. **运行时**：
   - SSH 命令 → 函数立即重命名 → 设置跳过标记
   - CD 命令 → 检查跳过标记 → 如无则更新目录名
   - 后台进程 → 每 3 秒检测进程树 → 根据程序类型重命名

3. **窗口命名**：
   - `🤖c` / `💭c` - Claude 状态
   - `💬q` - Amazon Q
   - `📚user` - SMTH BBS
   - `🔗host` - SSH 连接
   - 目录名 - 普通 bash

## ⚠️ 注意事项

1. **无终端控制序列乱码**
   - 使用 nohup 和 I/O 重定向
   - 守护进程不与终端交互

2. **无冲突**
   - 统一的标记系统
   - 清晰的优先级规则

3. **简单维护**
   - 单一脚本
   - 清晰的日志（~/.tmux-monitor/）

## 🎯 使用建议

日常使用无需任何命令，一切自动运行。

如需调试：
```bash
DEBUG=1 monitor_start  # 启用调试日志
tail -f ~/.tmux-monitor/monitor.log  # 查看日志
```

---
*清理完成于 2025-09-30*