#!/bin/bash
#
# 描述: 主入口，加载各模块
# 用法:
#   cd auto_ops
#   chmod +x main.sh
#   ./main.sh
#

set -uo pipefail

# -----------------------------------------------------------
# 确定脚本所在目录，确保从任意路径运行都能正确加载模块
# -----------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# -----------------------------------------------------------
# 加载顺序: 配置 → 工具库 → 各功能模块
# -----------------------------------------------------------
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/modules/sysinfo.sh"
source "${SCRIPT_DIR}/modules/user_mgmt.sh"
source "${SCRIPT_DIR}/modules/backup.sh"
source "${SCRIPT_DIR}/modules/process_mgmt.sh"
source "${SCRIPT_DIR}/modules/network_test.sh"
source "${SCRIPT_DIR}/modules/git_mgmt.sh"
source "${SCRIPT_DIR}/modules/pkg_mgmt.sh"

# -----------------------------------------------------------
# 主菜单
# -----------------------------------------------------------
show_menu() {
    clear
    echo "========== 自动化运维平台 =========="
    echo "1. 查看系统信息"
    echo "2. 用户管理"
    echo "3. 备份文件目录"
    echo "4. 进程管理"
    echo "5. 网络连通检测"
    echo "6. Git 仓库管理"
    echo "7. 软件包管理"
    echo "0. 退出"
    echo "====================================="
}

# -----------------------------------------------------------
# 主程序入口
# -----------------------------------------------------------
main() {
    while true; do
        show_menu
        read -rp "请输入选项编号: " choice || break
        case $choice in
            1) show_sysinfo; pause ;;
            2) user_menu ;;
            3) backup_menu ;;
            4) process_menu ;;
            5) network_menu ;;
            6) git_menu ;;
            7) pkg_menu ;;
            0) echo "再见！"; exit 0 ;;
            *) echo "无效输入，请重新选择！"; pause ;;
        esac
    done
}

main
