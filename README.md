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
