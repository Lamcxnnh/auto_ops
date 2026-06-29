#!/bin/bash
#
# sysinfo.sh - 系统信息模块
# 描述: 查看操作系统、内核、CPU、内存、磁盘等基本信息
#

show_sysinfo() {
    echo
    echo "========== 系统信息 =========="
    echo "操作系统: $(lsb_release -d 2>/dev/null | cut -f2)"
    echo "内核版本: $(uname -r)"
    echo "CPU 型号: $(lscpu | grep 'Model name' | awk -F':' '{print $2}' | xargs)"
    echo "内存总量: $(free -h | awk '/^Mem:/ {print $2}')"
    echo "可用内存: $(free -h | awk '/^Mem:/ {print $7}')"
    echo "磁盘使用:"
    df -h --total 2>/dev/null | grep -E '^(/dev/|total)'
    echo "=============================="
}
