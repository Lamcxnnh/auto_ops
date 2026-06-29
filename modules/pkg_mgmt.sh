#!/bin/bash
#
# pkg_mgmt.sh - 软件包管理模块
# 描述: 自动检测 apt / yum / dnf，提供搜索、安装、卸载、更新、查看已安装功能
# 依赖: lib/utils.sh (confirm, pause 函数)
#

# -----------------------------------------------------------
# 包管理器检测（模块加载时执行一次）
# -----------------------------------------------------------
detect_pm() {
    if command -v apt &>/dev/null; then
        PM="apt"
        PM_INSTALL="sudo apt install -y"
        PM_REMOVE="sudo apt remove -y"
        PM_SEARCH="apt search"
        PM_LIST_INSTALLED="apt list --installed"
        PM_UPDATE_CACHE="sudo apt update"
        PM_LIST_UPGRADES="apt list --upgradable"
        PM_UPGRADE="sudo apt upgrade -y"
    elif command -v dnf &>/dev/null; then
        PM="dnf"
        PM_INSTALL="sudo dnf install -y"
        PM_REMOVE="sudo dnf remove -y"
        PM_SEARCH="dnf search"
        PM_LIST_INSTALLED="dnf list installed"
        PM_UPDATE_CACHE="sudo dnf makecache"
        PM_LIST_UPGRADES="dnf list upgrades"
        PM_UPGRADE="sudo dnf upgrade -y"
    elif command -v yum &>/dev/null; then
        PM="yum"
        PM_INSTALL="sudo yum install -y"
        PM_REMOVE="sudo yum remove -y"
        PM_SEARCH="yum search"
        PM_LIST_INSTALLED="yum list installed"
        PM_UPDATE_CACHE="sudo yum makecache"
        PM_LIST_UPGRADES="yum list updates"
        PM_UPGRADE="sudo yum update -y"
    else
        PM=""
    fi
}

# -----------------------------------------------------------
# 1. 搜索软件包
# -----------------------------------------------------------
pkg_search() {
    echo
    read -rp "请输入要搜索的软件包名称: " keyword
    if [[ -z "$keyword" ]]; then
        echo "搜索关键词不能为空！"
        return
    fi
    echo
    echo "正在搜索: $keyword ..."
    $PM_SEARCH "$keyword" 2>/dev/null || echo "搜索失败或未找到匹配结果。"
}

# -----------------------------------------------------------
# 2. 安装软件包
# -----------------------------------------------------------
pkg_install() {
    echo
    read -rp "请输入要安装的软件包名称: " pkg
    if [[ -z "$pkg" ]]; then
        echo "包名不能为空！"
        return
    fi

    # 先搜索确认存在
    echo
    echo "正在查找 $pkg ..."
    $PM_SEARCH "$pkg" 2>/dev/null | head -5 || true
    echo

    if confirm "确认安装 $pkg？"; then
        echo "正在安装..."
        $PM_INSTALL "$pkg"
        if [[ $? -eq 0 ]]; then
            echo
            echo "✅ $pkg 安装成功！"
        else
            echo
            echo "安装失败，请检查包名是否正确或是否有权限。"
        fi
    else
        echo "操作取消。"
    fi
}

# -----------------------------------------------------------
# 3. 卸载软件包
# -----------------------------------------------------------
pkg_remove() {
    echo
    read -rp "请输入要卸载的软件包名称: " pkg
    if [[ -z "$pkg" ]]; then
        echo "包名不能为空！"
        return
    fi

    # 检查是否已安装
    echo "正在检查 $pkg 是否已安装..."
    if ! $PM_LIST_INSTALLED 2>/dev/null | grep -qi "^${pkg}/"; then
        echo "警告：$pkg 似乎未安装或不在已安装列表中。"
        if ! confirm "是否仍要尝试卸载？"; then
            return
        fi
    fi

    if confirm "确认卸载 $pkg？此操作可能同时移除依赖它的其他软件。"; then
        echo "正在卸载..."
        $PM_REMOVE "$pkg"
        if [[ $? -eq 0 ]]; then
            echo
            echo "✅ $pkg 已卸载。"
        else
            echo
            echo "卸载失败。"
        fi
    else
        echo "操作取消。"
    fi
}

# -----------------------------------------------------------
# 4. 批量更新
# -----------------------------------------------------------
pkg_update() {
    echo
    echo "========== 软件更新 =========="

    echo
    echo ">>> 正在刷新软件源..."
    $PM_UPDATE_CACHE || { echo "刷新失败，请检查网络。"; return; }

    echo
    echo ">>> 可更新的软件包:"
    $PM_LIST_UPGRADES 2>/dev/null | head -20 || echo "  (未发现可更新软件包)"

    local upgradable
    upgradable=$($PM_LIST_UPGRADES 2>/dev/null | grep -c '^' || echo 0)
    echo
    echo "可更新总数: 约 $upgradable 个"

    if [[ "$upgradable" -eq 0 ]]; then
        echo "系统已是最新，无需更新。"
        return
    fi

    echo
    if confirm "确认更新以上所有软件包？"; then
        echo "正在进行系统更新..."
        $PM_UPGRADE
        if [[ $? -eq 0 ]]; then
            echo
            echo "✅ 系统更新完成！"
        else
            echo
            echo "更新过程中出现错误。"
        fi
    else
        echo "操作取消。"
    fi
}

# -----------------------------------------------------------
# 5. 查看已安装软件包
# -----------------------------------------------------------
pkg_list() {
    echo
    echo "----- 查询选项 -----"
    echo "1. 查看所有已安装"
    echo "2. 按名称搜索已安装"
    echo "3. 返回"
    echo "------------------"
    read -rp "请选择: " sub_choice || return

    case $sub_choice in
        1)
            echo
            echo "========== 已安装软件包 =========="
            $PM_LIST_INSTALLED | less
            ;;
        2)
            echo
            read -rp "请输入搜索关键词: " keyword
            if [[ -n "$keyword" ]]; then
                echo
                echo "========== 搜索已安装包: $keyword =========="
                $PM_LIST_INSTALLED 2>/dev/null | grep -i "$keyword" || echo "未找到匹配项。"
            fi
            ;;
        3) return ;;
        *) echo "无效选项！" ;;
    esac
}

# -----------------------------------------------------------
# 软件包管理主菜单
# -----------------------------------------------------------
pkg_menu() {
    # 检测包管理器
    detect_pm
    if [[ -z "$PM" ]]; then
        echo
        echo "⚠ 未检测到支持的包管理器（apt / yum / dnf）。"
        echo "  当前系统可能不是 Debian/Ubuntu 或 RHEL/CentOS/Fedora 系列。"
        pause
        return
    fi

    while true; do
        clear
        echo "----- 软件包管理 ($PM) -----"
        echo "1. 搜索软件包"
        echo "2. 安装软件包"
        echo "3. 卸载软件包"
        echo "4. 系统更新"
        echo "5. 查看已安装软件包"
        echo "6. 返回主菜单"
        echo "------------------------"
        read -rp "请选择: " choice || break
        case $choice in
            1) pkg_search ;;
            2) pkg_install ;;
            3) pkg_remove ;;
            4) pkg_update ;;
            5) pkg_list ;;
            6) break ;;
            *) echo "无效选项，请重新输入！" ;;
        esac
        pause
    done
}
