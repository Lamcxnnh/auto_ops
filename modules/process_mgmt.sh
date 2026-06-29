#!/bin/bash
#
# process_mgmt.sh - 进程管理模块
# 描述: 查看进程列表、按 PID 终止进程
# 依赖: lib/utils.sh (confirm 函数)
#

# 终止进程
kill_process() {
    echo
    read -rp "请输入要终止的 PID: " pid
    if [[ -z "$pid" ]]; then
        echo "PID 不能为空！"
        return
    fi
    if ps -p "$pid" &>/dev/null; then
        if confirm "确认终止 PID $pid 进程？"; then
            sudo kill -9 "$pid" && echo "进程 $pid 已终止。"
        else
            echo "操作取消。"
        fi
    else
        echo "PID $pid 不存在！"
    fi
}

# 进程管理子菜单
process_menu() {
    while true; do
        clear
        echo "----- 进程管理 -----"
        echo "1. 查看所有进程（最近20个）"
        echo "2. 终止进程"
        echo "3. 返回主菜单"
        echo "------------------"
        read -rp "请选择: " sub_choice || break
        case $sub_choice in
            1) ps -ef --sort=-pid | head -20 ;;
            2) kill_process ;;
            3) break ;;
            *) echo "无效选项，请重新输入！" ;;
        esac
        pause
    done
}
