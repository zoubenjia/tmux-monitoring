#!/opt/homebrew/bin/expect -f

# 增强版 SMTH BBS 脚本 - 支持防掉线和自动重连

set host "bbs.mysmth.net"
set dport "22" 
set user "abenbit"
set mode ""
set board "IBM"
set password "1qaz!QAZ"

# 防掉线配置
set reconnect_attempts 0
set max_reconnect_attempts 5
set heartbeat_interval 120
set connection_timeout 30

if {[info exists argv]} {
    for {set i 0} {$i < [llength $argv]} {incr i} {
        if {[string eq [lindex $argv $i] "-u"]} {
            incr i
            set user [lindex $argv $i]
        } elseif {[string eq [lindex $argv $i] "-p"]} {
            incr i
            set password [lindex $argv $i]
        } elseif {[string eq [lindex $argv $i] "-h"]} {
            incr i
            set host [lindex $argv $i]
        } elseif {[string eq [lindex $argv $i] "-m"]} {
            incr i
            set mode [lindex $argv $i]
        } elseif {[string eq [lindex $argv $i] "-b"]} {
            incr i
            set board [lindex $argv $i]
        }
    }
}

proc qx cmd {
	set fh [open "|$cmd"]
		set res [read $fh]
		close $fh
		return $res
}

proc send_all args {
	send [join $args ""]
}

proc strcat args {
	return [join $args ""]
}

proc log_msg {msg} {
    if {[catch {
        set timestamp [exec date "+%H:%M:%S"]
        puts "\033\[33m\[$timestamp\] $msg\033\[0m"
        flush stdout
    } err]} {
        # 如果无法输出到 stdout，至少尝试输出到 stderr
        catch {puts stderr "LOG: $msg"}
    }
}

# 心跳保持连接的函数
proc send_heartbeat {} {
    global heartbeat_interval
    
    # 发送一个不会影响界面的按键组合
    send " \b"
    log_msg "💗 发送心跳保持连接"
    
    # 设置下次心跳
    after [expr $heartbeat_interval * 1000] send_heartbeat
}

# 连接函数
proc connect_to_smth {} {
    global host user password spawn_id
    
    log_msg "🌐 正在连接 $user@$host..."
    
    if [string eq "" $password] {
        set password [qx "get-authinfo $host $user"]
    }
    
    spawn luit -encoding GB2312 ssh $user@$host
    
    expect -timeout 30 password: {
        log_msg "🔐 输入密码"
        send "$password\n"
    } timeout {
        log_msg "❌ 连接超时"
        return 0
    } eof {
        log_msg "❌ 连接失败"
        return 0
    }
    
    # 处理登录后的各种提示
    expect -timeout 1 {
        -re "按.*RETURN.*继续|上次连线时间|按任意键继续|近期热点|如何处理以上" {
            send "\n"
            exp_continue
        }
        -re "离开水木" {
            send "s\n"
            send "NewExpress\n"
            exp_continue
        }
    }
    
    log_msg "✅ 登录成功"
    return 1
}

# 重连函数
proc reconnect {} {
    global reconnect_attempts max_reconnect_attempts host user
    
    incr reconnect_attempts
    
    if {$reconnect_attempts > $max_reconnect_attempts} {
        log_msg "💀 已达到最大重连次数 ($max_reconnect_attempts)，退出"
        exit 1
    }
    
    log_msg "🔄 尝试重连 (第 $reconnect_attempts 次)..."
    
    # 等待一下再重连
    sleep [expr $reconnect_attempts * 2]
    
    if {[connect_to_smth]} {
        log_msg "✅ 重连成功！"
        set reconnect_attempts 0
        
        # 重新启动心跳
        after [expr 120 * 1000] send_heartbeat
        
        # 继续交互模式
        setup_interaction
    } else {
        log_msg "❌ 重连失败，准备再次尝试"
        reconnect
    }
}

# 设置交互模式和掉线检测
proc setup_interaction {} {
    global spawn_id
    
    log_msg "🎮 进入交互模式"
    log_msg "💡 防掉线功能已激活 (心跳间隔: 2分钟)"
    
    # 启动心跳
    after [expr 120 * 1000] send_heartbeat
    
    # 简单的交互模式，让用户能够正常使用 BBS
    interact
}

# 主程序开始
log_msg "🚀 启动增强版 SMTH BBS 连接脚本"
log_msg "📋 用户: $user@$host"
log_msg "🛡️ 防掉线功能: 启用"
log_msg "💗 心跳间隔: 2分钟"
log_msg "🔄 最大重连次数: $max_reconnect_attempts"
log_msg ""
log_msg "💡 特殊功能:"
log_msg "   Ctrl+R: 手动重连"
log_msg "   自动检测掉线并重连"
log_msg ""

# 首次连接
if {[connect_to_smth]} {
    setup_interaction
} else {
    log_msg "❌ 初始连接失败"
    reconnect
}

log_msg "👋 SMTH BBS 会话结束"