#!/bin/bash

echo "🧹 最终清理 - 只保留必要文件"
echo "================================"

# 移动所有多余的监控脚本到备份
BACKUP_DIR="old_monitors_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo ""
echo "📦 移动多余的监控脚本..."
# 移动多余的监控脚本（只保留 tmux-unified-monitor.sh）
mv -v tmux-monitor.sh "$BACKUP_DIR/" 2>/dev/null
mv -v tmux-full-monitor.sh "$BACKUP_DIR/" 2>/dev/null
mv -v clean_bashrc.sh "$BACKUP_DIR/" 2>/dev/null
mv -v cleanup.sh "$BACKUP_DIR/" 2>/dev/null

echo ""
echo "📁 最终目录结构："
echo "==================="
echo "tmux-monitoring/"
echo "├── tmux-unified-monitor.sh  # 唯一的监控脚本"
echo "├── smth-robust.tcl          # SMTH BBS 连接"
echo "├── README.md                # 文档"
echo "└── old_files/               # 备份"
echo ""

# 创建简化的 README
cat > README.md << 'EOF'
# Tmux 监控系统

## 功能
- 自动检测并重命名 tmux 窗口
- 支持 Claude、Q Chat、vim、python、docker 等程序检测
- SSH 连接显示主机名
- SMTH BBS 显示用户名
- 无终端控制序列乱码

## 使用方法

### 自动启动
在 `.bashrc` 中添加：
```bash
source ~/personal-projects/productivity-tools/tmux-monitoring/tmux-unified-monitor.sh
```

### 手动控制
- `monitor_status` - 查看状态
- `monitor_start` - 启动监控
- `monitor_stop` - 停止监控
- `monitor_restart` - 重启监控

### 窗口命名规则
- `🤖c` - Claude 就绪
- `💭c` - Claude 工作中
- `💬q` - Amazon Q
- `📚username` - SMTH BBS
- `🔗hostname` - SSH 连接
- `✏️vim` - Vim 编辑器
- `🐍py` - Python
- `🐋dock` - Docker
- `📝git` - Git

## 文件说明
- `tmux-unified-monitor.sh` - 主监控脚本
- `~/.tmux-monitor/` - 配置和日志目录
- `~/.tmux-monitor/daemon_enhanced.sh` - 后台守护进程

## SMTH BBS
使用 `smth` 命令连接（别名指向 smth-robust.tcl）
EOF

echo "✅ 清理完成！"
echo ""
echo "📝 下一步："
echo "1. 检查并简化 alias"
echo "2. 确保 .bashrc 只有一行 source 命令"