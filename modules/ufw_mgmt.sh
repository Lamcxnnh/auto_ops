#!/bin/bash
#
# ufw_mgmt.sh - 防火墙管理模块
# 描述: 基于 ufw 的查看规则、放行端口、删除规则、启用/禁用
# 依赖: lib/utils.sh (confirm, pause 函数)
#

# -----------------------------------------------------------
# 辅助：检查 ufw 是否可用
# -----------------------------------------------------------
check_ufw() {
    if ! command -v ufw &>/dev/null; then
        echo "⚠ 系统未安装 ufw。"
        echo "  安装命令: sudo apt install ufw"
        return 1
    fi
    return 0
}

# -----------------------------------------------------------
# 1. 查看防火墙状态
# -----------------------------------------------------------
ufw_status() {
    check_ufw || return

    echo
    echo "========== 防火墙状态 =========="

    local status
    status=$(sudo ufw status 2>/dev/null | head -1 || echo "未知")
    echo "状态: $status"
    echo

    echo "详细规则:"
    sudo ufw status verbose 2>/dev/null || echo "  无法获取"

    echo "==================================="
}

# -----------------------------------------------------------
# 2. 放行端口
# -----------------------------------------------------------
ufw_allow() {
    check_ufw || return

    echo
    echo "========== 放行端口 =========="
    echo
    read -rp "请输入端口号: " port
    if [[ -z "$port" ]]; then
        echo "端口号不能为空！"
        return
    fi
    if [[ ! "$port" =~ ^[0-9]+$ ]] || [[ "$port" -lt 1 || "$port" -gt 65535 ]]; then
        echo "无效端口号（范围: 1-65535）！"
        return
    fi

    echo
    echo "选择协议:"
    echo "  1. TCP"
    echo "  2. UDP"
    echo "  3. TCP 和 UDP（两者）"
    read -rp "请选择 [默认: 3]: " proto_choice
    proto_choice="${proto_choice:-3}"

    local proto_arg
    case $proto_choice in
        1) proto_arg="tcp" ;;
        2) proto_arg="udp" ;;
        3) proto_arg="" ;;
        *) echo "无效选择！"; return ;;
    esac

    echo
    echo "即将执行:"
    if [[ -n "$proto_arg" ]]; then
        echo "  sudo ufw allow $port/$proto_arg"
    else
        echo "  sudo ufw allow $port"
    fi

    if confirm "确认放行？"; then
        if [[ -n "$proto_arg" ]]; then
            sudo ufw allow "$port/$proto_arg"
        else
            sudo ufw allow "$port"
        fi
        if [[ $? -eq 0 ]]; then
            echo
            echo "✅ 端口 $port 已放行。"
        else
            echo "操作失败。"
        fi
    else
        echo "操作取消。"
    fi
}

# -----------------------------------------------------------
# 3. 关闭端口
# -----------------------------------------------------------
ufw_close_port() {
    check_ufw || return

    echo
    echo "========== 关闭端口 =========="

    # 检查防火墙是否启用
    local ufw_active
    ufw_active=$(sudo ufw status 2>/dev/null | head -1 | grep -ci 'active' || echo 0)
    if [[ "$ufw_active" -eq 0 ]]; then
        echo "⚠ 防火墙当前未启用，关闭端口不会生效。"
        echo "  建议先启用防火墙再操作。"
        echo
    fi

    # 从 ufw status 中提取当前已放行的端口
    echo "当前已放行的端口:"
    echo
    local allowed
    allowed=$(sudo ufw status 2>/dev/null | grep -i 'ALLOW' || true)

    if [[ -z "$allowed" ]]; then
        echo "  没有找到已放行的端口。"
        return
    fi

    echo "$allowed"
    echo

    read -rp "请输入要关闭的端口号 (输入 0 返回): " port
    [[ "$port" == "0" || -z "$port" ]] && return
    if [[ ! "$port" =~ ^[0-9]+$ ]] || [[ "$port" -lt 1 || "$port" -gt 65535 ]]; then
        echo "无效端口号！"
        return
    fi

    echo
    echo "即将关闭端口 $port（删除该端口的所有 ALLOW 规则）"
    if confirm "确认关闭？"; then
        # 删除该端口的 allow 规则（包括 tcp/udp）
        sudo ufw delete allow "$port" 2>&1 || true
        sudo ufw delete allow "$port/tcp" 2>&1 || true
        sudo ufw delete allow "$port/udp" 2>&1 || true
        echo
        echo "✅ 已尝试关闭端口 $port。"
        echo
        echo ">>> 更新后的状态:"
        if sudo ufw status 2>/dev/null | grep -qE "^$port/|$port "; then
            echo "  ⚠ 端口 $port 仍在放行列表中，可能需要手动检查:"
            sudo ufw status 2>/dev/null | grep -E "^$port/|$port " || true
        else
            echo "  端口 $port 已不在放行列表中。"
        fi
    else
        echo "操作取消。"
    fi
}

# -----------------------------------------------------------
# 4. 启用/禁用防火墙
# -----------------------------------------------------------
ufw_toggle() {
    check_ufw || return

    echo
    echo "========== 启用/禁用防火墙 =========="

    local status
    status=$(sudo ufw status 2>/dev/null | head -1 | grep -o 'active\|inactive' || echo "未知")

    echo "当前状态: $status"
    echo
    echo "1. 启用防火墙 (ufw enable)"
    echo "2. 禁用防火墙 (ufw disable)"
    echo "3. 返回"
    read -rp "请选择: " toggle

    case $toggle in
        1)
            if [[ "$status" == "active" ]]; then
                echo "防火墙已在运行中。"
                return
            fi
            echo
            echo "⚠ 启用防火墙可能中断现有 SSH 连接！"
            echo "   建议确保已放行 SSH 端口（通常是 22）。"
            if confirm "确认启用防火墙？"; then
                sudo ufw enable
                echo "防火墙已启用。"
            else
                echo "操作取消。"
            fi
            ;;
        2)
            if [[ "$status" == "inactive" ]]; then
                echo "防火墙已处于禁用状态。"
                return
            fi
            if confirm "确认禁用防火墙？服务器将开放所有端口。"; then
                sudo ufw disable
                echo "防火墙已禁用。"
            else
                echo "操作取消。"
            fi
            ;;
        3) return ;;
        *) echo "无效选择！" ;;
    esac
}

# -----------------------------------------------------------
# 防火墙管理主菜单
# -----------------------------------------------------------
ufw_menu() {
    # 进入时检测 ufw 是否安装
    if ! command -v ufw &>/dev/null; then
        echo
        echo "⚠ 系统未安装 ufw。"
        echo "  安装命令: sudo apt install ufw"
        echo
        pause
        return
    fi

    while true; do
        clear
        echo "----- 防火墙管理 (ufw) -----"
        echo "1. 查看防火墙状态"
        echo "2. 放行端口"
        echo "3. 关闭端口"
        echo "4. 启用 / 禁用防火墙"
        echo "5. 返回主菜单"
        echo "-------------------------"
        read -rp "请选择: " choice || break
        case $choice in
            1) ufw_status ;;
            2) ufw_allow ;;
            3) ufw_close_port ;;
            4) ufw_toggle ;;
            5) break ;;
            *) echo "无效选项，请重新输入！" ;;
        esac
        pause
    done
}
