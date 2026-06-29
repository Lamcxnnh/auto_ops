#!/bin/bash
#
# utils.sh - 通用工具函数
# 描述: 提供各模块共用的辅助函数
#

# 按回车键继续
pause() {
    echo
    read -rp "按回车键继续..."
}

# 二次确认提示
# 参数: $1 - 提示信息
# 返回: 0=确认, 1=取消
confirm() {
    local prompt="${1:-确认执行此操作？}"
    local answer
    while true; do
        read -rp "${prompt} (y/n): " answer
        case "$answer" in
            ""|y|Y) return 0 ;;
            n|N) return 1 ;;
            *) echo "输入错误，请输入 y 或 n" ;;
        esac
    done
}

